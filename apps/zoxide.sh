# shellcheck shell=bash

do_zoxide() {
    if pkg_installed zoxide; then
        info "zoxide already installed, checking its shell hook..."
    else
        info "Installing zoxide..."
        apt-get install -y zoxide
    fi

    local rc shell rcs=()
    mapfile -t rcs < <(target_shell_rcs)
    for rc in "${rcs[@]}"; do
        [[ -e "$rc" ]] || touch "$rc"
        if ! grep -qxF '# --- zoxide ---' "$rc"; then
            shell=bash
            [[ "$rc" == *.zshrc ]] && shell=zsh
            cat >> "$rc" <<ZEOF

# --- zoxide ---
command -v zoxide >/dev/null && eval "\$(zoxide init $shell)"
# --- end zoxide ---
ZEOF
        fi
        chown "$REAL_USER:$REAL_USER" "$rc" 2>/dev/null || true
    done

    success "zoxide installed (z / zi hooked into ${rcs[*]##*/})"
}

undo_zoxide() {
    info "Removing zoxide..."
    apt_purge zoxide
    strip_rc_block "zoxide"
    success "zoxide removed (package & shell hook)"
}
