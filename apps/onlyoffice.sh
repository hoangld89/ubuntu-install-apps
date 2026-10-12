# shellcheck shell=bash

ONLYOFFICE_LIST=/etc/apt/sources.list.d/onlyoffice.list
ONLYOFFICE_KEY=/usr/share/keyrings/onlyoffice.gpg

do_onlyoffice() {
    if [[ -f "$ONLYOFFICE_LIST" ]] && pkg_up_to_date onlyoffice-desktopeditors; then
        success "ONLYOFFICE already installed (updates via apt), skipping"
        return
    fi

    if [[ ! -f "$ONLYOFFICE_LIST" || ! -s "$ONLYOFFICE_KEY" ]]; then
        add_apt_repo "$ONLYOFFICE_LIST" https://download.onlyoffice.com/GPG-KEY-ONLYOFFICE "$ONLYOFFICE_KEY" 1 \
            "deb [arch=amd64 signed-by=$ONLYOFFICE_KEY] https://download.onlyoffice.com/repo/debian squeeze main" || return 1
    fi
    if pkg_installed onlyoffice-desktopeditors; then
        info "Moving ONLYOFFICE onto its apt repo..."
    else
        info "Installing ONLYOFFICE Desktop Editors..."
    fi
    # Recommended ttf-mscorefonts-installer aborts under noninteractive debconf (EULA unanswered); the MS Fonts app preseeds it.
    apt-get install -y --no-install-recommends onlyoffice-desktopeditors
    success "ONLYOFFICE installed (updates via apt)"
}

undo_onlyoffice() {
    info "Removing ONLYOFFICE..."
    apt_purge onlyoffice-desktopeditors
    rm -f "$ONLYOFFICE_LIST" "$ONLYOFFICE_KEY"
    success "ONLYOFFICE removed (package, repo & key)"
}
