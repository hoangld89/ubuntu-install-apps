# shellcheck shell=bash

remove_keepassxc_ppa() {
    add-apt-repository -y --remove ppa:phoerious/keepassxc 2>/dev/null || true
    rm -f /etc/apt/sources.list.d/phoerious-ubuntu-keepassxc-*.list \
          /etc/apt/sources.list.d/phoerious-ubuntu-keepassxc-*.sources
}

do_keepassxc() {
    local ppa_source installed pkg=keepassxc
    ppa_source=$(compgen -G '/etc/apt/sources.list.d/phoerious-ubuntu-keepassxc-*' || true)
    installed=$(dpkg-query -W -f='${Version}' keepassxc 2>/dev/null || true)
    if [[ -n "$ppa_source" || "$installed" == *ppa* ]]; then
        info "Moving KeePassXC from its PPA to the Ubuntu archive..."
        remove_keepassxc_ppa
        apt-get update
        # The PPA build does not Replace keepassxc-full's files, so it must go before the install.
        apt_purge keepassxc
    fi
    # 24.04 ships only the full build as `keepassxc`; from 25.04 that name is a metapackage that may pull keepassxc-minimal.
    apt_has_candidate keepassxc-full && pkg=keepassxc-full
    if pkg_up_to_date "$pkg"; then
        success "KeePassXC already installed, skipping"
        return
    fi
    info "Installing KeePassXC..."
    apt-get install -y "$pkg"
    success "KeePassXC installed"
}

undo_keepassxc() {
    info "Removing KeePassXC..."
    apt_purge keepassxc keepassxc-full keepassxc-minimal
    remove_keepassxc_ppa
    success "KeePassXC removed (your .kdbx databases left intact)"
}
