# shellcheck shell=bash

do_terminal() {
    info "Installing terminal utilities..."

    local p missing=()
    for p in zsh tmux htop jq ripgrep fzf git curl bat; do
        pkg_installed "$p" || missing+=("$p")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        apt-get install -y "${missing[@]}"
    fi
    if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
        ln -sf "$(command -v batcat)" /usr/local/bin/bat
    fi

    if ! command -v yq &>/dev/null; then
        info "Installing yq..."
        step_tmpdir
        if wget -q --tries=3 --timeout=30 -O "$STEP_TMP/yq" "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64" \
            && [[ -s "$STEP_TMP/yq" ]]; then
            install -m 755 "$STEP_TMP/yq" /usr/local/bin/yq
        else
            warn "Could not download yq, skipping"
        fi
    fi

    if [[ -d "$REAL_HOME/.oh-my-zsh" ]]; then
        success "Oh My Zsh already installed for '$REAL_USER'"
    else
        info "Installing Oh My Zsh for '$REAL_USER'..."
        # --unattended implies RUNZSH=no CHSH=no, which `su -` would otherwise strip from the environment.
        run_remote_script "$REAL_USER" sh https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh --unattended \
            || { fail "Oh My Zsh install failed"; return 1; }
    fi

    local plugin
    for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
        [[ -d "$REAL_HOME/.oh-my-zsh/custom/plugins/$plugin" ]] && continue
        su - "$REAL_USER" -c "git clone --depth 1 https://github.com/zsh-users/$plugin \"\$HOME/.oh-my-zsh/custom/plugins/$plugin\"" \
            || { fail "Could not clone $plugin"; return 1; }
    done
    ensure_zsh_plugins "$REAL_HOME/.zshrc" git zsh-autosuggestions zsh-syntax-highlighting

    # PATH/env for the runtimes lives in the shared Tool-integrations block.
    write_tool_integrations "$REAL_HOME/.zshrc"

    local cur_shell zsh_bin
    cur_shell=$(user_login_shell)
    zsh_bin=$(command -v zsh)
    if [[ "$cur_shell" == "$zsh_bin" ]]; then
        success "zsh is already the default shell for '$REAL_USER'"
    elif [[ "$ZSH_LOGIN_SHELL" == 1 ]]; then
        chsh -s "$zsh_bin" "$REAL_USER"
        need_reboot "login shell changed to zsh"
        success "Default shell changed to zsh (re-login to apply)"
    else
        info "Keeping the current login shell (zsh login turned off). zsh is installed — run 'zsh' anytime to use it"
    fi

    success "Terminal tools installed: zsh + oh-my-zsh (3 plugins), tmux, htop, jq, yq, rg, fzf, bat"
}

undo_terminal() {
    info "Removing terminal tools..."

    # A login shell pointing at a purged zsh would block login, so switch to bash first.
    local cur_shell
    cur_shell=$(user_login_shell)
    if [[ "$cur_shell" == *zsh ]]; then
        chsh -s "$(command -v bash)" "$REAL_USER" 2>/dev/null || true
        need_reboot "login shell reverted to bash"
        success "Default shell reverted to bash (re-login to apply)"
    fi

    # git/curl are intentionally kept — too many other things depend on them.
    apt_purge zsh tmux htop jq ripgrep fzf bat
    rm -f /usr/local/bin/yq /usr/local/bin/bat

    su - "$REAL_USER" -c 'rm -rf "$HOME/.oh-my-zsh"' 2>/dev/null || true
    strip_rc_block "Tool integrations" "$REAL_HOME/.zshrc"
    if runtimes_present; then
        write_tool_integrations "$REAL_HOME/.bashrc"
        info "Tool-integrations block kept in .bashrc — other runtimes still use it"
    else
        strip_rc_block "Tool integrations" "$REAL_HOME/.bashrc"
    fi
    if [[ -f "$REAL_HOME/.zshrc.pre-oh-my-zsh" ]]; then
        mv -f "$REAL_HOME/.zshrc.pre-oh-my-zsh" "$REAL_HOME/.zshrc"
        success "Restored ~/.zshrc from .zshrc.pre-oh-my-zsh"
    fi
    warn "Shell rc files left in place (Tool-integrations block removed from .zshrc)"
    success "Terminal tools removed (kept git & curl)"
}
