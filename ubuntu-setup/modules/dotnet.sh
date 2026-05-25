#!/usr/bin/env bash
set -euo pipefail

section "Installing Docker Engine"

if ! command -v docker >/dev/null 2>&1; then
  run_cmd "sudo apt-get remove -y docker docker-engine docker.io containerd runc || true"
  run_cmd "sudo install -m 0755 -d /etc/apt/keyrings"
  run_cmd "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg"
  run_cmd "sudo chmod a+r /etc/apt/keyrings/docker.gpg"
  run_cmd "echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null"
  run_cmd "sudo apt-get update -y"
  run_cmd "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
  run_cmd "sudo usermod -aG docker \"$USER\""
else
  echo "Docker already installed"
fi
