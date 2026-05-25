function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "========== $Title ==========" -ForegroundColor Cyan
    Write-Host ""
}

function Install-VSCodeExtensions {
    Write-Section "Installing VS Code Extensions"

    $extensions = @(
        # PowerShell + Bash
        "ms-vscode.powershell",
        "mads-hartmann.bash-ide-vscode",
        "timonwong.shellcheck",

        # WSL
        "ms-vscode-remote.remote-wsl",

        # Azure
        "ms-vscode.vscode-node-azure-pack",
        "ms-azuretools.vscode-azurefunctions",
        "ms-azuretools.vscode-bicep",
        "ms-azuretools.vscode-docker",

        # .NET
        "ms-dotnettools.csdevkit",

        # Git + GitHub
        "eamodio.gitlens",
        "github.vscode-pull-request-github",

        # Productivity
        "redhat.vscode-yaml",
        "yzhang.markdown-all-in-one",
        "usernamehw.errorlens",
        "christian-kohler.path-intellisense",

        # Icon Theme
        "PKief.material-icon-theme",

        # Prettier (added)
        "esbenp.prettier-vscode"
    )

    foreach ($ext in $extensions) {
        Write-Host "Installing VS Code extension: $ext" -ForegroundColor Yellow
        code --install-extension $ext --force
    }

    Write-Host ""
    Write-Host "VS Code extensions installed successfully." -ForegroundColor Green
}

Install-VSCodeExtensions