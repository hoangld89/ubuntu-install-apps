# shellcheck shell=bash

do_mysqlclient() {
    if pkg_installed mysql-client; then
        success "MySQL Client already installed, skipping"
        return
    fi
    info "Installing MySQL Client..."
    apt-get install -y mysql-client
    success "MySQL Client installed (mysqldump $(mysqldump --version 2>/dev/null | grep -oP 'Distrib \K[^,]+' || echo 'ready'))"
}

undo_mysqlclient() {
    info "Removing MySQL Client..."
    apt_purge mysql-client
    success "MySQL Client removed"
}
