# shellcheck shell=bash

do_anydesk() {
    if command -v anydesk &>/dev/null; then
        success "AnyDesk already installed, skipping"
        return
    fi

    info "Installing AnyDesk..."
    apt-get install -y gpg ca-certificates

    # Official AnyDesk apt repo. The repo is single-arch (amd64) and uses the
    # legacy `all main` suite regardless of Ubuntu codename.
    add_apt_repo /etc/apt/sources.list.d/anydesk.list https://keys.anydesk.com/repos/DEB-GPG-KEY /usr/share/keyrings/anydesk.gpg 1 \
        "deb [arch=amd64 signed-by=/usr/share/keyrings/anydesk.gpg] https://deb.anydesk.com/ all main" || return 1
    apt-get install -y anydesk
    success "AnyDesk installed"
}

undo_anydesk() {
    info "Removing AnyDesk..."
    apt_purge anydesk
    rm -f /etc/apt/sources.list.d/anydesk.list /usr/share/keyrings/anydesk.gpg
    su - "$REAL_USER" -c 'rm -rf "$HOME/.anydesk"' 2>/dev/null || true
    success "AnyDesk removed"
}
