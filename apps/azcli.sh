# shellcheck shell=bash

azcli_codename() {
    local codename
    codename=$(get_ubuntu_codename)
    # Azure CLI has no repo for other codenames (apt update 404s and aborts the run), so fall back to noble.
    case "$codename" in
        jammy | noble | resolute) echo "$codename" ;;
        *) echo noble ;;
    esac
}

write_azcli_repo() {
    ensure_microsoft_gpg || return 1
    add_apt_source /etc/apt/sources.list.d/azure-cli.list \
        "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $1 main" || return 1
    apt-get install -y azure-cli
}

do_azcli() {
    local list=/etc/apt/sources.list.d/azure-cli.list codename
    codename=$(azcli_codename)

    if command -v az &>/dev/null; then
        # Older runs pinned the jammy repo on newer Ubuntu; move to the native build.
        if [[ -f "$list" ]] && ! grep -q "/azure-cli/ $codename main" "$list"; then
            info "Switching Azure CLI repo to '$codename'..."
            write_azcli_repo "$codename" || { fail "Azure CLI repo switch failed"; return 1; }
            success "Azure CLI moved to the '$codename' repo"
            return
        fi
        success "Azure CLI already installed, skipping"
        return
    fi

    info "Installing Azure CLI..."
    apt-get install -y ca-certificates curl lsb-release gnupg
    local host_codename
    host_codename=$(get_ubuntu_codename)
    [[ "$codename" == "$host_codename" ]] \
        || warn "Azure CLI repo does not support '$host_codename', using the 'noble' repo instead"
    write_azcli_repo "$codename" || return 1

    success "Azure CLI $(az version --output tsv 2>/dev/null | head -1) installed"
}

undo_azcli() {
    info "Removing Azure CLI..."
    apt_purge azure-cli
    rm -f /etc/apt/sources.list.d/azure-cli.list
    success "Azure CLI removed"
}
