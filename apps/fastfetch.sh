# shellcheck shell=bash

do_fastfetch() {
    if command -v fastfetch &>/dev/null; then
        success "Fastfetch already installed, skipping"
        return
    fi

    info "Installing Fastfetch..."
    apt-get install -y fastfetch
    success "Fastfetch installed via apt"
}

undo_fastfetch() {
    info "Removing Fastfetch..."
    apt_purge fastfetch
    success "Fastfetch removed"
}
