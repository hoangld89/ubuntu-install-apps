# shellcheck shell=bash

# gsettings needs REAL_USER's dconf store and DBus session, so this runs as that user.
apply_terminal_font() {
    command -v gnome-terminal &>/dev/null || return 0
    command -v gsettings     &>/dev/null || return 0

    local font_script
    font_script=$(mktemp /tmp/term-font-XXXXXX.sh)
    cat > "$font_script" << 'FONT_EOF'
runtime_bus="/run/user/$(id -u)/bus"
[ -S "$runtime_bus" ] && export DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_bus"

profile=$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'")
[ -z "$profile" ] && exit 1
base="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$profile/"
gsettings set "$base" use-system-font false || exit 1
gsettings set "$base" font 'MesloLGS NF 12'  || exit 1
FONT_EOF
    chmod a+rx "$font_script"

    if su - "$REAL_USER" -c "bash $font_script" 2>/dev/null; then
        success "gnome-terminal font set to 'MesloLGS NF' (reopen the terminal to see icons)"
    else
        warn "Could not auto-set the terminal font — set it to 'MesloLGS NF' manually so icons render"
    fi
    rm -f "$font_script"
}

# Sites fall back to system fonts for Vietnamese diacritics: Noto covers them and emoji, Liberation the Arial/Helvetica stacks.
install_vn_web_fonts() {
    local pkgs=(fonts-noto-core fonts-noto-cjk fonts-noto-color-emoji fonts-liberation)
    local missing=() p
    for p in "${pkgs[@]}"; do
        dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q 'install ok installed' \
            || missing+=("$p")
    done
    if [[ ${#missing[@]} -eq 0 ]]; then
        success "Vietnamese web fonts already present (Noto + Liberation)"
        return
    fi
    info "Installing Vietnamese web fonts: ${missing[*]}"
    if apt-get install -y "${missing[@]}" >/dev/null 2>&1 || apt-get install -y "${missing[@]}"; then
        fc-cache -f >/dev/null 2>&1 || true
        success "Vietnamese web fonts installed — Facebook/browser diacritics fixed"
    else
        warn "Some Vietnamese web fonts failed to install (${missing[*]})"
    fi
}

do_font() {
    info "Installing fonts (Nerd Font + Vietnamese web fonts)..."

    # fontconfig provides fc-list / fc-cache — required for an accurate check.
    apt-get install -y fontconfig wget >/dev/null 2>&1 || apt-get install -y fontconfig wget

    # Web fonts run regardless of Nerd Font state (Nerd Font has an early return).
    install_vn_web_fonts

    local font_dir="/usr/local/share/fonts/MesloLGS-NF" font missing=()
    local faces_all=("MesloLGS NF Regular.ttf" "MesloLGS NF Bold.ttf" "MesloLGS NF Italic.ttf" "MesloLGS NF Bold Italic.ttf")
    for font in "${faces_all[@]}"; do
        [[ -s "$font_dir/$font" ]] || missing+=("$font")
    done
    if [[ ${#missing[@]} -eq 0 ]]; then
        success "MesloLGS Nerd Font already installed, skipping (${#faces_all[@]} faces)"
        apply_terminal_font
        return
    fi

    mkdir -p "$font_dir"
    step_tmpdir
    local base_url="https://github.com/romkatv/powerlevel10k-media/raw/master"
    for font in "${missing[@]}"; do
        if wget -q -O "$STEP_TMP/face.ttf" "$base_url/${font// /%20}" && [[ -s "$STEP_TMP/face.ttf" ]]; then
            install -m 644 "$STEP_TMP/face.ttf" "$font_dir/$font"
        else
            fail "Failed to download: $font"
            return 1
        fi
    done
    # Caching only $font_dir can leave the parent-dir cache stale, hiding the new faces from fc-list.
    fc-cache -f >/dev/null 2>&1 || true

    # The .ttf files decide success; fc-list can lag behind its cache, so it only gets a short retry.
    local faces=0 i
    for i in 1 2 3; do
        faces=$(fc-list 2>/dev/null | grep -ci 'MesloLGS NF' || true)
        [[ $faces -gt 0 ]] && break
        fc-cache -f >/dev/null 2>&1 || true
    done

    if [[ $faces -gt 0 ]]; then
        success "MesloLGS Nerd Font installed & verified ($faces faces)"
    else
        success "MesloLGS Nerd Font installed (${#faces_all[@]} files); fontconfig cache will refresh on next login"
    fi
    apply_terminal_font
}

# The profile must stop pointing at the Nerd Font before it is deleted.
revert_terminal_font() {
    command -v gnome-terminal &>/dev/null || return 0
    command -v gsettings     &>/dev/null || return 0

    local font_script
    font_script=$(mktemp /tmp/term-font-XXXXXX.sh)
    cat > "$font_script" << 'FONT_EOF'
runtime_bus="/run/user/$(id -u)/bus"
[ -S "$runtime_bus" ] && export DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_bus"

profile=$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'")
[ -z "$profile" ] && exit 1
base="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$profile/"
# Only revert if we are the one who set it, to avoid clobbering a user choice.
[ "$(gsettings get "$base" font 2>/dev/null | tr -d "'")" = "MesloLGS NF 12" ] || exit 0
gsettings set "$base" use-system-font true
FONT_EOF
    chmod a+rx "$font_script"
    su - "$REAL_USER" -c "bash $font_script" 2>/dev/null || true
    rm -f "$font_script"
}

undo_font() {
    info "Removing MesloLGS Nerd Font..."
    revert_terminal_font
    rm -rf /usr/local/share/fonts/MesloLGS-NF
    fc-cache -f >/dev/null 2>&1 || true
    if fc-list 2>/dev/null | grep -qi 'MesloLGS NF'; then
        warn "MesloLGS NF still detected — it may be installed elsewhere (e.g. user fonts)"
    else
        success "MesloLGS Nerd Font removed"
    fi
    # Noto/Liberation stay: the desktop and browsers depend on them.
    info "Vietnamese web fonts (Noto/Liberation) left installed — shared with the desktop"
}
