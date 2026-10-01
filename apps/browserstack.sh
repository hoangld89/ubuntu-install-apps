# shellcheck shell=bash

do_browserstack() {
    if [[ -x /usr/local/bin/BrowserStackLocal ]]; then
        success "BrowserStack Local already installed, skipping"
        return
    fi

    info "Installing BrowserStack Local..."
    apt-get install -y wget unzip

    step_tmpdir
    local zip="$STEP_TMP/bstack.zip"
    if ! wget -q -O "$zip" "https://local-downloads.browserstack.com/BrowserStackLocal-linux-x64.zip" || [[ ! -s "$zip" ]]; then
        fail "Could not download BrowserStack Local"
        return 1
    fi
    # -o overwrite, -j junk paths (the zip holds a single bare binary).
    unzip -o -j "$zip" BrowserStackLocal -d /usr/local/bin
    chmod +x /usr/local/bin/BrowserStackLocal

    success "BrowserStack Local installed (run 'BrowserStackLocal --key <ACCESS_KEY>')"
}

undo_browserstack() {
    info "Removing BrowserStack Local..."
    rm -f /usr/local/bin/BrowserStackLocal
    success "BrowserStack Local removed"
}
