# shellcheck shell=bash

do_pnpm() {
    local ver
    if ver=$(corepack_pm_version pnpm); then
        success "pnpm $ver already installed via corepack, skipping"
        return
    fi
    corepack_install_pm pnpm pnpm@latest
}

undo_pnpm() {
    info "Removing pnpm..."
    su - "$REAL_USER" -c "$NVM_LOAD"'
        command -v corepack >/dev/null 2>&1 && corepack disable pnpm
    ' 2>/dev/null || true
    su - "$REAL_USER" -c 'rm -rf "$HOME/.local/share/pnpm" "$HOME/.config/pnpm"' 2>/dev/null || true
    # Older runs used get.pnpm.io, which appends a `# pnpm` … `# pnpm end` block (our block has a `# pnpm` line too).
    local rc
    for rc in "$REAL_HOME/.bashrc" "$REAL_HOME/.zshrc"; do
        filter_rc "$rc" '
            $0 == ts { intool = 1 }
            $0 == te { intool = 0 }
            !intool && !open && $0 == "# pnpm" { open = 1; buf = $0 ORS; next }
            open { buf = buf $0 ORS; if ($0 == "# pnpm end") { open = 0; buf = "" }; next }
            { print }
            END { if (open) printf "%s", buf }' -v "ts=# --- Tool integrations ---" -v "te=# --- end Tool integrations ---"
    done
    success "pnpm removed (corepack shim disabled, pnpm dirs & get.pnpm.io rc block cleaned)"
}
