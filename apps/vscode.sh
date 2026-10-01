# shellcheck shell=bash

# The package launcher is now com.microsoft.VSCode.desktop and the dpkg hook adds the IME flags, so an old hand-made code.desktop is only a second icon.
remove_stale_vscode_launcher() {
    local stale="$REAL_HOME/.local/share/applications/code.desktop"
    [[ -f /usr/share/applications/com.microsoft.VSCode.desktop && -f "$stale" ]] || return 0
    grep -q '^Exec=/usr/share/code/.*--enable-wayland-ime' "$stale" || return 0
    rm -f "$stale"
    success "Removed duplicate VS Code launcher (~/.local/share/applications/code.desktop)"
}

do_vscode() {
    remove_stale_vscode_launcher
    if command -v code &>/dev/null; then
        success "VS Code already installed, skipping"
        return
    fi

    info "Installing Visual Studio Code..."
    ensure_microsoft_gpg || return 1
    add_apt_source /etc/apt/sources.list.d/vscode.list \
        "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" || return 1
    apt-get install -y code
    success "VS Code installed"
}

undo_vscode() {
    info "Removing VS Code..."
    apt_purge code
    rm -f /etc/apt/sources.list.d/vscode.{list,sources}
    success "VS Code removed"
}
