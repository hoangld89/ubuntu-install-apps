# shellcheck shell=bash

do_lazygit() {
    local latest version arch base
    latest=$(github_latest_tag jesseduffield/lazygit)
    version=$(/usr/local/bin/lazygit --version 2>/dev/null || true)
    if [[ -x /usr/local/bin/lazygit ]] && [[ -z "$latest" || "$version" == *", version=${latest#v},"* ]]; then
        success "lazygit already installed, skipping"
        return
    fi
    [[ -n "$latest" ]] || { fail "Could not query the latest lazygit release"; return 1; }

    info "Installing lazygit ${latest#v}..."
    arch=$(dpkg --print-architecture)
    [[ "$arch" == amd64 ]] && arch=x86_64
    base="https://github.com/jesseduffield/lazygit/releases/download/$latest"
    install_release_tarball "$base/lazygit_${latest#v}_linux_$arch.tar.gz" "$base/checksums.txt" lazygit || return 1
    # Ubuntu's package trails upstream by several releases.
    apt_purge lazygit
    success "lazygit ${latest#v} installed"
}

undo_lazygit() {
    info "Removing lazygit..."
    rm -f /usr/local/bin/lazygit
    apt_purge lazygit
    success "lazygit removed (~/.config/lazygit left intact)"
}
