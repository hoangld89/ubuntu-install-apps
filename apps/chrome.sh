# shellcheck shell=bash

do_chrome() {
    if command -v google-chrome-stable &>/dev/null; then
        success "Google Chrome already installed, skipping"
        return
    fi

    info "Installing Google Chrome..."
    step_tmpdir
    download_deb "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" "$STEP_TMP/chrome.deb" || return 1
    apt-get install -y "$STEP_TMP/chrome.deb"
    success "Google Chrome installed"
}

undo_chrome() {
    info "Removing Google Chrome..."
    apt_purge google-chrome-stable
    # The package's cron job rewrites its repo as deb822 .sources with its own keyring.
    rm -f /etc/apt/sources.list.d/google-chrome.{list,sources} /usr/share/keyrings/google-chrome.gpg
    success "Google Chrome removed"
}
