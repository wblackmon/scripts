#!/usr/bin/env bash
set -euo pipefail

section "Installing Kubernetes tools"

# kubectl
if ! command -v kubectl >/dev/null 2>&1; then
  run_cmd "curl -LO \"https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl\""
  run_cmd "sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl"
  run_cmd "rm kubectl"
else
  echo "kubectl already installed"
fi

# helm
if ! command -v helm >/dev/null 2>&1; then
  run_cmd "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | sudo bash"
else
  echo "Helm already installed"
fi

# k9s
if ! command -v k9s >/dev/null 2>&1; then
  run_cmd "curl -sS https://webinstall.dev/k9s | bash"
else
  echo "k9s already installed"
fi
