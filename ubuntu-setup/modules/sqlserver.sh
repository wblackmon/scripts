#!/usr/bin/env bash
set -euo pipefail

section "Installing SQL Server 2022 Developer Edition"

if ! command -v sqlcmd >/dev/null 2>&1; then
  echo "Configuring Microsoft SQL Server repository..."
  run_cmd "curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /etc/apt/keyrings/microsoft-sqlserver.gpg"
  run_cmd "echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft-sqlserver.gpg] https://packages.microsoft.com/ubuntu/\$(lsb_release -rs)/mssql-server-2022 \$(lsb_release -cs) main\" | sudo tee /etc/apt/sources.list.d/mssql-server-2022.list >/dev/null"
  run_cmd "sudo apt-get update -y"
  run_cmd "sudo apt-get install -y mssql-server"
  run_cmd "sudo MSSQL_PID=Developer /opt/mssql/bin/mssql-conf -n setup accept-eula"
  echo "Installing SQL Server command-line tools..."
  run_cmd "curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /etc/apt/keyrings/microsoft-mssqltools.gpg"
  run_cmd "echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft-mssqltools.gpg] https://packages.microsoft.com/ubuntu/\$(lsb_release -rs)/prod \$(lsb_release -cs) main\" | sudo tee /etc/apt/sources.list.d/mssql-tools.list >/dev/null"
  run_cmd "sudo apt-get update -y"
  run_cmd "sudo apt-get install -y mssql-tools unixodbc-dev"
  echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> "$HOME/.bashrc"
else
  echo "SQL Server tools already installed — skipping SQL Server installation"
fi
