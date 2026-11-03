# shellcheck shell=bash

TELEGRAM_DIR=/opt/telegram
TELEGRAM_DESKTOP=/usr/share/applications/org.telegram.desktop.desktop
TELEGRAM_ICON=/usr/share/icons/hicolor/256x256/apps/org.telegram.desktop.png
TELEGRAM_AUTOSTART=.config/autostart/org.telegram.desktop.desktop

telegram_fetch_icon() {
    step_tmpdir
    if wget -q --tries=3 --timeout=30 -O "$STEP_TMP/icon.png" \
        "https://raw.githubusercontent.com/telegramdesktop/tdesktop/dev/Telegram/Resources/art/icon256.png"; then
        install -Dm 644 "$STEP_TMP/icon.png" "$TELEGRAM_ICON"
        gtk-update-icon-cache -q /usr/share/icons/hicolor 2>/dev/null || true
    else
        warn "Could not download the Telegram icon"
    fi
}

do_telegram() {
    local url ver bin="$TELEGRAM_DIR/Telegram"
    if [[ "$(uname -m)" != x86_64 ]]; then
        warn "Telegram Desktop ships an x86_64 build only — skipped on $(uname -m)"
        return
    fi
    if pkg_installed telegram-desktop; then
        warn "Telegram is already installed from apt (telegram-desktop) — skipped"
        return
    fi

    url=$(redirect_target "https://telegram.org/dl/desktop/linux")
    if [[ ! "$url" =~ -([0-9]+(\.[0-9]+)+)\.tar\.xz$ ]]; then
        [[ -x "$bin" ]] || { fail "Could not find the latest Telegram Desktop release"; return 1; }
        warn "Could not check for a newer Telegram — keeping $(cat "$TELEGRAM_DIR/VERSION" 2>/dev/null)"
        return
    fi
    ver=${BASH_REMATCH[1]}
    if [[ -x "$bin" && "$(cat "$TELEGRAM_DIR/VERSION" 2>/dev/null)" == "$ver" ]]; then
        [[ -f "$TELEGRAM_ICON" ]] || telegram_fetch_icon
        success "Telegram $ver already installed, skipping"
        return
    fi

    info "Downloading Telegram $ver (~90 MB)..."
    step_tmpdir
    if ! wget -q --tries=3 --timeout=30 -O "$STEP_TMP/telegram.tar.xz" "$url" \
        || ! tar --no-same-owner -xJf "$STEP_TMP/telegram.tar.xz" -C "$STEP_TMP" Telegram/Telegram; then
        fail "Could not download or unpack $url"
        return 1
    fi
    install -Dm 755 "$STEP_TMP/Telegram/Telegram" "$bin.new"
    mv -f "$bin.new" "$bin"
    # Telegram skips its self-updater (it can't write /opt) and its per-user launcher when its path is listed here.
    mkdir -p "$TELEGRAM_DIR/externalupdater.d"
    echo "$bin" > "$TELEGRAM_DIR/externalupdater.d/toolkit"
    ln -sf "$bin" /usr/local/bin/telegram

    telegram_fetch_icon

    # With the updater off Telegram writes only argv[0]'s basename into its autostart entry, so launch it by a name on PATH.
    cat > "$TELEGRAM_DESKTOP" <<'DEOF'
[Desktop Entry]
Name=Telegram
Comment=Official Telegram Desktop client
Exec=telegram -- %U
Terminal=false
Type=Application
Icon=org.telegram.desktop
StartupWMClass=TelegramDesktop
Categories=Network;InstantMessaging;Chat;
MimeType=x-scheme-handler/tg;x-scheme-handler/tonsite;
Keywords=tg;chat;im;messaging;messenger;
SingleMainWindow=true
DEOF
    update-desktop-database -q /usr/share/applications 2>/dev/null || true
    echo "$ver" > "$TELEGRAM_DIR/VERSION"

    if pgrep -x '[Tt]elegram' >/dev/null; then
        warn "Telegram is running — restart it to use $ver"
    fi
    success "Telegram $ver installed (run 'telegram' or from app menu)"
}

undo_telegram() {
    info "Removing Telegram..."
    rm -rf "$TELEGRAM_DIR"
    rm -f /usr/local/bin/telegram
    pkg_installed telegram-desktop || rm -f "$TELEGRAM_DESKTOP" "$TELEGRAM_ICON"
    if grep -qE '^Exec=[Tt]elegram -autostart' "$REAL_HOME/$TELEGRAM_AUTOSTART" 2>/dev/null; then
        rm -f "$REAL_HOME/$TELEGRAM_AUTOSTART"
    fi
    gtk-update-icon-cache -q /usr/share/icons/hicolor 2>/dev/null || true
    update-desktop-database -q /usr/share/applications 2>/dev/null || true
    success "Telegram removed"
}
