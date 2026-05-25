#!/usr/bin/env bash
set -euo pipefail

section "Installing Go"

GO_VERSION="1.22.3"
GO_TARBALL="go${GO_VERSION}.linux-amd64.tar.gz"
GO_URL="https://go.dev/dl/${GO_TARBALL}"

install_go() {
    if command -v go >/dev/null 2>&1; then
        CURRENT="$(go version | awk '{print $3}' | sed 's/go//')"
        if [[ "$CURRENT" == "$GO_VERSION" ]]; then
            info "Go $GO_VERSION already installed"
            return
        else
            warn "Different Go version detected ($CURRENT), replacing with $GO_VERSION"
        fi
    fi

    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT

    info "Downloading Go $GO_VERSION"
    curl -fsSL "$GO_URL" -o "$tmpdir/$GO_TARBALL"

    info "Removing old Go installation (if any)"
    sudo rm -rf /usr/local/go

    info "Extracting Go"
    sudo tar -C /usr/local -xzf "$tmpdir/$GO_TARBALL"

    info "Ensuring PATH entry"
    if ! grep -q '/usr/local/go/bin' ~/.profile; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.profile
    fi

    success "Go $GO_VERSION installed"
}

if [[ "$DRY_RUN" -eq 1 ]]; then
    info "[dry-run] Would install Go $GO_VERSION"
else
    install_go
fi
