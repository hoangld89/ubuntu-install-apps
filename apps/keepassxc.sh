# shellcheck shell=bash

remove_keepassxc_ppa() {
    add-apt-repository -y --remove ppa:phoerious/keepassxc 2>/dev/null || true
    rm -f /etc/apt/sources.list.d/phoerious-ubuntu-keepassxc-*.list \
          /etc/apt/sources.list.d/phoerious-ubuntu-keepassxc-*.sources
}

do_keepassxc() {
    local ppa_source installed
    ppa_source=$(compgen -G '/etc/apt/sources.list.d/phoerious-ubuntu-keepassxc-*' || true)
    installed=$(dpkg-query -W -f='${Version}' keepassxc 2>/dev/null || true)
    if [[ -n "$ppa_source" || "$installed" == *ppa* ]]; then
        info "Moving KeePassXC from its PPA to the Ubuntu archive..."
        remove_keepassxc_ppa
        apt-get update
        # The PPA build does not Replace keepassxc-full's files, so it must go before the install.
        apt_purge keepassxc
    fi
    if pkg_up_to_date keepassxc-full; then
        success "KeePassXC already installed, skipping"
        return
    fi
    info "Installing KeePassXC..."
    apt-get install -y keepassxc-full
    success "KeePassXC installed"
}

undo_keepassxc() {
    info "Removing KeePassXC..."
    apt_purge keepassxc keepassxc-full keepassxc-minimal
    remove_keepassxc_ppa
    success "KeePassXC removed (your .kdbx databases left intact)"
}
