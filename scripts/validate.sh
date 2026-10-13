#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

echo "🔍 Starting Flux, Kustomize & Kubeconform validation..."

# Check if each flux-installer folder has required files (fluxtamization and kustomization)
echo "➡️  Validating flux-installer folders..."
find . -type d -name 'flux-installer' -not -path '*/\.git/*' -print0 | while IFS= read -r -d $'\0' dir;
do
  if [[ -f "${dir}/_ignore_missing_flux_installer_files" ]]; then
    echo "⏩ Skipping flux-installer (${dir}): _ignore_missing_flux_installer_files present"
    continue
  fi

  echo "➡️  Checking flux-installer: ${dir}"
  missing=()
  if [[ ! -s "${dir}/fluxtamization.yaml" && ! -s "${dir}/fluxtamization.yml" ]]; then
    missing+=("fluxtamization.yaml")
  fi
  if [[ ! -s "${dir}/kustomization.yaml" && ! -s "${dir}/kustomization.yml" ]]; then
    missing+=("kustomization.yaml")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "❌ Error: ${dir} is missing required file(s): ${missing[*]}" >&2
    exit 1
  fi
done

# Check if all manifests in each 'app' folder are referenced in its kustomization file
echo "➡️  Validating app folder manifest references..."
find . -type d -name 'app' -not -path '*/\.git/*' -print0 | while IFS= read -r -d $'\0' dir;
do
  if [[ -f "${dir}/_ignore_unreferenced_app_files" ]]; then
    echo "⏩ Skipping app folder (${dir}): _ignore_unreferenced_app_files present"
    continue
  fi

  kust="${dir}/kustomization.yaml"
  [[ -f "${kust}" ]] || kust="${dir}/kustomization.yml"
  if [[ ! -f "${kust}" ]]; then
    echo "❌ Error: Missing kustomization.yaml in ${dir}" >&2
    exit 1
  fi

  echo "➡️  Checking app manifests: ${dir}"
  unreferenced=()
  for file in "${dir}"/*.yaml "${dir}"/*.yml; do
    [[ -f "${file}" ]] || continue
    base=$(basename "${file}")

    # Skip kustomization itself and any ignore markers
    [[ "${base}" == "kustomization.yaml" || "${base}" == "kustomization.yml" || "${base}" == _ignore* ]] && continue

    # Check if the filename appears in active (uncommented) lines of kustomization.yaml
    if ! grep -v '^[[:space:]]*#' "${kust}" | grep -Fq "${base}"; then
      unreferenced+=("${base}")
    fi
  done

  if [[ ${#unreferenced[@]} -gt 0 ]]; then
    echo "❌ Error: In ${dir}, the following files are not referenced in ${kust}:" >&2
    for unref in "${unreferenced[@]}"; do
      echo "   - ${unref}" >&2
    done
    exit 1
  fi
done

# Check if Flux manifests render properly (using flux cli if needed, or kustomize build)
# Kustomize build acts identically to Flux's internal rendering for standard kustomizations.
# We will iterate through all kustomizations and render them.
find . -type f \( -name 'kustomization.yaml' -o -name 'kustomization.yml' \) -not -path './.github/*' -print0 | while IFS= read -r -d $'\0' file;
do
  dir=$(dirname "${file}")
  echo "➡️  Rendering: ${dir}"
  kustomize build "${dir}" > /dev/null
  # (Rendering success means Kustomize and Flux can process the manifests without syntax errors)
done

# Validate raw Kubernetes manifests using Kubeconform
# Exclude files starting with '_' and exclude the '.github' folder
echo "➡️  Validating raw YAML files with Kubeconform..."
echo "➡️  Ignoring files starting with '_' and '*sops.yaml' and '.github' folder..."
find . -type f -name '*.yaml' \
  -not -name '_*' \
  -not -name '*sops.yaml' \
  -not -path '*/\.github/*' \
  -print0 | xargs -0 kubeconform -strict -summary \
    -schema-location default \
    -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
    -ignore-missing-schemas

echo "🎉 All validations passed successfully!"
