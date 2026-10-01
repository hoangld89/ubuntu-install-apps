# shellcheck shell=bash

# Remove a marked block from the user's shell rc files. Install steps wrap their
# additions in `# --- <label> ---` … `# --- end <label> ---` so this deletes them
# cleanly from every rc they landed in (.bashrc, plus .zshrc when zsh is installed).
# Runs as root but rewrites REAL_USER's files and restores ownership.
strip_rc_block() {
    local label="$1" rc
    shift
    local files=("$@")
    (( ${#files[@]} )) || files=("$REAL_HOME/.zshrc" "$REAL_HOME/.bashrc")
    # An unclosed start marker is printed back untouched instead of eating the rest of the file.
    for rc in "${files[@]}"; do
        filter_rc "$rc" '
            $0 == s && !open { open = 1; buf = $0 ORS; next }
            open { buf = buf $0 ORS; if ($0 == e) { open = 0; buf = "" }; next }
            { print }
            END { if (open) printf "%s", buf }' -v "s=# --- $label ---" -v "e=# --- end $label ---" || return 1
    done
}

filter_rc() {
    local rc="$1" prog="$2" tmp
    shift 2
    [[ -f "$rc" ]] || return 0
    tmp=$(mktemp)
    if ! awk "$@" "$prog" "$rc" > "$tmp"; then
        rm -f "$tmp"
        return 1
    fi
    if ! cmp -s "$tmp" "$rc"; then
        # One .bak per run, so several edits to the same rc still leave the pre-run copy.
        local marker="$RUN_DIR/bak${rc//\//_}"
        if [[ ! -e "$marker" ]]; then
            cp -p "$rc" "$rc.bak" || { rm -f "$tmp"; return 1; }
            mkdir -p "$RUN_DIR" && touch "$marker"
        fi
        cat "$tmp" > "$rc" || { cp -p "$rc.bak" "$rc"; rm -f "$tmp"; return 1; }
        chown "$REAL_USER:$REAL_USER" "$rc" "$rc.bak" 2>/dev/null || true
    fi
    rm -f "$tmp"
}

# Shell config goes to every installed shell, so the login-shell choice never decides whether tools are on PATH.
target_shell_rcs() {
    echo "$REAL_HOME/.bashrc"
    if command -v zsh &>/dev/null; then echo "$REAL_HOME/.zshrc"; fi
}

runtimes_present() {
    [[ -d "$REAL_HOME/.nvm" || -d "$REAL_HOME/.bun" || -x /usr/bin/dotnet || -d "$REAL_HOME/.dotnet/tools" \
        || -x /usr/bin/az || -e "$REAL_HOME/.local/bin/claude" || -d "$REAL_HOME/.local/share/pnpm" ]]
}

tool_integrations_block() {
    cat <<'TOOLEOF'
# --- Tool integrations ---
# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Bun
[ -d "$HOME/.bun" ] && export BUN_INSTALL="$HOME/.bun" && export PATH="$BUN_INSTALL/bin:$PATH"

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in *":$PNPM_HOME:"*) ;; *) export PATH="$PNPM_HOME:$PATH" ;; esac

# .NET
if [ -x /usr/bin/dotnet ]; then
    DOTNET_ROOT="$(dirname "$(readlink -f /usr/bin/dotnet)")"
    export DOTNET_ROOT
fi
[ -d "$HOME/.dotnet/tools" ] && export PATH="$PATH:$HOME/.dotnet/tools"

# Azure CLI completions
if [ -f /etc/bash_completion.d/azure-cli ]; then
    if [ -n "$ZSH_VERSION" ]; then
        autoload -U +X bashcompinit && bashcompinit
    fi
    source /etc/bash_completion.d/azure-cli
fi

# Claude Code (native installer symlinks the CLI into ~/.local/bin)
if [ -d "$HOME/.local/bin" ]; then
    case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
fi
# --- end Tool integrations ---
TOOLEOF
}

# Write the shared Tool-integrations block into $1, replacing an existing copy in place so script updates reach old machines.
write_tool_integrations() {
    local rc="$1" block
    [[ -n "$rc" ]] || return 0
    [[ -e "$rc" ]] || touch "$rc"
    block=$(mktemp) || return 1
    tool_integrations_block > "$block"
    if grep -qxF '# --- Tool integrations ---' "$rc" && grep -qxF '# --- end Tool integrations ---' "$rc"; then
        filter_rc "$rc" '
            $0 == s && !done { while ((getline line < f) > 0) print line; skip = 1; next }
            skip { if ($0 == e) { skip = 0; done = 1 }; next }
            { print }' -v "f=$block" -v "s=# --- Tool integrations ---" -v "e=# --- end Tool integrations ---" \
            || { rm -f "$block"; return 1; }
    else
        { echo ""; cat "$block"; } >> "$rc" || { rm -f "$block"; return 1; }
    fi
    rm -f "$block"
    chown "$REAL_USER:$REAL_USER" "$rc" 2>/dev/null || true
}

# Wayland input-method flags for Chromium/Electron apps — without them fcitx5
# can't type into these apps under a Wayland session. `-hint=auto` picks Wayland
# when available and falls back to X11, so the flags are safe on either session.
WAYLAND_IME_FLAGS="--enable-features=UseOzonePlatform --ozone-platform-hint=auto --enable-wayland-ime --wayland-text-input-version=3"

# Chromium/Electron launchers that get the flags. Both VS Code names are listed:
# newer `code` packages ship com.microsoft.VSCode.desktop instead of code.desktop.
WAYLAND_IME_LAUNCHERS=(
    /usr/share/applications/google-chrome.desktop
    /usr/share/applications/microsoft-edge.desktop
    /usr/share/applications/teams-for-linux.desktop
    /usr/share/applications/com.microsoft.VSCode.desktop
    /usr/share/applications/code.desktop
    /usr/share/applications/trae.desktop
    /usr/share/applications/postman.desktop
)
WAYLAND_IME_HOOK=/usr/local/sbin/wayland-ime-launchers
WAYLAND_IME_APT_CONF=/etc/apt/apt.conf.d/99wayland-ime-launchers

# Package upgrades rewrite their .desktop files and drop the flags, so instead of
# patching once we install a helper that dpkg re-runs after every apt operation.
# The helper is idempotent: the x11-strip is a no-op when absent, and the flag
# injection skips files that already carry them. Missing launchers are skipped.
enable_wayland_ime() {
    # Ubuntu 26.04 is Wayland-first. Some launchers (e.g. teams-for-linux) ship a
    # hard `--ozone-platform=x11` that conflicts with our `-hint=auto`: the
    # explicit flag wins and pins the app to X11, which breaks Wayland IME and —
    # on some GPUs — crashes the app (SIGILL/GPU-process). Strip it so the Ozone
    # platform resolves consistently through the hint.
    cat > "$WAYLAND_IME_HOOK" <<HOOKEOF
#!/bin/sh
# Generated by install-app.sh: re-applies Wayland IME flags after every dpkg run.
for f in ${WAYLAND_IME_LAUNCHERS[*]}; do
    [ -f "\$f" ] || continue
    if grep -q -- ' --ozone-platform=x11' "\$f"; then
        sed -i -E 's# --ozone-platform=x11\\b##g' "\$f"
    fi
    if ! grep -q -- '--enable-wayland-ime' "\$f"; then
        sed -i -E 's#^(Exec=(env( +[A-Za-z_][A-Za-z0-9_]*=[^ ]*)+ +)?[^ ]+)#\\1 ${WAYLAND_IME_FLAGS}#' "\$f"
    fi
done
HOOKEOF
    [[ -s "$WAYLAND_IME_HOOK" ]] || return 1
    chmod 755 "$WAYLAND_IME_HOOK" || return 1
    echo "DPkg::Post-Invoke { \"[ -x ${WAYLAND_IME_HOOK} ] && ${WAYLAND_IME_HOOK} || true\"; };" \
        > "$WAYLAND_IME_APT_CONF" || return 1
    "$WAYLAND_IME_HOOK" || true
}

# Drop the dpkg hook once the last app it patches has been uninstalled.
remove_wayland_ime_if_unused() {
    local f
    for f in "${WAYLAND_IME_LAUNCHERS[@]}"; do
        [[ -f "$f" ]] && return 0
    done
    rm -f "$WAYLAND_IME_HOOK" "$WAYLAND_IME_APT_CONF"
    if grep -q '^ELECTRON_OZONE_PLATFORM_HINT=' /etc/environment 2>/dev/null; then
        sed -i '/^ELECTRON_OZONE_PLATFORM_HINT=/d' /etc/environment
        need_reboot "/etc/environment changed (Electron Wayland hint removed)"
    fi
}
