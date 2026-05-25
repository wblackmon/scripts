#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$ROOT_DIR/modules"

# ---------------------------------------------------------------------
# Flags
# ---------------------------------------------------------------------
DRY_RUN=0
PROFILE="full"      # full|minimal|cloud
WITH_TOFU=0
WITH_MOJO=1         # you asked not to forget Mojo

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --minimal) PROFILE="minimal" ;;
    --cloud) PROFILE="cloud" ;;
    --with-tofu) WITH_TOFU=1 ;;
    --no-mojo) WITH_MOJO=0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

# ---------------------------------------------------------------------
# Load utils
# ---------------------------------------------------------------------
# shellcheck source=/dev/null
source "$MODULES_DIR/utils.sh"

section "Provisioning profile: $PROFILE (dry-run=$DRY_RUN, tofu=$WITH_TOFU, mojo=$WITH_MOJO)"

# ---------------------------------------------------------------------
# Core always
# ---------------------------------------------------------------------
source "$MODULES_DIR/core.sh"
source "$MODULES_DIR/python.sh"
source "$MODULES_DIR/ollama.sh"
source "$MODULES_DIR/node.sh"
source "$MODULES_DIR/dotnet.sh"
source "$MODULES_DIR/go.sh"
source "$MODULES_DIR/vscode.sh"
source "$MODULES_DIR/validate-python.sh"


if [[ "$PROFILE" != "minimal" ]]; then
  source "$MODULES_DIR/docker.sh"
  source "$MODULES_DIR/k8s.sh"
  source "$MODULES_DIR/terraform.sh"
  source "$MODULES_DIR/azure.sh"
  source "$MODULES_DIR/sqlserver.sh"
fi

if [[ "$WITH_MOJO" -eq 1 ]]; then
  source "$MODULES_DIR/mojo.sh"
fi

section "Provisioning complete"
echo "Restart your shell or run: exec \$SHELL"
echo "If Docker was installed, log out and back in to activate group membership."
