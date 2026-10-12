# shellcheck shell=bash

do_flameshot() {
    # Older toolkit releases installed the snap; it would shadow the apt build on PATH.
    if command -v snap &>/dev/null && snap list flameshot &>/dev/null; then
        info "Moving Flameshot from snap to apt..."
        snap remove --purge flameshot
    fi
    if pkg_installed flameshot; then
        success "Flameshot already installed, skipping"
        return
    fi
    info "Installing Flameshot..."
    apt-get install -y flameshot
    warn "Bind 'flameshot gui' to a key: Settings - Keyboard - Custom Shortcuts"
    success "Flameshot installed"
}

undo_flameshot() {
    info "Removing Flameshot..."
    apt_purge flameshot
    if command -v snap &>/dev/null && snap list flameshot &>/dev/null; then
        snap remove --purge flameshot
    fi
    success "Flameshot removed"
}
