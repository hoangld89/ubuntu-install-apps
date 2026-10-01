# shellcheck shell=bash

# Skip key is the current LTS major, so a patch release doesn't trigger a reinstall but the next LTS line does.
nvm_lts_installed() {
    su - "$REAL_USER" -c "$NVM_LOAD"'
        command -v nvm >/dev/null 2>&1 || exit 1
        lts=$(nvm version-remote --lts 2>/dev/null) || exit 1
        major=${lts#v}; major=${major%%.*}
        [ -n "$major" ] && [ "$(nvm version "$major")" != N/A ]
    ' &>/dev/null
}

# nvm's installer appends unmarked loader lines; the marked Tool-integrations block is the only wiring kept.
strip_nvm_installer_lines() {
    local rc
    for rc in "$REAL_HOME/.bashrc" "$REAL_HOME/.zshrc"; do
        [[ -f "$rc" ]] && grep -q '# This loads nvm' "$rc" || continue
        filter_rc "$rc" '
            $0 == s { inblock = 1 }
            $0 == e { inblock = 0 }
            !inblock && ($0 ~ /^export NVM_DIR=/ || $0 ~ /# This loads nvm/) { next }
            { print }' -v "s=# --- Tool integrations ---" -v "e=# --- end Tool integrations ---"
        grep -qxF '# --- Tool integrations ---' "$rc" || write_tool_integrations "$rc"
        success "Removed nvm installer lines from $(basename "$rc") (the Tool-integrations block loads nvm)"
    done
}

do_nvm() {
    strip_nvm_installer_lines
    if nvm_lts_installed; then
        success "Node.js LTS already installed via nvm, skipping"
        return
    fi

    info "Installing NVM + Node.js LTS for user '$REAL_USER'..."
    command -v curl &>/dev/null || apt-get install -y curl

    if [[ ! -s "$REAL_HOME/.nvm/nvm.sh" ]]; then
        local nvm_tag
        nvm_tag=$(curl -fsSL --connect-timeout 10 --max-time 20 https://api.github.com/repos/nvm-sh/nvm/releases/latest 2>/dev/null \
            | grep -oP '"tag_name":\s*"\Kv[0-9.]+' | head -1 || true)
        nvm_tag="${nvm_tag:-v0.40.8}"
        info "Using nvm $nvm_tag"
        run_remote_script "$REAL_USER" "env PROFILE=/dev/null bash" "https://raw.githubusercontent.com/nvm-sh/nvm/$nvm_tag/install.sh" \
            || { fail "nvm installer failed"; return 1; }
    fi

    su - "$REAL_USER" -c "$NVM_LOAD"'
        from=""
        case "$(nvm current)" in none|system) ;; *) from="--reinstall-packages-from=current" ;; esac
        nvm install --lts $from && nvm alias default "lts/*"
    ' || { fail "nvm install --lts failed"; return 1; }

    success "NVM + Node.js LTS installed for '$REAL_USER' (default: lts/*)"
}

undo_nvm() {
    info "Removing NVM + Node.js..."
    su - "$REAL_USER" -c 'rm -rf "$HOME/.nvm"' 2>/dev/null || true
    success "NVM removed (PATH cleared on next login; .zshrc NVM lines live in the Tool-integrations block)"
}
