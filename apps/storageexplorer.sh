# shellcheck shell=bash

STORAGE_EXPLORER_DIR=/opt/StorageExplorer
STORAGE_EXPLORER_ASSET=StorageExplorer-linux-x64.tar.gz
STORAGE_EXPLORER_ICON=$STORAGE_EXPLORER_DIR/resources/app/out/app/media/StorageExplorerColor.svg

# Releases ship no checksum file, so the sha256 comes from the asset digest in GitHub's API.
storage_explorer_sha() {
    curl -fsSL --retry 3 --max-time 30 "https://api.github.com/repos/microsoft/AzureStorageExplorer/releases/tags/$1" 2>/dev/null \
        | awk -v f="\"$STORAGE_EXPLORER_ASSET\"" '$0 ~ "\"name\": " f { hit = 1 } hit && /"digest":/ { if (match($0, /sha256:[0-9a-f]+/)) print substr($0, RSTART + 7, RLENGTH - 7); exit }' \
        || true
}

do_storageexplorer() {
    local latest installed sha archive
    latest=$(github_latest_tag microsoft/AzureStorageExplorer)
    installed=$(grep -m1 -oP '"version":\s*"\K[^"]+' "$STORAGE_EXPLORER_DIR/resources/app/package.json" 2>/dev/null || true)
    if [[ -n "$installed" && -f /usr/share/applications/storage-explorer.desktop ]] && pkg_installed dotnet-runtime-10.0 && [[ -z "$latest" || "$installed" == "${latest#v}" ]]; then
        sed -i "s#^Icon=.*#Icon=$STORAGE_EXPLORER_ICON#" /usr/share/applications/storage-explorer.desktop
        success "Azure Storage Explorer already installed, skipping"
        return
    fi
    [[ -n "$latest" ]] || { fail "Could not query the latest Azure Storage Explorer release"; return 1; }

    info "Installing Azure Storage Explorer ${latest#v}..."
    apt-get install -y dotnet-runtime-10.0 libsecret-1-0 libnss3 libxss1 libxtst6 libasound2t64 iproute2 xdg-utils

    sha=$(storage_explorer_sha "$latest")
    step_tmpdir
    archive="$STEP_TMP/$STORAGE_EXPLORER_ASSET"
    download_verified "https://github.com/microsoft/AzureStorageExplorer/releases/download/$latest/$STORAGE_EXPLORER_ASSET" \
        "$sha" "$archive" 1800 || return 1
    mkdir "$STEP_TMP/app"
    tar --no-same-owner -xzf "$archive" -C "$STEP_TMP/app"
    rm "$archive"
    chown -R root:root "$STEP_TMP/app"
    rm -rf "$STORAGE_EXPLORER_DIR"
    mv "$STEP_TMP/app" "$STORAGE_EXPLORER_DIR"
    # The bundled launcher finds StorageExplorerExe next to itself, so a symlink breaks it.
    rm -f /usr/local/bin/storage-explorer
    printf '#!/bin/sh\nexec %s/StorageExplorer "$@"\n' "$STORAGE_EXPLORER_DIR" > /usr/local/bin/storage-explorer
    chmod 755 /usr/local/bin/storage-explorer

    cat > /usr/share/applications/storage-explorer.desktop <<DEOF
[Desktop Entry]
Type=Application
Name=Azure Storage Explorer
Comment=Manage Azure blobs, files, queues and tables
Exec=$STORAGE_EXPLORER_DIR/StorageExplorer %U
Icon=$STORAGE_EXPLORER_ICON
Terminal=false
Categories=Development;
StartupWMClass=StorageExplorer
DEOF

    success "Azure Storage Explorer ${latest#v} installed (updates when you re-run the toolkit)"
}

undo_storageexplorer() {
    info "Removing Azure Storage Explorer..."
    rm -rf "$STORAGE_EXPLORER_DIR"
    rm -f /usr/local/bin/storage-explorer /usr/share/applications/storage-explorer.desktop
    success "Azure Storage Explorer removed (the .NET 10 runtime stays)"
}
