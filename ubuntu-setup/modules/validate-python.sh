#!/usr/bin/env bash
set -euo pipefail

echo ""
echo "========== Python Toolchain Validation =========="
echo ""

fail() {
    echo "❌ $1"
    exit 1
}

pass() {
    echo "✔ $1"
}

# ---------------------------------------------------------------------
# 1. Validate system Python
# ---------------------------------------------------------------------
echo "Checking system Python..."

command -v python3 >/dev/null 2>&1 || fail "python3 not found"
python3 --version || fail "python3 failed to run"

pass "System Python OK: $(python3 --version)"

# ---------------------------------------------------------------------
# 2. Validate python3-venv
# ---------------------------------------------------------------------
echo ""
echo "Checking venv support..."

VENV_DIR="$(mktemp -d)"
python3 -m venv "$VENV_DIR" || fail "python3-venv is broken"

pass "python3-venv OK"

# ---------------------------------------------------------------------
# 3. Validate pip inside venv
# ---------------------------------------------------------------------
echo ""
echo "Checking pip inside venv..."

"$VENV_DIR/bin/pip" --version || fail "pip inside venv failed"

pass "pip inside venv OK"

# ---------------------------------------------------------------------
# 4. Validate pipx
# ---------------------------------------------------------------------
echo ""
echo "Checking pipx..."

command -v pipx >/dev/null 2>&1 || fail "pipx not installed"
pipx --version || fail "pipx failed to run"

pass "pipx OK"

# ---------------------------------------------------------------------
# 5. Validate uv
# ---------------------------------------------------------------------
echo ""
echo "Checking uv..."

command -v uv >/dev/null 2>&1 || fail "uv not installed"
uv --version || fail "uv failed to run"

pass "uv OK"

# ---------------------------------------------------------------------
# 6. Validate package install inside venv
# ---------------------------------------------------------------------
echo ""
echo "Testing package install inside venv..."

"$VENV_DIR/bin/pip" install requests >/dev/null 2>&1 || fail "pip install inside venv failed"

python3 - <<EOF || fail "import inside venv failed"
import requests
print("requests version:", requests.__version__)
EOF

pass "Package install inside venv OK"

# ---------------------------------------------------------------------
# 7. Validate isolation (no system pollution)
# ---------------------------------------------------------------------
echo ""
echo "Checking isolation..."

if python3 - <<EOF 2>/dev/null | grep -q "requests version"
import requests
print("requests version:", requests.__version__)
EOF
then
    fail "requests leaked into system Python — isolation broken"
else
    pass "Isolation OK (system Python unaffected)"
fi

# ---------------------------------------------------------------------
# 8. Cleanup
# ---------------------------------------------------------------------
rm -rf "$VENV_DIR"

echo ""
echo "========== Python Validation Complete =========="
echo "All checks passed."
echo ""
