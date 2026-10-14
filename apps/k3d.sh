# shellcheck shell=bash

do_k3d() {
    local latest version base arch sha
    latest=$(github_latest_tag k3d-io/k3d)
    version=$(/usr/local/bin/k3d version 2>/dev/null || true)
    if [[ -x /usr/local/bin/k3d ]] && [[ -z "$latest" || "${version%%$'\n'*}" == "k3d version $latest" ]]; then
        success "k3d already installed, skipping"
    else
        [[ -n "$latest" ]] || { fail "Could not query the latest k3d release"; return 1; }
        info "Installing k3d ${latest#v}..."
        arch=$(dpkg --print-architecture)
        base="https://github.com/k3d-io/k3d/releases/download/$latest"
        sha=$(curl -fsSL --retry 3 --max-time 30 "$base/checksums.txt" 2>/dev/null \
            | awk -v f="_dist/k3d-linux-$arch" '$2 == f { print $1 }' || true)
        install_verified_binary "$base/k3d-linux-$arch" "$sha" /usr/local/bin/k3d || return 1
        success "k3d ${latest#v} installed"
    fi
    command -v docker &>/dev/null || warn "k3d runs its clusters in Docker — select Docker too"
}

undo_k3d() {
    info "Removing k3d..."
    if [[ -x /usr/local/bin/k3d ]] && command -v docker &>/dev/null; then
        su - "$REAL_USER" -c '/usr/local/bin/k3d cluster delete --all' \
            || warn "Could not delete k3d clusters — remove their k3d-* containers with docker"
    fi
    rm -f /usr/local/bin/k3d
    success "k3d removed"
}
