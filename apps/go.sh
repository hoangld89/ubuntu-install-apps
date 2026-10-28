# shellcheck shell=bash

GO_ROOT=/usr/local/go

do_go() {
    local latest current arch archive sha stage
    latest=$(curl -fsSL --retry 3 --max-time 30 'https://go.dev/VERSION?m=text' 2>/dev/null | head -1 || true)
    [[ "$latest" =~ ^go[0-9.]+$ ]] || latest=""
    current=$(head -1 "$GO_ROOT/VERSION" 2>/dev/null || true)
    if [[ -x "$GO_ROOT/bin/go" ]] && [[ -z "$latest" || "$current" == "$latest" ]]; then
        success "Go ${current#go} already installed, skipping"
    else
        [[ -n "$latest" ]] || { fail "Could not query the latest Go release"; return 1; }
        info "Installing Go ${latest#go}..."
        arch=$(dpkg --print-architecture)
        case "$arch" in armhf) arch=armv6l ;; ppc64el) arch=ppc64le ;; esac
        archive="$latest.linux-$arch.tar.gz"
        sha=$(curl -fsSL --retry 3 --max-time 30 "https://dl.google.com/go/$archive.sha256" 2>/dev/null || true)
        step_tmpdir
        download_verified "https://dl.google.com/go/$archive" "$sha" "$STEP_TMP/$archive" || return 1
        # Unpack beside GO_ROOT so the swap is a rename: untarring over an old tree leaves stale files that break builds.
        stage=$(mktemp -d "${GO_ROOT%/*}/.go-new-XXXXXX")
        trap "rm -rf -- '$STEP_TMP' '$stage'" EXIT
        tar -xzf "$STEP_TMP/$archive" -C "$stage"
        rm -rf "$GO_ROOT"
        mv "$stage/go" "$GO_ROOT"
        success "Go ${latest#go} installed in $GO_ROOT (open a new shell to use it)"
    fi
    if pkg_installed golang-go; then
        warn "Ubuntu's golang-go package is also installed — $GO_ROOT/bin comes first on PATH"
    fi
}

undo_go() {
    info "Removing Go..."
    if [[ -x "$GO_ROOT/bin/go" ]]; then
        su - "$REAL_USER" -c "$GO_ROOT/bin/go clean -cache -modcache" &>/dev/null || true
    fi
    rm -rf "$GO_ROOT"
    # Module cache files are read-only; these are the default paths, for when go clean could not run.
    chmod -R u+w "$REAL_HOME/go/pkg/mod" 2>/dev/null || true
    rm -rf "$REAL_HOME/go/pkg/mod" "$REAL_HOME/go/pkg/sumdb" "$REAL_HOME/.cache/go-build"
    rmdir "$REAL_HOME/go/pkg" "$REAL_HOME/go" 2>/dev/null || true
    if [[ -d "$REAL_HOME/go" ]]; then
        warn "Kept ~/go — it holds your 'go install' binaries or sources"
    fi
    success "Go removed (toolchain, build & module caches)"
}
