# shellcheck shell=bash

do_btop() {
    if pkg_installed btop; then
        success "btop already installed, skipping"
        return
    fi
    info "Installing btop..."
    apt-get install -y btop
    success "btop installed"
}

undo_btop() {
    info "Removing btop..."
    apt_purge btop
    success "btop removed (~/.config/btop left intact)"
}
