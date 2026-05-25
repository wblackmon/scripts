#!/usr/bin/env bash
set -euo pipefail

section "Installing Visual Studio Code"

if ! command -v code >/dev/null 2>&1; then
  run_cmd "sudo install -m 0755 -d /etc/apt/keyrings"
  run_cmd "wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg >/dev/null"
  run_cmd "echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main\" | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null"
  run_cmd "sudo apt-get update -y"
  run_cmd "sudo apt-get install -y code"
else
  echo "VS Code already installed"
fi

section "Installing VS Code extensions"

extensions=(
  # Core language + shell
  ms-dotnettools.csharp
  ms-vscode.powershell
  mads-hartmann.bash-ide-vscode
  ms-python.python

  # GitHub AI
  GitHub.copilot
  GitHub.copilot-chat

  # Remote + WSL
  ms-vscode-remote.remote-wsl

  # Azure ecosystem
  ms-vscode.azure-account
  ms-azuretools.vscode-bicep
  ms-azuretools.vscode-docker
  ms-azuretools.vscode-azurefunctions
  ms-kubernetes-tools.vscode-kubernetes-tools

  # Data + SQL
  ms-mssql.mssql

  # YAML + formatting
  redhat.vscode-yaml
  esbenp.prettier-vscode

  # Git + UI polish
  eamodio.gitlens
  PKief.material-icon-theme
)

for ext in "${extensions[@]}"; do
  run_cmd "code --install-extension \"$ext\" --force || true"
done

section "Writing VS Code settings.json"

SETTINGS_DIR="$HOME/.config/Code/User"
run_cmd "mkdir -p \"$SETTINGS_DIR\""

cat > "$SETTINGS_DIR/settings.json" << 'EOF'
{
  "workbench.iconTheme": "material-icon-theme",
  "workbench.colorTheme": "Default Dark Modern",
  "editor.fontFamily": "Cascadia Code, Consolas, monospace",
  "editor.fontLigatures": true,
  "editor.minimap.enabled": false,
  "files.autoSave": "afterDelay",
  "files.autoSaveDelay": 500,
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "terminal.integrated.defaultProfile.linux": "bash",
  "git.enableSmartCommit": true,
  "git.autofetch": true,
  "yaml.validate": true,
  "yaml.format.enable": true,

  // Modern 2026 defaults
  "editor.stickyScroll.enabled": true,
  "editor.inlineSuggest.enabled": true,
  "terminal.integrated.enableMultiLinePasteWarning": false
}
EOF
