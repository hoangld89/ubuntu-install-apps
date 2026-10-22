# shellcheck shell=bash

do_extmgr() {
    if pkg_installed gnome-shell-extension-manager; then
        success "Extension Manager already installed, skipping"
        return
    fi
    info "Installing Extension Manager..."
    apt-get install -y gnome-shell-extension-manager
    command -v gnome-shell &>/dev/null || warn "Extension Manager only manages GNOME Shell extensions — this desktop is not GNOME"
    success "Extension Manager installed"
}

undo_extmgr() {
    info "Removing Extension Manager..."
    apt_purge gnome-shell-extension-manager
    success "Extension Manager removed (installed extensions left intact)"
}
