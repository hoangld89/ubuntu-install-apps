# shellcheck shell=bash

do_localsend() {
    local latest installed arch
    latest=$(github_latest_tag localsend/localsend)
    installed=$(dpkg-query -W -f='${Version}' localsend 2>/dev/null || true)
    if pkg_installed localsend && [[ -z "$latest" || "${installed%%+*}" == "${latest#v}" ]]; then
        success "LocalSend already installed, skipping"
        return
    fi
    [[ -n "$latest" ]] || { fail "Could not query the latest LocalSend release"; return 1; }

    info "Installing LocalSend ${latest#v}..."
    arch=x86-64
    [[ "$(dpkg --print-architecture)" == arm64 ]] && arch=arm-64
    step_tmpdir
    download_deb "https://github.com/localsend/localsend/releases/download/$latest/LocalSend-${latest#v}-linux-$arch.deb" \
        "$STEP_TMP/localsend.deb" || return 1
    apt-get install -y "$STEP_TMP/localsend.deb"
    success "LocalSend ${latest#v} installed (updates when you re-run the toolkit)"
}

undo_localsend() {
    info "Removing LocalSend..."
    apt_purge localsend
    success "LocalSend removed"
}
