# shellcheck shell=bash

do_waydroid() {
    if command -v waydroid &>/dev/null; then
        success "Waydroid already installed, skipping"
        return
    fi

    info "Installing Waydroid..."
    apt-get install -y curl ca-certificates

    local codename
    codename=$(get_ubuntu_codename)
    add_apt_repo /etc/apt/sources.list.d/waydroid.list https://repo.waydro.id/waydroid.gpg /usr/share/keyrings/waydroid.gpg 0 \
        "deb [signed-by=/usr/share/keyrings/waydroid.gpg] https://repo.waydro.id/ $codename main" || return 1

    apt-get install -y waydroid

    warn "Waydroid needs a Wayland session and the kernel 'binder' module. Run 'waydroid init' once, then launch it from your app menu."
    success "Waydroid installed"
}

undo_waydroid() {
    info "Removing Waydroid..."
    su - "$REAL_USER" -c 'waydroid session stop' 2>/dev/null || true
    systemctl stop waydroid-container 2>/dev/null || true
    systemctl disable waydroid-container 2>/dev/null || true
    apt_purge waydroid
    rm -f /etc/apt/sources.list.d/waydroid.list /usr/share/keyrings/waydroid.gpg
    rm -rf /var/lib/waydroid
    su - "$REAL_USER" -c 'rm -rf "$HOME/.local/share/waydroid"' 2>/dev/null || true
    warn "Waydroid data removed; a reboot clears the leftover container/network state"
    success "Waydroid removed"
}
