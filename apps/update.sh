# shellcheck shell=bash

do_update() {
    info "Updating system packages..."
    apt-get update \
        && apt-get -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold upgrade -y --with-new-pkgs \
        && apt-get autoremove -y \
        || return 1
    success "System updated"
}

undo_update() {
    warn "A system update/upgrade cannot be rolled back — skipping"
}
