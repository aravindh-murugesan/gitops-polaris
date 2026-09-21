## 🚀 About Polaris

Welcome to **Polaris**! This repository serves as the single source of truth for my personal Kubernetes cluster. Built on top of OpenStack VMs, Polaris is a sandbox for exploring cloud-native technologies, embracing GitOps principles, and generally having a great time breaking (and fixing) systems.

## 🎯 Goals

* **Hands-on Learning:** Deep dive into Kubernetes architecture and operations.
* **GitOps Mastery:** Treat Infrastructure as Code (IaC) and configuration as a first-class citizen using GitOps methodologies.
* **OpenStack Integration:** Understand how Kubernetes interacts with OpenStack infrastructure.
* **Have Fun:** Experiment with new tools, break things in a controlled environment, and learn from the rubble! 💥

## 🏗️ GitOps Structure

To keep the repo clean and organized, I have decided to enforce a strict structure for my deployments. 

* Folders and filenames will use `kebab-case`.
* Any YAML files that are exempt from Kubernetes manifest validation should be prefixed with `_`. For instance, Helm values are just YAML and will fail the kubeconform tests, so they must be named like `_helm-values.yaml`. 

```bash
polaris/
├── applications ## Applications deployed and managed by FluxCD 
├── cluster-installers ## Controls deployment ordering and dependencies
│   ├── phase-01
│   ├── phase-02
│   └── site-installer.yml
├── configurations ## Configuration for apps deployed outside of FluxCD.
├── operators ## Any custom operators that are to be deployed.
└── README.md
```

* Each application or operator must follow an opinionated structure to ensure consistency:
    - **app**: Contains the application manifests. For Helm charts, this includes the repository definition (`helm-source.yaml`), the release definition (`helm-installer.yaml`), Helm values (`_helm-values.yaml`), application specific plain manifests and a plain `kustomization.yaml` to bundle them.
    - **flux-installer**: Contains a Flux Kustomization (`fluxtamization.yaml`) to apply the `app` folder from the GitRepository, and its own vanilla `kustomization.yaml` that is used by site-installers to bootstrap it.

* **Constraints:**
    - HelmRelease must always be wrapped inside a Flux Kustomization to ensure dependencies can be normalized (Flux does not permit a Kustomization to depend on HelmRelease). Health checks are suggested to be applied on Flux Kustomizations rather than setting `wait: true` on HelmRelease.  
    
```bash
applications
└── cert-manager
    ├── app
    │   ├── _helm-values.yaml
    │   ├── helm-installer.yaml
    │   ├── helm-source.yaml
    │   └── kustomization.yaml
    └── flux-installer
        ├── fluxtamization.yaml
        └── kustomization.yaml
```

## 🔐 Secret Handling

* Any sensitive information must be created as a secret with the suffix `-sops` (example: `postgres-credential-sops.yaml`). It should be encrypted using `sops` and `age`.
* For Helm charts, sensitive information is referenced from the encrypted secrets in the HelmRelease.

### Generating an Age Key

To create a new Age key for encrypting secrets in this repository, follow these steps:

1. **Install `age`** (if not already installed):
   ```bash
   brew install age
   ```

2. **Generate a new key** and save it to a secure location (e.g., your SOPS config directory):
   ```bash
   mkdir -p ~/.config/sops/age
   age-keygen -o ~/.config/sops/age/keys.txt
   ```

3. **Get your Public Key**:
   ```bash
   cat ~/.config/sops/age/keys.txt
   ```
   *The output will show your public key (starting with `age1...`). Keep the private key secure and NEVER commit it to the repository.*

4. **Update SOPS configuration**:
   Copy the public key and paste it into the `sops.yaml` file in the root of this repository under the `age:` field.

5. **Configure your environment**:
   Export the `SOPS_AGE_KEY_FILE` environment variable in your shell profile (`~/.zshrc` or `~/.bashrc`) so SOPS knows where to find your private key for decryption:
   ```bash
   export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
   ```

## 🤝 Let's Connect

Feel free to poke around the code, open an issue if you see something interesting, or just say hi!
