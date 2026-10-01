# shellcheck shell=bash

do_edge() {
    if command -v microsoft-edge-stable &>/dev/null; then
        success "Microsoft Edge already installed, skipping"
        return
    fi

    info "Installing Microsoft Edge..."
    ensure_microsoft_gpg || return 1
    add_apt_source /etc/apt/sources.list.d/microsoft-edge.list \
        "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/edge stable main" || return 1
    apt-get install -y microsoft-edge-stable
    success "Microsoft Edge installed"
}

undo_edge() {
    info "Removing Microsoft Edge..."
    apt_purge microsoft-edge-stable
    rm -f /etc/apt/sources.list.d/microsoft-edge.{list,sources} /usr/share/keyrings/microsoft-edge.gpg
    success "Microsoft Edge removed"
}
