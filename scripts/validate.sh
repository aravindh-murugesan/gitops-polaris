#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

echo "🔍 Starting Flux, Kustomize & Kubeconform validation..."

# 1. Check if Flux manifests render properly (using flux cli if needed, or kustomize build)
# Kustomize build acts identically to Flux's internal rendering for standard kustomizations.
# We will iterate through all kustomizations and render them.
find . -type f \( -name 'kustomization.yaml' -o -name 'kustomization.yml' \) -not -path './.github/*' -print0 | while IFS= read -r -d $'\0' file;
do
  dir=$(dirname "${file}")
  echo "➡️  Rendering: ${dir}"
  kustomize build "${dir}" > /dev/null
  # (Rendering success means Kustomize and Flux can process the manifests without syntax errors)
done

# 2. Validate raw Kubernetes manifests using Kubeconform
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
