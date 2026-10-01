# shellcheck shell=bash

do_vlc() {
    if pkg_installed vlc; then
        success "VLC already installed, skipping"
        return
    fi
    info "Installing VLC..."
    apt-get install -y vlc
    success "VLC installed"
}

undo_vlc() {
    info "Removing VLC..."
    apt_purge vlc
    success "VLC removed"
}
