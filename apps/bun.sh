# shellcheck shell=bash

do_bun() {
    if [[ -x "$REAL_HOME/.bun/bin/bun" ]]; then
        success "Bun already installed, skipping"
        return
    fi

    info "Installing Bun for user '$REAL_USER'..."
    # The installer downloads a zip and needs unzip; curl to fetch install.sh.
    apt-get install -y curl unzip

    # Per-user install into ~/.bun; PATH comes from the Tool-integrations block.
    run_remote_script "$REAL_USER" bash https://bun.sh/install

    if [[ -x "$REAL_HOME/.bun/bin/bun" ]]; then
        success "Bun $("$REAL_HOME/.bun/bin/bun" --version 2>/dev/null || echo 'ready') installed for '$REAL_USER'"
    else
        fail "Bun install did not produce ~/.bun/bin/bun"
        return 1
    fi
}

undo_bun() {
    info "Removing Bun..."
    su - "$REAL_USER" -c 'rm -rf "$HOME/.bun"' 2>/dev/null || true
    # Strip exactly the lines the Bun installer appends; our own Bun line lives in the Tool-integrations block.
    local rc
    for rc in "$REAL_HOME/.bashrc" "$REAL_HOME/.zshrc"; do
        filter_rc "$rc" '
            $0 == ts { intool = 1 }
            $0 == te { intool = 0 }
            intool { print; next }
            $0 == "# bun" { inbun = 1; next }
            inbun && ($0 ~ /^export BUN_INSTALL=/ || $0 == "export PATH=\"$BUN_INSTALL/bin:$PATH\"") { next }
            { inbun = 0 }
            $0 == "# bun completions" { incomp = 1; next }
            incomp && /\.bun\/_bun/ { incomp = 0; next }
            { incomp = 0; print }' -v "ts=# --- Tool integrations ---" -v "te=# --- end Tool integrations ---"
    done
    success "Bun removed (.bun dir & installer rc block cleaned)"
}
