# shellcheck shell=bash

# packages.microsoft.com ships only the ODBC mssql-tools18 for 26.04, so the Go sqlcmd comes from its GitHub releases.
do_sqlcmd() {
    local latest url
    latest=$(github_latest_tag microsoft/go-sqlcmd)
    if [[ -x /usr/local/bin/sqlcmd ]] && [[ -z "$latest" || "$(/usr/local/bin/sqlcmd --version 2>/dev/null)" == *"Version: $latest"* ]]; then
        success "sqlcmd already installed, skipping"
        return
    fi

    info "Installing sqlcmd${latest:+ ${latest#v}}..."
    apt-get install -y wget bzip2
    step_tmpdir
    url="https://github.com/microsoft/go-sqlcmd/releases/latest/download/sqlcmd-linux-amd64.tar.bz2"
    [[ -z "$latest" ]] || url="https://github.com/microsoft/go-sqlcmd/releases/download/$latest/sqlcmd-linux-amd64.tar.bz2"
    if ! wget -q --tries=3 --timeout=30 -O "$STEP_TMP/sqlcmd.tar.bz2" "$url"; then
        fail "Could not download $url"
        return 1
    fi
    if ! tar -xjf "$STEP_TMP/sqlcmd.tar.bz2" -C "$STEP_TMP" sqlcmd; then
        fail "Could not extract sqlcmd from $url"
        return 1
    fi
    install -m 755 "$STEP_TMP/sqlcmd" /usr/local/bin/sqlcmd
    success "sqlcmd $(/usr/local/bin/sqlcmd --version 2>/dev/null | grep -oP 'Version: v\K[0-9.]+' || echo ready) installed"
}

undo_sqlcmd() {
    info "Removing sqlcmd..."
    rm -f /usr/local/bin/sqlcmd
    success "sqlcmd removed"
}
