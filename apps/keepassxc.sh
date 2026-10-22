# shellcheck shell=bash

KEEPASSXC_PPA=ppa:phoerious/keepassxc

keepassxc_ppa_added() { compgen -G '/etc/apt/sources.list.d/phoerious-ubuntu-keepassxc-*' >/dev/null; }

do_keepassxc() {
    if keepassxc_ppa_added && pkg_up_to_date keepassxc; then
        success "KeePassXC already installed (updates via its PPA), skipping"
        return
    fi
    # The upstream PPA ships releases months before Ubuntu's archive; add-apt-repository -y already refreshes apt.
    keepassxc_ppa_added || add_ppa "$KEEPASSXC_PPA" || return 1
    if pkg_installed keepassxc; then
        info "Moving KeePassXC onto its PPA..."
    else
        info "Installing KeePassXC..."
    fi
    # Ubuntu's keepassxc is a transitional package; keepassxc-full owns the binary, and the PPA build does not Replace it.
    apt-get install -y keepassxc keepassxc-full- keepassxc-minimal-
    success "KeePassXC installed (updates via its PPA)"
}

undo_keepassxc() {
    info "Removing KeePassXC..."
    apt_purge keepassxc keepassxc-full keepassxc-minimal
    add-apt-repository -y --remove "$KEEPASSXC_PPA" 2>/dev/null || true
    rm -f /etc/apt/sources.list.d/phoerious-ubuntu-keepassxc-*.list \
          /etc/apt/sources.list.d/phoerious-ubuntu-keepassxc-*.sources
    success "KeePassXC removed (package & PPA; your .kdbx databases left intact)"
}
