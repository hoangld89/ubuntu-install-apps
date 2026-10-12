# shellcheck shell=bash

FLAMESHOT_KEY_PATH=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/flameshot/

# Pre-grants capture, since GNOME blocks the portal dialog without a focused window: https://flameshot.org/docs/guide/wayland-help/
setup_flameshot_session() {
    command -v gsettings &>/dev/null || return 0
    run_in_user_session << EOF
set -e
gdbus call --session --dest org.freedesktop.impl.portal.PermissionStore \
    --object-path /org/freedesktop/impl/portal/PermissionStore \
    --method org.freedesktop.impl.portal.PermissionStore.SetPermission \
    screenshot true screenshot org.flameshot.Flameshot "['yes']" >/dev/null
gsettings writable org.gnome.shell.keybindings show-screenshot-ui >/dev/null 2>&1 || exit 0
list=\$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)
case "\$list" in *"'$FLAMESHOT_KEY_PATH'"*) exit 0 ;; esac
if [ "\$(gsettings get org.gnome.shell.keybindings show-screenshot-ui)" = "['Print']" ]; then
    gsettings set org.gnome.shell.keybindings show-screenshot-ui "[]"
fi
schema="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$FLAMESHOT_KEY_PATH"
gsettings set "\$schema" name 'Flameshot'
gsettings set "\$schema" command 'flameshot gui'
gsettings set "\$schema" binding 'Print'
case "\$list" in
    "@as []"|"[]") list="['$FLAMESHOT_KEY_PATH']" ;;
    *) list="\${list%]}, '$FLAMESHOT_KEY_PATH']" ;;
esac
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "\$list"
EOF
}

revert_flameshot_session() {
    command -v gsettings &>/dev/null || return 0
    run_in_user_session << EOF || true
gdbus call --session --dest org.freedesktop.impl.portal.PermissionStore \
    --object-path /org/freedesktop/impl/portal/PermissionStore \
    --method org.freedesktop.impl.portal.PermissionStore.DeletePermission \
    screenshot screenshot org.flameshot.Flameshot >/dev/null 2>&1
gsettings writable org.gnome.shell.keybindings show-screenshot-ui >/dev/null 2>&1 || exit 0
list=\$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)
case "\$list" in *"'$FLAMESHOT_KEY_PATH'"*) ;; *) exit 0 ;; esac
list=\$(printf '%s' "\$list" | sed -e "s#, '$FLAMESHOT_KEY_PATH'##" -e "s#'$FLAMESHOT_KEY_PATH', ##" -e "s#'$FLAMESHOT_KEY_PATH'##")
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "\$list" && dconf reset -f "$FLAMESHOT_KEY_PATH"
if [ "\$(gsettings get org.gnome.shell.keybindings show-screenshot-ui)" = "@as []" ]; then
    gsettings reset org.gnome.shell.keybindings show-screenshot-ui
fi
EOF
}

do_flameshot() {
    # Older toolkit releases installed the snap; it would shadow the apt build on PATH.
    if command -v snap &>/dev/null && snap list flameshot &>/dev/null; then
        info "Moving Flameshot from snap to apt..."
        snap remove --purge flameshot
    fi
    if pkg_installed flameshot; then
        info "Flameshot already installed, checking its screen capture permission and Print key..."
    else
        info "Installing Flameshot..."
        apt-get install -y flameshot
    fi
    if setup_flameshot_session; then
        success "Flameshot ready"
    else
        warn "Could not grant Flameshot screen capture (see the log) — capture may fail outside its Print shortcut"
        success "Flameshot installed"
    fi
}

undo_flameshot() {
    info "Removing Flameshot..."
    revert_flameshot_session
    apt_purge flameshot
    if command -v snap &>/dev/null && snap list flameshot &>/dev/null; then
        snap remove --purge flameshot
    fi
    success "Flameshot removed"
}
