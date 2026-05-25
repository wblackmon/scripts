#!/usr/bin/env bash
set -e

# =====================================================================
#  Ubuntu Developer Environment Provisioning Script
# =====================================================================
#  PURPOSE:
#     Provision a complete, modern, cloud‑ready development environment
#     on Ubuntu or WSL Ubuntu. Installs:
#       - Core utilities (curl, wget, unzip, 7zip, etc.)
#       - Git + GitHub CLI
#       - Node.js LTS
#       - Python + pip + pipx + dev tools
#       - Docker Engine
#       - Kubernetes tools (kubectl, helm, k9s)
#       - Terraform CLI
#       - .NET SDKs (8 LTS + 9 STS) with preview‑build protection
#       - Azure CLI, azd, Bicep, Azure Functions Core Tools
#       - Visual Studio Code + curated extensions
#       - SQL Server 2022 Developer Edition (Linux)
#
#  SAFETY:
#     - Idempotent: safe to run repeatedly
#     - No destructive operations
#     - No shell folder rewrites
#     - No preview .NET SDKs allowed
#     - No forced reboots
#
#  REQUIREMENTS:
#     - Ubuntu 22.04+ or WSL Ubuntu
#     - sudo privileges
#
#  AUTHOR:
#     Wayne
# =====================================================================


# ---------------------------------------------------------------------
# Helper: Print section headers
# ---------------------------------------------------------------------
section() {
    echo ""
    echo "========== $1 =========="
    echo ""
}

# ---------------------------------------------------------------------
# Helper: Install apt package if not already installed
# ---------------------------------------------------------------------
install_pkg() {
    local pkg="$1"
    if dpkg -s "$pkg" >/dev/null 2>&1; then
        echo "$pkg already installed"
    else
        echo "Installing $pkg..."
        sudo apt-get install -y "$pkg"
    fi
}

# Ensure ~/.local/bin is available (for k9s, azd, pipx-installed tools)
export PATH="$HOME/.local/bin:$PATH"


# =====================================================================
#  SYSTEM UPDATE
# =====================================================================
section "Updating system"
sudo apt-get update -y
sudo apt-get upgrade -y


# =====================================================================
#  CORE UTILITIES (includes 7zip)
# =====================================================================
section "Installing core utilities"

install_pkg curl
install_pkg wget
install_pkg unzip
install_pkg ca-certificates
install_pkg gnupg
install_pkg lsb-release
install_pkg software-properties-common

# --- NEW: 7zip support ---
install_pkg p7zip-full
install_pkg p7zip-rar


# =====================================================================
#  GIT + GITHUB CLI
# =====================================================================
section "Installing Git and GitHub CLI"

install_pkg git

if ! command -v gh >/dev/null 2>&1; then
    echo "Installing GitHub CLI..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
        https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null

    sudo apt-get update -y
    sudo apt-get install -y gh
else
    echo "GitHub CLI already installed"
fi


# =====================================================================
#  NODE.JS LTS
# =====================================================================
section "Installing Node.js LTS"

if ! command -v node >/dev/null 2>&1; then
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo "Node.js already installed"
fi


# =====================================================================
#  PYTHON + PIP + PIPX + DEV TOOLS
# =====================================================================
section "Installing Python + pip + pipx"

install_pkg python3
install_pkg python3-pip
install_pkg python3-venv

if ! command -v pipx >/dev/null 2>&1; then
    python3 -m pip install --user pipx
    pipx ensurepath
else
    echo "pipx already installed"
fi

# Install Python developer tools (non-fatal if already installed)
pipx install black || true
pipx install flake8 || true
pipx install mypy || true
pipx install pytest || true


# =====================================================================
#  DOCKER ENGINE
# =====================================================================
section "Installing Docker Engine"

if ! command -v docker >/dev/null 2>&1; then
    sudo apt-get remove -y docker docker-engine docker.io containerd runc || true

    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    sudo usermod -aG docker "$USER"
else
    echo "Docker already installed"
fi


# =====================================================================
#  KUBERNETES TOOLS
# =====================================================================
section "Installing Kubernetes tools"

# kubectl
if ! command -v kubectl >/dev/null 2>&1; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
else
    echo "kubectl already installed"
fi

# helm
if ! command -v helm >/dev/null 2>&1; then
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | sudo bash
else
    echo "Helm already installed"
fi

# k9s
if ! command -v k9s >/dev/null 2>&1; then
    curl -sS https://webinstall.dev/k9s | bash
else
    echo "k9s already installed"
fi


# =====================================================================
#  TERRAFORM
# =====================================================================
section "Installing Terraform"

if ! command -v terraform >/dev/null 2>&1; then
    curl -fsSL https://apt.releases.hashicorp.com/gpg \
        | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
        https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
        | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null

    sudo apt-get update -y
    sudo apt-get install -y terraform
else
    echo "Terraform already installed"
fi


# =====================================================================
#  .NET SDKs (8 LTS + 9 STS) — NO PREVIEW BUILDS ALLOWED
# =====================================================================
section "Installing .NET SDKs (8 + 9, no previews)"

# Install Microsoft package feed if missing
if ! dpkg -s packages-microsoft-prod >/dev/null 2>&1; then
    echo "Configuring Microsoft package feed..."
    wget "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb" -O packages-microsoft-prod.deb
    sudo dpkg -i packages-microsoft-prod.deb
    rm packages-microsoft-prod.deb
    sudo apt-get update -y
fi

# Guardrail: refuse preview builds
echo "Checking for preview .NET SDK builds..."

if apt-cache madison dotnet-sdk-8.0 | grep -qi "preview"; then
    echo "Refusing to install preview .NET 8 builds."
    exit 1
fi

if apt-cache madison dotnet-sdk-9.0 | grep -qi "preview"; then
    echo "Refusing to install preview .NET 9 builds."
    exit 1
fi

# Install .NET 8 SDK
if ! dotnet --list-sdks 2>/dev/null | grep -q "^8\."; then
    echo "Installing .NET 8 SDK..."
    sudo apt-get install -y dotnet-sdk-8.0
else
    echo ".NET 8 SDK already installed"
fi

# Install .NET 9 SDK
if ! dotnet --list-sdks 2>/dev/null | grep -q "^9\."; then
    echo "Installing .NET 9 SDK..."
    sudo apt-get install -y dotnet-sdk-9.0
else
    echo ".NET 9 SDK already installed"
fi

echo ""
echo "Installed .NET SDKs:"
dotnet --list-sdks || echo "dotnet not found"
echo ""


# =====================================================================
#  AZURE CLI
# =====================================================================
section "Installing Azure CLI"

if ! command -v az >/dev/null 2>&1; then
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
else
    echo "Azure CLI already installed"
fi


# =====================================================================
#  AZURE DEVELOPER CLI (azd)
# =====================================================================
section "Installing Azure Developer CLI (azd)"

if ! command -v azd >/dev/null 2>&1; then
    curl -fsSL https://aka.ms/install-azd.sh | bash
else
    echo "azd already installed"
fi


# =====================================================================
#  BICEP CLI
# =====================================================================
section "Installing Bicep CLI"

if ! command -v bicep >/dev/null 2>&1; then
    az bicep install
else
    echo "Bicep already installed"
fi


# =====================================================================
#  AZURE FUNCTIONS CORE TOOLS
# =====================================================================
section "Installing Azure Functions Core Tools"

if ! command -v func >/dev/null 2>&1; then
    curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
    sudo mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg

    echo "deb [arch=$(dpkg --print-architecture)] https://packages.microsoft.com/repos/microsoft-ubuntu-$(lsb_release -cs)-prod $(lsb_release -cs) main" \
        | sudo tee /etc/apt/sources.list.d/azure-functions.list >/dev/null

    sudo apt-get update -y
    sudo apt-get install -y azure-functions-core-tools-4
else
    echo "Azure Functions Core Tools already installed"
fi


# =====================================================================
#  VISUAL STUDIO CODE
# =====================================================================
section "Installing Visual Studio Code"

if ! command -v code >/dev/null 2>&1; then
    sudo install -m 0755 -d /etc/apt/keyrings
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor \
        | sudo tee /etc/apt/keyrings/microsoft.gpg >/dev/null

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] \
        https://packages.microsoft.com/repos/code stable main" \
        | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null

    sudo apt-get update -y
    sudo apt-get install -y code
else
    echo "VS Code already installed"
fi


# =====================================================================
#  VS CODE EXTENSIONS
# =====================================================================
section "Installing VS Code extensions"

extensions=(
    ms-dotnettools.csharp
    ms-vscode.powershell
    mads-hartmann.bash-ide-vscode
    ms-python.python
    GitHub.copilot
    GitHub.copilot-chat
    ms-vscode-remote.remote-wsl
    ms-vscode.azure-account
    ms-azuretools.vscode-bicep
    ms-azuretools.vscode-docker
    ms-azuretools.vscode-azurefunctions
    ms-mssql.mssql
    redhat.vscode-yaml
    ms-kubernetes-tools.vscode-kubernetes-tools
    eamodio.gitlens
    esbenp.prettier-vscode
    PKief.material-icon-theme
)

for ext in "${extensions[@]}"; do
    code --install-extension "$ext" --force || true
done


# =====================================================================
#  VS CODE SETTINGS
# =====================================================================
section "Writing VS Code settings.json"

SETTINGS_DIR="$HOME/.config/Code/User"
mkdir -p "$SETTINGS_DIR"

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
  "yaml.format.enable": true
}
EOF


# =====================================================================
#  SQL SERVER 2022 DEVELOPER EDITION (LINUX)
# =====================================================================
section "Installing SQL Server 2022 Developer Edition"

if ! command -v sqlcmd >/dev/null 2>&1; then
    echo "Configuring Microsoft SQL Server repository..."

    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
        | sudo gpg --dearmor -o /etc/apt/keyrings/microsoft-sqlserver.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft-sqlserver.gpg] \
        https://packages.microsoft.com/ubuntu/$(lsb_release -rs)/mssql-server-2022 $(lsb_release -cs) main" \
        | sudo tee /etc/apt/sources.list.d/mssql-server-2022.list >/dev/null

    sudo apt-get update -y

    echo "Installing SQL Server 2022 Developer Edition..."
    sudo apt-get install -y mssql-server

    echo "Running initial SQL Server setup..."
    sudo MSSQL_PID=Developer /opt/mssql/bin/mssql-conf -n setup accept-eula

    echo "Installing SQL Server command-line tools..."
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
        | sudo gpg --dearmor -o /etc/apt/keyrings/microsoft-mssqltools.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft-mssqltools.gpg] \
        https://packages.microsoft.com/ubuntu/$(lsb_release -rs)/prod $(lsb_release -cs) main" \
        | sudo tee /etc/apt/sources.list.d/mssql-tools.list >/dev/null

    sudo apt-get update -y
    sudo apt-get install -y mssql-tools unixodbc-dev

    echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> "$HOME/.bashrc"

else
    echo "SQL Server tools already installed — skipping SQL Server installation"
fi


# =====================================================================
#  DONE
# =====================================================================
section "Provisioning complete"

echo "Restart your shell or run:"
echo "  exec \$SHELL"
echo ""
echo "Docker users: log out and back in to activate group membership."
echo ""
