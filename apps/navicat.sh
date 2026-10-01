# shellcheck shell=bash

remove_navicat_user_entries() {
    rm -f "$REAL_HOME"/.local/share/applications/Navicat.Premium.*.desktop \
        "$REAL_HOME"/.local/share/icons/hicolor/256x256/apps/"Navicat Premium Lite "*.png
}

do_navicat() {
    local version=18
    local install_dir="/opt/navicat-premium-lite"
    local appimage="$install_dir/navicat.AppImage"

    # SQL Server needs the unversioned libodbc.so, shipped only by unixodbc-dev
    if ! dpkg -s unixodbc-dev >/dev/null 2>&1; then
        info "Installing unixODBC for Navicat SQL Server connections..."
        apt-get install -y unixodbc-dev >/dev/null 2>&1 || apt-get install -y unixodbc-dev
    fi

    if [[ "$(cat "$install_dir/VERSION" 2>/dev/null)" == "$version" ]]; then
        success "Navicat Premium Lite $version already installed, skipping"
        return
    fi

    if pgrep -f '\.mount_navica|navicat-premium-lite/navicat\.AppImage' >/dev/null; then
        warn "Navicat is running — close it and re-run to install Navicat Premium Lite $version"
        return
    fi

    info "Installing Navicat Premium Lite $version..."
    step_tmpdir
    local tmp_dir="$STEP_TMP"

    local download="$tmp_dir/navicat.AppImage"
    if ! wget -q -O "$download" "https://download.navicat.com/download/navicat${version}-premium-lite-en-x86_64.AppImage" \
        || [[ ! -s "$download" ]]; then
        fail "Could not download Navicat Premium Lite $version"
        return 1
    fi
    chmod +x "$download"

    if [[ -f "$appimage" ]]; then
        local config_dir="$REAL_HOME/.config/navicat"
        if [[ -d "$config_dir" ]]; then
            local backup
            backup="$config_dir.bak-$(date +%Y%m%d-%H%M%S)"
            cp -a "$config_dir" "$backup"
            chown -R "$REAL_USER": "$backup"
            info "Backed up Navicat settings to $backup"
        fi
        remove_navicat_user_entries
    fi

    mkdir -p "$install_dir"
    mv "$download" "$appimage"
    (cd "$tmp_dir" && "$appimage" --appimage-extract icon.png >/dev/null 2>&1 \
        && install -Dm 644 squashfs-root/icon.png /usr/share/icons/hicolor/256x256/apps/navicat-premium-lite.png) \
        || warn "Could not extract the Navicat icon"
    gtk-update-icon-cache -q /usr/share/icons/hicolor 2>/dev/null || true

    # Same basename as Navicat's self-registered entry so it shadows ours, not duplicates
    rm -f /usr/share/applications/navicat-premium-lite.desktop /usr/share/applications/Navicat.Premium.*.desktop
    # WM_CLASS is AppRun (Qt uses argv[0]), so StartupWMClass must match it
    cat > "/usr/share/applications/Navicat.Premium.$version.desktop" <<DEOF
[Desktop Entry]
Name=Navicat Premium Lite $version
Exec=$appimage
Type=Application
Icon=navicat-premium-lite
Categories=Development;Database;
Comment=Database Management Tool
StartupWMClass=AppRun
DEOF

    ln -sf "$appimage" /usr/local/bin/navicat
    echo "$version" > "$install_dir/VERSION"

    success "Navicat Premium Lite $version installed (run 'navicat' or from app menu)"
}

undo_navicat() {
    info "Removing Navicat Premium Lite..."
    rm -rf /opt/navicat-premium-lite
    rm -f /usr/share/applications/navicat-premium-lite.desktop /usr/share/applications/Navicat.Premium.*.desktop
    rm -f /usr/local/bin/navicat /usr/share/icons/hicolor/256x256/apps/navicat-premium-lite.png
    gtk-update-icon-cache -q /usr/share/icons/hicolor 2>/dev/null || true
    remove_navicat_user_entries
    info "unixodbc-dev stays installed — other ODBC tools may use it (apt purge unixodbc-dev to drop it)"
    success "Navicat Premium Lite removed"
}
