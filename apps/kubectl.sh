# shellcheck shell=bash

do_kubectl() {
    local latest version base sha
    latest=$(curl -fsSL --retry 3 --connect-timeout 10 --max-time 30 https://dl.k8s.io/release/stable.txt 2>/dev/null || true)
    version=$(/usr/local/bin/kubectl version --client 2>/dev/null || true)
    if [[ -x /usr/local/bin/kubectl ]] && [[ -z "$latest" || "${version%%$'\n'*}" == "Client Version: $latest" ]]; then
        success "kubectl already installed, skipping"
        return
    fi
    [[ -n "$latest" ]] || { fail "Could not query the stable kubectl version from dl.k8s.io"; return 1; }

    info "Installing kubectl ${latest#v}..."
    base="https://dl.k8s.io/release/$latest/bin/linux/$(dpkg --print-architecture)/kubectl"
    sha=$(curl -fsSL --retry 3 --max-time 30 "$base.sha256" 2>/dev/null || true)
    install_verified_binary "$base" "$sha" /usr/local/bin/kubectl || return 1
    success "kubectl ${latest#v} installed"
}

undo_kubectl() {
    info "Removing kubectl..."
    rm -f /usr/local/bin/kubectl
    success "kubectl removed (~/.kube left intact)"
}
