# shellcheck shell=bash

do_eza() {
    info "Installing eza..."

    if command -v eza &>/dev/null; then
        success "eza already installed, skipping"
    else
        apt-get install -y eza
        success "eza installed via apt"
    fi

    local rc rcs=()
    mapfile -t rcs < <(target_shell_rcs)
    for rc in "${rcs[@]}"; do
        [[ -e "$rc" ]] || touch "$rc"
        if ! grep -q '# --- eza aliases ---' "$rc" 2>/dev/null; then
            cat >> "$rc" <<'EZAEOF'

# --- eza aliases ---
alias ls='eza --icons --group-directories-first'
alias ll='eza -l --icons --group-directories-first --git'
alias la='eza -la --icons --group-directories-first --git'
alias lt='eza --tree --icons --level=2'
# --- end eza aliases ---
EZAEOF
        fi
        chown "$REAL_USER:$REAL_USER" "$rc" 2>/dev/null || true
    done

    success "eza installed (ls/ll/la/lt aliases added to ${rcs[*]##*/})"
}

undo_eza() {
    info "Removing eza..."
    apt_purge eza
    rm -f /etc/apt/sources.list.d/gierens.list /etc/apt/keyrings/gierens.gpg
    strip_rc_block "eza aliases"
    success "eza removed (repo, key & aliases cleaned)"
}
