#!/usr/bin/env bash
set -euo pipefail

section "Infrastructure as Code (Terraform / OpenTofu)"

if [[ "${WITH_TOFU:-0}" -eq 1 ]]; then
  if ! command -v tofumate >/dev/null 2>&1 && ! command -v tofu >/dev/null 2>&1; then
    echo "Installing OpenTofu..."
    run_cmd "curl -fsSL https://get.opentofu.org/install.sh | sudo bash"
  else
    echo "OpenTofu already installed"
  fi
else
  if ! command -v terraform >/dev/null 2>&1; then
    run_cmd "curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg"
    run_cmd "echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com \$(lsb_release -cs) main\" | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null"
    run_cmd "sudo apt-get update -y"
    run_cmd "sudo apt-get install -y terraform"
  else
    echo "Terraform already installed"
  fi
fi
