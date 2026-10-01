# shellcheck shell=bash

do_claude() {
    if [[ -x "$REAL_HOME/.local/bin/claude" ]]; then
        success "Claude Code already installed, skipping"
        return
    fi

    info "Installing Claude Code..."
    run_remote_script "$REAL_USER" bash https://claude.ai/install.sh || { fail "Claude Code installer failed"; return 1; }
    if [[ ! -x "$REAL_HOME/.local/bin/claude" ]]; then
        fail "Claude Code installer did not produce ~/.local/bin/claude"
        return 1
    fi
    success "Claude Code installed (run 'claude' to start)"
}

undo_claude() {
    info "Removing Claude Code..."
    rm -f "$REAL_HOME/.local/bin/claude"
    rm -rf "$REAL_HOME/.local/share/claude"
    warn "$REAL_HOME/.claude config directory left intact — remove manually if desired"
    success "Claude Code removed (~/.local/bin/claude & ~/.local/share/claude)"
}
