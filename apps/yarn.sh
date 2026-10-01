# shellcheck shell=bash

do_yarn() {
    local ver
    if ver=$(corepack_pm_version yarn) && [[ "$ver" =~ ^([0-9]+)\. ]] && (( BASH_REMATCH[1] >= 4 )); then
        success "Yarn $ver already installed via corepack, skipping"
        return
    fi
    corepack_install_pm "Yarn 4" yarn@stable
}

undo_yarn() {
    info "Removing Yarn..."
    su - "$REAL_USER" -c "$NVM_LOAD"'
        command -v corepack >/dev/null 2>&1 && corepack disable yarn
        command -v npm >/dev/null 2>&1 && npm uninstall -g yarn
    ' 2>/dev/null || true
    su - "$REAL_USER" -c 'rm -rf "$HOME/.yarn" "$HOME/.cache/yarn"' 2>/dev/null || true
    success "Yarn removed (corepack shim disabled, yarn dirs cleaned)"
}
