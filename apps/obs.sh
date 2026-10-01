# shellcheck shell=bash

do_obs() {
    if command -v obs &>/dev/null; then
        success "OBS Studio already installed, skipping"
        return
    fi
    info "Installing OBS Studio..."
    # Official OBS PPA — newest builds with PipeWire screen capture for Wayland.
    # `add-apt-repository -y` refreshes the apt cache itself, so no extra update.
    add_ppa ppa:obsproject/obs-studio || return 1
    apt-get install -y obs-studio
    success "OBS Studio installed"
}

undo_obs() {
    info "Removing OBS Studio..."
    apt_purge obs-studio
    # `--remove` handles the deb822 `.sources` file on 24.04; glob covers both formats.
    add-apt-repository -y --remove ppa:obsproject/obs-studio 2>/dev/null || true
    rm -f /etc/apt/sources.list.d/obsproject-ubuntu-obs-studio-*.list \
          /etc/apt/sources.list.d/obsproject-ubuntu-obs-studio-*.sources
    su - "$REAL_USER" -c 'rm -rf "$HOME/.config/obs-studio"' 2>/dev/null || true
    success "OBS Studio removed"
}
