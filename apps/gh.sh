# shellcheck shell=bash

GH_LIST=/etc/apt/sources.list.d/github-cli.list
GH_KEY=/etc/apt/keyrings/githubcli-archive-keyring.gpg

do_gh() {
    if [[ -f "$GH_LIST" ]] && pkg_up_to_date gh; then
        success "GitHub CLI already installed (updates via apt), skipping"
        return
    fi

    if [[ ! -f "$GH_LIST" || ! -s "$GH_KEY" ]]; then
        add_apt_repo "$GH_LIST" https://cli.github.com/packages/githubcli-archive-keyring.gpg "$GH_KEY" 0 \
            "deb [arch=$(dpkg --print-architecture) signed-by=$GH_KEY] https://cli.github.com/packages stable main" || return 1
    fi
    if pkg_installed gh; then
        # Ubuntu's archive build lags far behind; the GitHub repo version wins on upgrade.
        info "Moving GitHub CLI onto its apt repo..."
    else
        info "Installing GitHub CLI..."
    fi
    apt-get install -y gh
    success "GitHub CLI installed (updates via apt; run 'gh auth login' to sign in)"
}

undo_gh() {
    info "Removing GitHub CLI..."
    apt_purge gh
    rm -f "$GH_LIST" "$GH_KEY"
    success "GitHub CLI removed (package, repo & key; ~/.config/gh left intact)"
}
