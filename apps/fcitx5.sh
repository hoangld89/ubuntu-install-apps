# shellcheck shell=bash

do_fcitx5() {
    # Per-engine package, plus the IM addon name written into the fcitx5 profile.
    local im_name="$IME_ENGINE" engine_pkg
    case "$IME_ENGINE" in
        bamboo|lotus|ngosen) engine_pkg="fcitx5-$IME_ENGINE" ;;
        *)                   im_name="unikey"; engine_pkg="fcitx5-unikey" ;;
    esac

    if pkg_installed fcitx5 && pkg_installed "$engine_pkg" \
        && grep -qx 'GTK_IM_MODULE=fcitx' /etc/environment \
        && grep -qx "Name=${im_name}" "$REAL_HOME/.config/fcitx5/profile" 2>/dev/null; then
        [[ "$im_name" == ngosen ]] && ngosen_enable_key_fix
        success "Fcitx5 + ${im_name} already installed & configured, skipping"
        return
    fi

    info "Installing Fcitx5 with Vietnamese input (engine: ${im_name})..."

    apt-get install -y fcitx5 fcitx5-config-qt \
        fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 fcitx5-frontend-qt5

    # Lotus and Ngó Sen are not in Ubuntu's archive; their signed apt repos are keyed per codename.
    local codename repo_list repo_key
    codename=$(get_ubuntu_codename)
    repo_list="/etc/apt/sources.list.d/${engine_pkg}.list"
    repo_key="/etc/apt/keyrings/${engine_pkg}.gpg"
    if [[ "$im_name" == lotus && ( ! -f "$repo_list" || ! -s "$repo_key" ) ]]; then
        add_apt_repo "$repo_list" https://fcitx5-lotus.pages.dev/pubkey.gpg "$repo_key" 1 \
            "deb [arch=amd64 signed-by=$repo_key] https://fcitx5-lotus.pages.dev/apt/${codename} ${codename} main" \
            || return 1
    elif [[ "$im_name" == ngosen && ( ! -f "$repo_list" || ! -s "$repo_key" ) ]]; then
        add_apt_repo "$repo_list" https://ngosen.github.io/ngosen/apt/ngosen.gpg "$repo_key" 0 \
            "deb [arch=amd64 signed-by=$repo_key] https://ngosen.github.io/ngosen/apt ${codename} main" \
            || return 1
    fi
    apt-get install -y "$engine_pkg"

    # pam_env reads /etc/environment on X11 and Wayland; ~/.pam_environment is no longer read and Wayland never sources ~/.xprofile.
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

    # A per-user autostart entry starts fcitx5 regardless of session type or desktop.
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
    [[ "$im_name" == ngosen ]] && ngosen_enable_key_fix

    # An older script version wrote these locations; stale settings would fight the new ones.
    rm -f "$REAL_HOME/.pam_environment"
    if [[ -f "$REAL_HOME/.xprofile" ]]; then
        sed -i '/fcitx/d; /GTK_IM_MODULE/d; /QT_IM_MODULE/d; /XMODIFIERS/d' "$REAL_HOME/.xprofile"
        chown "$REAL_USER:$REAL_USER" "$REAL_HOME/.xprofile" 2>/dev/null || true
    fi

    success "Fcitx5 + ${im_name} installed & configured (log out and back in to activate)"
}

NGOSEN_KEY_FIX_UUID=forward-keys@ngosen.github.io
NGOSEN_KEY_FIX_DIR=/usr/share/gnome-shell/extensions/$NGOSEN_KEY_FIX_UUID

# GNOME 50.0-50.3 drop keys an IME forwards, Ngó Sen's extension delivers them: https://bugs.launchpad.net/ubuntu/+source/mutter/+bug/2169784
ngosen_enable_key_fix() {
    local uuid=$NGOSEN_KEY_FIX_UUID re='^GNOME Shell 50\.[0-3]$'
    [[ -d "$NGOSEN_KEY_FIX_DIR" ]] || return 0
    [[ "$(gnome-shell --version 2>/dev/null)" =~ $re ]] || return 0
    run_in_user_session <<EOF \
        || warn "Ngó Sen's GNOME typing fix is off; log in, turn Extensions on, then run: gnome-extensions enable $uuid"
set -e
[ -S "\$runtime_bus" ]
[ "\$(gsettings get org.gnome.shell disable-user-extensions)" = false ]
gsettings_list_remove org.gnome.shell disabled-extensions '$uuid'
gsettings_list_add org.gnome.shell enabled-extensions '$uuid'
EOF
}

ngosen_disable_key_fix() {
    [[ -d "$NGOSEN_KEY_FIX_DIR" ]] || return 0
    run_in_user_session <<<"gsettings_list_remove org.gnome.shell enabled-extensions '$NGOSEN_KEY_FIX_UUID'" || true
}

undo_fcitx5() {
    info "Removing Fcitx5..."
    ngosen_disable_key_fix
    # Purge every engine we might have installed, whichever was selected.
    apt_purge fcitx5 fcitx5-unikey fcitx5-bamboo fcitx5-lotus fcitx5-ngosen fcitx5-config-qt \
        fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 fcitx5-frontend-qt5

    rm -f /etc/apt/sources.list.d/fcitx5-lotus.list /etc/apt/keyrings/fcitx5-lotus.gpg \
        /etc/apt/sources.list.d/fcitx5-ngosen.list /etc/apt/keyrings/fcitx5-ngosen.gpg

    grep -qE '^(GTK_IM_MODULE|QT_IM_MODULE|XMODIFIERS)=' /etc/environment && need_reboot "/etc/environment changed (fcitx5 variables removed)"
    sed -i -E '/^(GTK_IM_MODULE|QT_IM_MODULE|XMODIFIERS|SDL_IM_MODULE|GLFW_IM_MODULE)=/d' /etc/environment

    su - "$REAL_USER" -c 'rm -rf "$HOME/.config/fcitx5" "$HOME/.config/autostart/fcitx5.desktop"' 2>/dev/null || true

    rm -f "$REAL_HOME/.pam_environment"
    if [[ -f "$REAL_HOME/.xprofile" ]]; then
        sed -i '/fcitx/d; /GTK_IM_MODULE/d; /QT_IM_MODULE/d; /XMODIFIERS/d' "$REAL_HOME/.xprofile"
        chown "$REAL_USER:$REAL_USER" "$REAL_HOME/.xprofile" 2>/dev/null || true
    fi

    success "Fcitx5 removed (packages, env vars & config cleaned — re-login to apply)"
}
