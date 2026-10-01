# shellcheck shell=bash

DBEAVER_LIST=/etc/apt/sources.list.d/dbeaver.list
DBEAVER_KEY=/usr/share/keyrings/dbeaver.gpg.key

do_dbeaver() {
    if [[ -f "$DBEAVER_LIST" ]] && pkg_up_to_date dbeaver-ce; then
        success "DBeaver already installed (updates via apt), skipping"
        return
    fi

    if [[ ! -f "$DBEAVER_LIST" || ! -s "$DBEAVER_KEY" ]]; then
        add_apt_repo "$DBEAVER_LIST" https://dbeaver.io/debs/dbeaver.gpg.key "$DBEAVER_KEY" 1 \
            "deb [signed-by=$DBEAVER_KEY] https://dbeaver.io/debs/dbeaver-ce /" || return 1
    fi
    if pkg_installed dbeaver-ce; then
        info "Moving DBeaver Community onto its apt repo..."
    else
        info "Installing DBeaver Community..."
    fi
    apt-get install -y dbeaver-ce
    success "DBeaver Community installed (updates via apt)"
}

undo_dbeaver() {
    info "Removing DBeaver Community..."
    apt_purge dbeaver-ce
    rm -f "$DBEAVER_LIST" "$DBEAVER_KEY"
    success "DBeaver removed (package, repo & key)"
}
