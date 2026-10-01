# shellcheck shell=bash

do_fcitx5() {
    # Per-engine package, plus the IM addon name written into the fcitx5 profile.
    local im_name="$IME_ENGINE" engine_pkg
    case "$IME_ENGINE" in
        bamboo|lotus) engine_pkg="fcitx5-$IME_ENGINE" ;;
        *)            im_name="unikey"; engine_pkg="fcitx5-unikey" ;;
    esac

    if pkg_installed fcitx5 && pkg_installed "$engine_pkg" \
        && grep -qx 'GTK_IM_MODULE=fcitx' /etc/environment \
        && grep -qx "Name=${im_name}" "$REAL_HOME/.config/fcitx5/profile" 2>/dev/null; then
        success "Fcitx5 + ${im_name} already installed & configured, skipping"
        return
    fi

    info "Installing Fcitx5 with Vietnamese input (engine: ${im_name})..."

    # Base fcitx5 runtime + GTK/Qt frontends — shared across every engine.
    apt-get install -y fcitx5 fcitx5-config-qt \
        fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 fcitx5-frontend-qt5

    if [[ "$im_name" == lotus ]]; then
        # Lotus is a third-party fcitx5 addon distributed via its own signed
        # apt repo (not in Ubuntu's archive), keyed per release codename.
        local lotus_list=/etc/apt/sources.list.d/fcitx5-lotus.list lotus_key=/etc/apt/keyrings/fcitx5-lotus.gpg lotus_codename
        lotus_codename=$(get_ubuntu_codename)
        if [[ ! -f "$lotus_list" || ! -s "$lotus_key" ]]; then
            add_apt_repo "$lotus_list" https://fcitx5-lotus.pages.dev/pubkey.gpg "$lotus_key" 1 \
                "deb [arch=amd64 signed-by=$lotus_key] https://fcitx5-lotus.pages.dev/apt/${lotus_codename} ${lotus_codename} main" \
                || return 1
        fi
    fi
    apt-get install -y "$engine_pkg"

    # ── IM environment variables ──────────────────────────────────────────
    # Ubuntu 24.04 dropped PAM's reading of ~/.pam_environment, and on Wayland
    # (GNOME default) ~/.xprofile is never sourced. /etc/environment is read by
    # pam_env for every login session — X11 *and* Wayland — so it's the one
    # reliable place for IM vars.
    local env_file="/etc/environment" env_before
    env_before=$(cksum < "$env_file")
    sed -i -E '/^(GTK_IM_MODULE|QT_IM_MODULE|XMODIFIERS|SDL_IM_MODULE|GLFW_IM_MODULE)=/d' "$env_file"
    cat >> "$env_file" <<'ENVEOF'
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
GLFW_IM_MODULE=ibus
ENVEOF
    [[ "$(cksum < "$env_file")" == "$env_before" ]] || need_reboot "/etc/environment changed (fcitx5 input-method variables)"

    # ── Autostart on login (X11 + Wayland) ────────────────────────────────
    # The fcitx5 package ships a system autostart entry; we add a per-user one
    # explicitly so it starts regardless of session type / desktop.
    local autostart_dir="$REAL_HOME/.config/autostart"
    mkdir -p "$autostart_dir"
    cat > "$autostart_dir/fcitx5.desktop" <<'DEOF'
[Desktop Entry]
Type=Application
Name=Fcitx 5
Icon=fcitx
Exec=fcitx5
X-GNOME-Autostart-Phase=Applications
X-GNOME-Autostart-enabled=true
DEOF

    # ── Preselect Unikey ──────────────────────────────────────────────────
    local fcitx_conf_dir="$REAL_HOME/.config/fcitx5"
    local profile_file="$fcitx_conf_dir/profile"
    mkdir -p "$fcitx_conf_dir"
    cat > "$profile_file" <<PROFEOF
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=${im_name}

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=${im_name}
Layout=

[GroupOrder]
0=Default
PROFEOF
    chown -R "$REAL_USER:$REAL_USER" "$autostart_dir" "$fcitx_conf_dir"

    # Migrate away from the legacy locations an older script version may have
    # written, so stale settings don't fight the new ones.
    rm -f "$REAL_HOME/.pam_environment"
    if [[ -f "$REAL_HOME/.xprofile" ]]; then
        sed -i '/fcitx/d; /GTK_IM_MODULE/d; /QT_IM_MODULE/d; /XMODIFIERS/d' "$REAL_HOME/.xprofile"
        chown "$REAL_USER:$REAL_USER" "$REAL_HOME/.xprofile" 2>/dev/null || true
    fi

    success "Fcitx5 + ${im_name} installed & configured (log out and back in to activate)"
}

undo_fcitx5() {
    info "Removing Fcitx5..."
    # Purge every engine we might have installed, whichever was selected.
    apt_purge fcitx5 fcitx5-unikey fcitx5-bamboo fcitx5-lotus fcitx5-config-qt \
        fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 fcitx5-frontend-qt5

    # Drop the third-party Lotus apt repo + key if they were added.
    rm -f /etc/apt/sources.list.d/fcitx5-lotus.list /etc/apt/keyrings/fcitx5-lotus.gpg

    # Strip the IM vars from /etc/environment (leave the rest untouched).
    grep -qE '^(GTK_IM_MODULE|QT_IM_MODULE|XMODIFIERS)=' /etc/environment && need_reboot "/etc/environment changed (fcitx5 variables removed)"
    sed -i -E '/^(GTK_IM_MODULE|QT_IM_MODULE|XMODIFIERS|SDL_IM_MODULE|GLFW_IM_MODULE)=/d' /etc/environment

    # Remove the config + autostart entry this script created.
    su - "$REAL_USER" -c 'rm -rf "$HOME/.config/fcitx5" "$HOME/.config/autostart/fcitx5.desktop"' 2>/dev/null || true

    # Clean up legacy locations from older script versions.
    rm -f "$REAL_HOME/.pam_environment"
    if [[ -f "$REAL_HOME/.xprofile" ]]; then
        sed -i '/fcitx/d; /GTK_IM_MODULE/d; /QT_IM_MODULE/d; /XMODIFIERS/d' "$REAL_HOME/.xprofile"
        chown "$REAL_USER:$REAL_USER" "$REAL_HOME/.xprofile" 2>/dev/null || true
    fi

    success "Fcitx5 removed (packages, env vars & config cleaned — re-login to apply)"
}
