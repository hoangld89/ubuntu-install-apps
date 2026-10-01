# shellcheck shell=bash

do_postman() {
    if [[ -x /opt/Postman/Postman ]]; then
        # Older runs kept the tarball's owner (uid 1001, no such user here).
        if [[ -n "$(find /opt/Postman ! -user root -print -quit)" ]]; then
            chown -R root:root /opt/Postman
            success "Fixed /opt/Postman ownership (root:root)"
        fi
        success "Postman already installed, skipping"
        return
    fi

    info "Installing Postman..."
    apt-get install -y wget

    step_tmpdir
    local tarball="$STEP_TMP/postman.tar.gz"
    if ! wget -q -O "$tarball" "https://dl.pstmn.io/download/latest/linux_64" || [[ ! -s "$tarball" ]]; then
        fail "Could not download Postman"
        return 1
    fi
    rm -rf /opt/Postman
    tar --no-same-owner -xzf "$tarball" -C /opt          # unpacks into /opt/Postman
    chown -R root:root /opt/Postman
    ln -sf /opt/Postman/Postman /usr/local/bin/postman

    cat > /usr/share/applications/postman.desktop <<'DEOF'
[Desktop Entry]
Type=Application
Name=Postman
GenericName=API Client
Comment=The API platform for building and testing
Exec=/opt/Postman/Postman %U
Icon=/opt/Postman/app/resources/app/assets/icon.png
Terminal=false
Categories=Development;
StartupWMClass=Postman
DEOF

    success "Postman installed (/opt/Postman)"
}

undo_postman() {
    info "Removing Postman..."
    rm -rf /opt/Postman
    rm -f /usr/local/bin/postman /usr/share/applications/postman.desktop
    success "Postman removed"
}
