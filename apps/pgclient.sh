# shellcheck shell=bash

do_pgclient() {
    if pkg_installed postgresql-client; then
        success "PostgreSQL Client already installed, skipping"
        return
    fi
    info "Installing PostgreSQL Client..."
    apt-get install -y postgresql-client
    success "PostgreSQL Client installed (pg_dump $(pg_dump --version 2>/dev/null | grep -oP '\d+\.\d+' || echo 'ready'))"
}

undo_pgclient() {
    info "Removing PostgreSQL Client..."
    apt_purge postgresql-client
    success "PostgreSQL Client removed"
}
