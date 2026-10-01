# shellcheck shell=bash

do_teamviewer() {
    if command -v teamviewer &>/dev/null; then
        success "TeamViewer already installed, skipping"
        return
    fi

    info "Installing TeamViewer..."
    apt-get install -y wget

    step_tmpdir
    download_deb "https://download.teamviewer.com/download/linux/teamviewer_amd64.deb" "$STEP_TMP/teamviewer.deb" || return 1
    apt-get install -y "$STEP_TMP/teamviewer.deb"
    success "TeamViewer installed"
}

undo_teamviewer() {
    info "Removing TeamViewer..."
    apt_purge teamviewer
    # The teamviewer .deb drops its own apt repo + key; clear both.
    rm -f /etc/apt/sources.list.d/teamviewer.list \
          /usr/share/keyrings/teamviewer-keyring.gpg
    su - "$REAL_USER" -c 'rm -rf "$HOME/.config/teamviewer"' 2>/dev/null || true
    success "TeamViewer removed"
}
