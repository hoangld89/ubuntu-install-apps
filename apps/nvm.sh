# shellcheck shell=bash

nvm_lts_installed() {
    su - "$REAL_USER" -c "$NVM_LOAD"'
        command -v nvm >/dev/null 2>&1 || exit 1
        lts=$(nvm version-remote --lts 2>/dev/null) || exit 1
        [ "$(nvm version "$lts")" = "$lts" ]
    ' &>/dev/null
}

nvm_release() {
    su - "$REAL_USER" -c "$NVM_LOAD"'; nvm --version' 2>/dev/null || true
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
    local nvm_tag nvm_cur
    nvm_tag=$(github_latest_tag nvm-sh/nvm)
    nvm_cur=$(nvm_release)
    if [[ -n "$nvm_cur" && ( -z "$nvm_tag" || "$nvm_cur" == "${nvm_tag#v}" ) ]] && nvm_lts_installed; then
        success "Node.js LTS and nvm $nvm_cur already at the latest release, skipping"
        return
    fi

    info "Installing NVM + Node.js LTS for user '$REAL_USER'..."
    command -v curl &>/dev/null || apt-get install -y curl

    if [[ -z "$nvm_cur" || ( -n "$nvm_tag" && "$nvm_cur" != "${nvm_tag#v}" ) ]]; then
        nvm_tag="${nvm_tag:-v0.40.8}"
        info "Using nvm $nvm_tag"
        run_remote_script "$REAL_USER" "env PROFILE=/dev/null bash" "https://raw.githubusercontent.com/nvm-sh/nvm/$nvm_tag/install.sh" \
            || { fail "nvm installer failed"; return 1; }
    fi

    # nvm drops the corepack package (the pnpm/yarn shims) on reinstall; only the new LTS line's older releases are pruned.
    su - "$REAL_USER" -c "$NVM_LOAD"'
        lts=$(nvm version-remote --lts) || exit 1
        from="" cp=""
        case "$(nvm current)" in none|system|"$lts") ;; *) from="--reinstall-packages-from=current" ;; esac
        case "$(readlink -f "$(command -v pnpm || command -v yarn)" 2>/dev/null)" in
            */node_modules/corepack/*) cp=$(corepack --version 2>/dev/null) ;;
        esac
        nvm install "$lts" $from && nvm alias default "lts/*" || exit 1
        if [ -n "$from" ] && [ -n "$cp" ]; then npm install -g "corepack@$cp" || exit 1; fi
        major=${lts#v}; major=${major%%.*}
        nvm ls --no-colors "$major" | grep -oE "v[0-9]+\.[0-9]+\.[0-9]+" | sort -u | while read -r v; do
            [ "$v" = "$lts" ] || nvm uninstall "$v" || true
        done
    ' || { fail "nvm install --lts failed"; return 1; }

    success "NVM $(nvm_release) + Node.js LTS installed for '$REAL_USER' (default: lts/*)"
}

undo_nvm() {
    info "Removing NVM + Node.js..."
    su - "$REAL_USER" -c 'rm -rf "$HOME/.nvm"' 2>/dev/null || true
    success "NVM removed (PATH cleared on next login; .zshrc NVM lines live in the Tool-integrations block)"
}
