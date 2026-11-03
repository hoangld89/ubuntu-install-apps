# shellcheck shell=bash

ZALO_REPO=VN-Linux-Family/zalo-for-linux
ZALO_DIR=/opt/zalo
ZALO_APPARMOR=/etc/apparmor.d/zalo-appimage
ZALO_PKGS_MARKER="$STATE_DIR/zalo-packages"
ZALO_I386_MARKER="$STATE_DIR/zalo-i386"
ZALO_CALL_PKGS=(python3 libopus0 pulseaudio-utils)

zalo_appimage_url() {  # $1 tag, $2 arch → URL of its Original AppImage (the name carries a commit hash), empty when offline
    local href
    href=$(curl -fsSL --connect-timeout 10 --max-time 60 "https://github.com/$ZALO_REPO/releases/expanded_assets/$1" 2>/dev/null \
        | grep -o "href=\"[^\"]*/Zalo-$1-Original-[0-9a-f]*-$2\.AppImage\"" | head -n 1 || true)
    [[ -n "$href" ]] && printf 'https://github.com%s' "$(cut -d'"' -f2 <<< "$href")"
    return 0
}

# Mark auto, not purge: autoremove keeps whatever another package (wine32, Steam...) now depends on.
zalo_release_packages() {
    local pkgs=()
    [[ -f "$ZALO_PKGS_MARKER" ]] || return 0
    mapfile -t pkgs < <(sort -u "$ZALO_PKGS_MARKER")
    apt-mark auto "${pkgs[@]}" >/dev/null 2>&1 || true
    apt-get autoremove --purge -y >/dev/null 2>&1 || true
    rm -f "$ZALO_PKGS_MARKER"
}

# autoremove keeps required libs (libc6:i386); purge the rest only when no amd64 package (wine, Steam...) needs them.
zalo_remove_i386() {
    local pkgs=()
    [[ -f "$ZALO_I386_MARKER" ]] || return 0
    mapfile -t pkgs < <(dpkg-query -W -f='${Package}:${Architecture}\n' 2>/dev/null | grep ':i386$' || true)
    if (( ${#pkgs[@]} )) && ! apt-mark showmanual | grep ':i386$' >/dev/null \
        && ! apt-get purge -s --allow-remove-essential "${pkgs[@]}" 2>/dev/null | grep -E '^Purg [^ :]+ ' >/dev/null; then
        apt-get purge -y --allow-remove-essential "${pkgs[@]}" >/dev/null 2>&1 || true
    fi
    if dpkg --remove-architecture i386 2>/dev/null; then
        apt-get update >/dev/null 2>&1 || true
        rm -f "$ZALO_I386_MARKER"
    else
        warn "Other packages still use i386 — kept the i386 architecture"
    fi
}

# Runs only once the installed AppImage has native calls: the old Full build's Wine needs these libraries.
zalo_drop_wine_libs() {
    local old=() removable=() keep=()
    if [[ -f "$ZALO_PKGS_MARKER" ]]; then
        mapfile -t old < <(grep -vxF -f <(printf '%s\n' "${ZALO_CALL_PKGS[@]}") "$ZALO_PKGS_MARKER" | sort -u || true)
    fi
    (( ${#old[@]} )) || [[ -f "$ZALO_I386_MARKER" ]] || return 0
    info "Removing the i386 Wine libraries older Zalo releases needed..."
    if (( ${#old[@]} )); then
        apt-mark auto "${old[@]}" >/dev/null 2>&1 || true
        mapfile -t removable < <(apt-get autoremove -s 2>/dev/null | awk '/^Remv /{print $2}' | grep -xF -f <(printf '%s\n' "${old[@]}") || true)
        if (( ${#removable[@]} )); then
            apt-get purge -y "${removable[@]}" >/dev/null 2>&1 || true
        fi
        mapfile -t keep < <(grep -xF -f <(printf '%s\n' "${ZALO_CALL_PKGS[@]}") "$ZALO_PKGS_MARKER" | sort -u || true)
        if (( ${#keep[@]} )); then printf '%s\n' "${keep[@]}" > "$ZALO_PKGS_MARKER"; else rm -f "$ZALO_PKGS_MARKER"; fi
    fi
    if [[ -f "$ZALO_I386_MARKER" ]]; then
        zalo_remove_i386
        rm -f "$ZALO_I386_MARKER"
    fi
}

zalo_install_deps() {
    local p missing=()
    for p in "${ZALO_CALL_PKGS[@]}"; do
        pkg_installed "$p" || missing+=("$p")
    done
    (( ${#missing[@]} )) || return 0
    info "Installing the packages Zalo calls need..."
    apt-get install -y "${missing[@]}" || return 1
    { mkdir -p "$STATE_DIR" && printf '%s\n' "${missing[@]}" >> "$ZALO_PKGS_MARKER"; } || return 1
}

# Ubuntu blocks unprivileged user namespaces, which Chromium's sandbox needs; the AppImage mounts under a random /tmp/.mount_zalo* path.
zalo_apparmor() {
    cat > "$ZALO_APPARMOR" <<'AAEOF'
abi <abi/4.0>,
include <tunables/global>

profile zalo-appimage /tmp/.mount_[Zz]alo*/zalo flags=(unconfined) {
  userns,
  include if exists <local/zalo-appimage>
}
AAEOF
    apparmor_parser -r "$ZALO_APPARMOR"
}

do_zalo() {
    local tag url arch appimage="$ZALO_DIR/zalo.AppImage"
    arch=$(uname -m)
    if [[ "$arch" != x86_64 && "$arch" != aarch64 ]]; then
        warn "Zalo for Linux ships x86_64 and aarch64 builds only — skipped on $arch"
        return
    fi

    zalo_install_deps || { fail "Could not install the libraries Zalo calls need"; return 1; }
    if command -v apparmor_parser >/dev/null; then
        zalo_apparmor || warn "Could not load the Zalo AppArmor profile — Zalo may not start"
    fi

    tag=$(github_latest_tag "$ZALO_REPO")
    if [[ -z "$tag" ]]; then
        [[ -f "$appimage" ]] || { fail "Could not find the latest Zalo for Linux release"; return 1; }
        warn "Could not check for a newer Zalo — keeping $(cat "$ZALO_DIR/VERSION" 2>/dev/null)"
        return
    fi
    if [[ -f "$appimage" && "$(cat "$ZALO_DIR/VERSION" 2>/dev/null)" == "$tag" ]]; then
        zalo_drop_wine_libs
        success "Zalo $tag already installed, skipping"
        return
    fi
    if pgrep -f '/\.mount_[Zz]alo[^/]*/zalo( |$)' >/dev/null; then
        warn "Zalo is running — quit it (tray icon too) and re-run to install Zalo $tag"
        return
    fi
    url=$(zalo_appimage_url "$tag" "$arch")
    [[ -n "$url" ]] || { fail "Could not find the Zalo $tag AppImage"; return 1; }

    info "Downloading Zalo $tag (~160 MB)..."
    step_tmpdir
    if ! wget -q --tries=3 --timeout=30 -O "$STEP_TMP/zalo.AppImage" "$url" || [[ ! -s "$STEP_TMP/zalo.AppImage" ]]; then
        fail "Could not download $url"
        return 1
    fi
    chmod +x "$STEP_TMP/zalo.AppImage"
    (cd "$STEP_TMP" && ./zalo.AppImage --appimage-extract usr/share/icons/hicolor/512x512/apps/zalo.png >/dev/null 2>&1 \
        && install -Dm 644 squashfs-root/usr/share/icons/hicolor/512x512/apps/zalo.png /usr/share/icons/hicolor/512x512/apps/zalo.png) \
        || warn "Could not extract the Zalo icon"
    gtk-update-icon-cache -q /usr/share/icons/hicolor 2>/dev/null || true

    mkdir -p "$ZALO_DIR"
    mv "$STEP_TMP/zalo.AppImage" "$appimage"
    cat > /usr/share/applications/zalo.desktop <<DEOF
[Desktop Entry]
Name=Zalo
Comment=Zalo messenger (unofficial Linux port)
Exec=$appimage %U
Terminal=false
Type=Application
Icon=zalo
StartupWMClass=zalo
Categories=Network;InstantMessaging;
DEOF
    ln -sf "$appimage" /usr/local/bin/zalo
    echo "$tag" > "$ZALO_DIR/VERSION"
    zalo_drop_wine_libs
    success "Zalo $tag installed (run 'zalo' or from app menu)"
}

undo_zalo() {
    local f
    info "Removing Zalo..."
    rm -rf "$ZALO_DIR"
    rm -f /usr/share/applications/zalo.desktop /usr/local/bin/zalo /usr/share/icons/hicolor/512x512/apps/zalo.png
    # Zalo's "start with system" setting names the entry after the AppImage file, so match on Exec.
    for f in "$REAL_HOME"/.config/autostart/*.desktop; do
        grep -qE '^Exec=\S*[Zz]alo[^/ ]*\.AppImage( |$)' "$f" 2>/dev/null && rm -f "$f"
    done
    gtk-update-icon-cache -q /usr/share/icons/hicolor 2>/dev/null || true
    if [[ -f "$ZALO_APPARMOR" ]]; then
        apparmor_parser -R "$ZALO_APPARMOR" 2>/dev/null || true
        rm -f "$ZALO_APPARMOR"
    fi

    zalo_release_packages
    zalo_remove_i386
    success "Zalo removed"
}
