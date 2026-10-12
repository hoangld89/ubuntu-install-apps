# shellcheck shell=bash

ANDROID_AVD=medium_phone
ANDROID_JDK=openjdk-21-jre-headless
ANDROID_JDK_MARKER="$STATE_DIR/android-jdk"
ANDROID_SDK_MARKER="$STATE_DIR/android-sdk"

android_clt_latest_url() {
    local zip
    zip=$(curl -fsSL --connect-timeout 10 --max-time 60 https://dl.google.com/android/repository/repository2-3.xml 2>/dev/null \
        | awk '/<remotePackage path="cmdline-tools;latest">/ { p = 1 }
               p && match($0, /commandlinetools-linux-[0-9]+_latest\.zip/) { print substr($0, RSTART, RLENGTH); exit }' || true)
    [[ -n "$zip" ]] && printf '%s' "https://dl.google.com/android/repository/$zip"
    return 0
}

android_cli() {
    su - "$REAL_USER" -c 'export ANDROID_HOME="$HOME/Android/Sdk"; "$ANDROID_HOME/cmdline-tools/latest/bin/android" --sdk="$ANDROID_HOME" '"$(printf '%q ' "$@")"
}

do_android() {
    local sdk="$REAL_HOME/Android/Sdk" url cfg java_major
    java_major=$(java -version 2>&1 | grep -oP 'version "\K[0-9]+' || true)
    if (( ${java_major:-0} < 17 )) && ! pkg_installed "$ANDROID_JDK"; then
        apt-get install -y "$ANDROID_JDK"
        mkdir -p "$STATE_DIR"
        touch "$ANDROID_JDK_MARKER"
    fi
    pkg_installed unzip || apt-get install -y unzip
    [[ -e /dev/kvm ]] || warn "/dev/kvm is missing — enable virtualization (VT-x/AMD-V) in the BIOS or the emulator won't start"

    # `android sdk update` keeps cmdline-tools current after this first install.
    if [[ ! -x "$sdk/cmdline-tools/latest/bin/android" ]]; then
        info "Installing Android command-line tools..."
        url=$(android_clt_latest_url)
        [[ -n "$url" ]] || { fail "Could not resolve the Android command-line tools download"; return 1; }
        if [[ ! -d "$sdk" ]]; then
            mkdir -p "$STATE_DIR"
            touch "$ANDROID_SDK_MARKER"
        fi
        step_tmpdir
        if ! wget -q --tries=3 --timeout=30 -O "$STEP_TMP/clt.zip" "$url" || ! unzip -tq "$STEP_TMP/clt.zip" &>/dev/null; then
            fail "Could not download $url"
            return 1
        fi
        unzip -q "$STEP_TMP/clt.zip" -d "$STEP_TMP/clt"
        mkdir -p "$sdk/cmdline-tools"
        rm -rf "$sdk/cmdline-tools/latest"
        mv "$STEP_TMP/clt/cmdline-tools" "$sdk/cmdline-tools/latest"
        chown -R "$REAL_USER:$REAL_USER" "$REAL_HOME/Android"
    fi

    if [[ -f "$REAL_HOME/.android/avd/$ANDROID_AVD.ini" ]]; then
        info "Updating Android SDK packages..."
        android_cli sdk update || warn "Android SDK update failed — run 'android sdk update' later"
    else
        info "Creating the '$ANDROID_AVD' virtual device (emulator + Play Store system image, ~8 GB)..."
        android_cli emulator create "$ANDROID_AVD" || { fail "Could not create the '$ANDROID_AVD' virtual device"; return 1; }
        # GPU blocklist puts Mesa iGPUs on software rendering; host mode works: https://developer.android.com/studio/run/emulator-acceleration#accel-graphics
        cfg="$REAL_HOME/.android/avd/$ANDROID_AVD.avd/config.ini"
        if grep -q '^hw\.gpu\.mode=' "$cfg"; then
            sed -i 's/^hw\.gpu\.mode=.*/hw.gpu.mode=host/' "$cfg"
        else
            echo 'hw.gpu.mode=host' >> "$cfg"
        fi
    fi

    su - "$REAL_USER" -c 'mkdir -p "$HOME/.local/share/applications"'
    cat > "$REAL_HOME/.local/share/applications/android-emulator.desktop" <<DEOF
[Desktop Entry]
Type=Application
Name=Android Emulator
Comment=Android phone with Google Play ($ANDROID_AVD)
Exec=$sdk/emulator/emulator -avd $ANDROID_AVD
Icon=phone
Terminal=false
Categories=Development;Emulator;
DEOF
    chown "$REAL_USER:$REAL_USER" "$REAL_HOME/.local/share/applications/android-emulator.desktop"

    success "Android Emulator ready — open 'Android Emulator' from the app menu (SDK: ~/Android/Sdk)"
}

undo_android() {
    info "Removing Android Emulator..."
    su - "$REAL_USER" -c '"$HOME/Android/Sdk/platform-tools/adb" emu kill' &>/dev/null || true
    rm -rf "$REAL_HOME/.android/avd/$ANDROID_AVD.avd" "$REAL_HOME/.android/avd/$ANDROID_AVD.ini" "$REAL_HOME/.android/$ANDROID_AVD"
    rmdir "$REAL_HOME/.android/avd" 2>/dev/null || true
    rm -f "$REAL_HOME/.local/share/applications/android-emulator.desktop"
    if [[ -f "$ANDROID_SDK_MARKER" ]]; then
        rm -rf "$REAL_HOME/Android/Sdk" "$REAL_HOME/.android/cli"
        rmdir "$REAL_HOME/Android" 2>/dev/null || true
        rm -f "$ANDROID_SDK_MARKER"
    elif [[ -d "$REAL_HOME/Android/Sdk" ]]; then
        warn "~/Android/Sdk existed before this toolkit (Android Studio?) — kept; only the '$ANDROID_AVD' AVD was removed"
    fi
    if [[ -f "$ANDROID_JDK_MARKER" ]]; then
        apt_purge "$ANDROID_JDK"
        rm -f "$ANDROID_JDK_MARKER"
    fi
    success "Android Emulator removed"
}
