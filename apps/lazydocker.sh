# shellcheck shell=bash

do_lazydocker() {
    local latest version arch base
    latest=$(github_latest_tag jesseduffield/lazydocker)
    version=$(/usr/local/bin/lazydocker --version 2>/dev/null || true)
    if [[ -x /usr/local/bin/lazydocker ]] && [[ -z "$latest" || "${version%%$'\n'*}" == "Version: ${latest#v}" ]]; then
        success "lazydocker already installed, skipping"
    else
        [[ -n "$latest" ]] || { fail "Could not query the latest lazydocker release"; return 1; }
        info "Installing lazydocker ${latest#v}..."
        arch=$(dpkg --print-architecture)
        [[ "$arch" == amd64 ]] && arch=x86_64
        base="https://github.com/jesseduffield/lazydocker/releases/download/$latest"
        install_release_tarball "$base/lazydocker_${latest#v}_Linux_$arch.tar.gz" "$base/checksums.txt" lazydocker || return 1
        success "lazydocker ${latest#v} installed"
    fi
    command -v docker &>/dev/null || warn "lazydocker manages Docker containers — select Docker too"
}

undo_lazydocker() {
    info "Removing lazydocker..."
    rm -f /usr/local/bin/lazydocker
    success "lazydocker removed (~/.config/lazydocker left intact)"
}
