# shellcheck shell=bash

DOTNET_PPA=ppa:dotnet/backports
DOTNET_PPA_MARKER="$STATE_DIR/dotnet-backports.added"

do_dotnet() {
    local ver missing=() installed=() failed=() need_ppa=0
    for ver in "${DOTNET_VERSIONS[@]}"; do
        if pkg_installed "dotnet-sdk-${ver}.0"; then installed+=("$ver"); else missing+=("$ver"); fi
    done
    if [[ ${#missing[@]} -eq 0 ]]; then
        success ".NET SDK ${installed[*]} already installed, skipping"
        return
    fi

    info "Installing .NET SDK (versions: ${missing[*]})..."
    # .NET 10 ships in the 26.04 archive; 8 and 9 only in the backports PPA. The old Microsoft repo list is dropped.
    rm -f /etc/apt/sources.list.d/dotnet.list
    for ver in "${missing[@]}"; do
        [[ "$ver" == 10 ]] || need_ppa=1
    done
    if [[ $need_ppa -eq 1 ]] && ! grep -rqs 'dotnet/backports' /etc/apt/sources.list.d/; then
        add_ppa "$DOTNET_PPA" || return 1
        mkdir -p "$STATE_DIR"
        touch "$DOTNET_PPA_MARKER"
    else
        apt-get update
    fi

    for ver in "${missing[@]}"; do
        if apt-get install -y "dotnet-sdk-${ver}.0"; then installed+=("$ver"); else failed+=("$ver"); fi
    done

    if [[ -d /usr/share/dotnet ]]; then
        warn "/usr/share/dotnet is left over from an older dotnet-install.sh run — .NET now lives in /usr/lib/dotnet"
    fi
    if [[ ${#installed[@]} -gt 0 ]]; then
        success ".NET SDK installed: ${installed[*]}"
    fi
    if [[ ${#failed[@]} -gt 0 ]]; then
        fail ".NET SDK failed: ${failed[*]}"
        return 1
    fi
}

undo_dotnet() {
    info "Removing .NET SDK..."
    local pkgs
    pkgs=$(dpkg-query -W -f='${Package}\n' 'dotnet-sdk-*' 'dotnet-runtime-*' 'dotnet-host*' 'dotnet-apphost-pack-*' \
        'dotnet-targeting-pack-*' 'dotnet-templates-*' 'aspnetcore-runtime-*' 'aspnetcore-targeting-pack-*' \
        'netstandard-targeting-pack-*' 2>/dev/null || true)
    if [[ -n "$pkgs" ]]; then
        # shellcheck disable=SC2086
        apt_purge $pkgs
    fi
    rm -f /etc/apt/sources.list.d/dotnet.list
    if [[ -f "$DOTNET_PPA_MARKER" ]]; then
        add-apt-repository -y --remove "$DOTNET_PPA" >/dev/null 2>&1 || true
        rm -f "$DOTNET_PPA_MARKER"
        success "Removed $DOTNET_PPA"
    fi
    rm -rf /usr/share/dotnet
    if [[ -L /usr/bin/dotnet && ! -e /usr/bin/dotnet ]]; then
        rm -f /usr/bin/dotnet
    fi
    success ".NET SDK removed (packages, PPA & leftovers)"
}
