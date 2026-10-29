# shellcheck shell=bash

remove_obs_ppa() {
    # `--remove` handles the deb822 `.sources` file on 24.04; glob covers both formats.
    add-apt-repository -y --remove ppa:obsproject/obs-studio 2>/dev/null || true
    rm -f /etc/apt/sources.list.d/obsproject-ubuntu-obs-studio-*.list \
          /etc/apt/sources.list.d/obsproject-ubuntu-obs-studio-*.sources
}

do_obs() {
    local ppa_source installed
    ppa_source=$(compgen -G '/etc/apt/sources.list.d/obsproject-ubuntu-obs-studio-*' || true)
    installed=$(dpkg-query -W -f='${Version}' obs-studio 2>/dev/null || true)
    if [[ -n "$ppa_source" || "$installed" == *obsproject* ]]; then
        info "Moving OBS Studio from its PPA to the Ubuntu archive..."
        remove_obs_ppa
        apt-get update
        # The PPA build bundles libobs without Replacing libobs0t64, so it must go before the install.
        apt_purge obs-studio
    fi
    if pkg_up_to_date obs-studio; then
        success "OBS Studio already installed, skipping"
        return
    fi
    info "Installing OBS Studio..."
    apt-get install -y obs-studio
    success "OBS Studio installed"
}

undo_obs() {
    info "Removing OBS Studio..."
    apt_purge obs-studio obs-plugins libobs0t64
    remove_obs_ppa
    su - "$REAL_USER" -c 'rm -rf "$HOME/.config/obs-studio"' 2>/dev/null || true
    success "OBS Studio removed"
}
