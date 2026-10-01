# shellcheck shell=bash

TRAE_URL_FILE="$STATE_DIR/trae.url"

# The version fields of the API, the URL and the package disagree, so the download URL is the update key.
trae_latest_url() {
    curl -fsSL --retry 3 --connect-timeout 15 --max-time 30 https://api.trae.ai/icube/api/v1/native/version/trae/latest \
        | jq -r '.data.manifest.linux.download | (map(select(.region == "va")) + map(select(.region != "cn")))[0]["x64.deb"] // empty'
}

do_trae() {
    command -v jq &>/dev/null || apt-get install -y jq
    local url
    url=$(trae_latest_url || true)
    if [[ -z "$url" ]]; then
        fail "Could not resolve the Trae download URL from api.trae.ai"
        return 1
    fi
    if pkg_installed trae && [[ "$(cat "$TRAE_URL_FILE" 2>/dev/null)" == "$url" ]]; then
        success "Trae IDE already at the latest release, skipping"
        return
    fi

    info "Installing Trae IDE ($url)..."
    step_tmpdir
    download_deb "$url" "$STEP_TMP/trae.deb" || return 1
    apt-get install -y --allow-downgrades "$STEP_TMP/trae.deb"
    mkdir -p "$STATE_DIR"
    echo "$url" > "$TRAE_URL_FILE"
    success "Trae IDE installed"
}

undo_trae() {
    info "Removing Trae IDE..."
    apt_purge trae
    rm -f "$TRAE_URL_FILE"
    success "Trae IDE removed"
}
