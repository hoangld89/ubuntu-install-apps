# shellcheck shell=bash

do_terraform() {
    if command -v terraform &>/dev/null; then
        success "Terraform already installed, skipping"
        return
    fi

    info "Installing Terraform..."
    apt-get install -y gnupg curl

    local codename
    codename=$(get_ubuntu_codename)
    add_apt_repo /etc/apt/sources.list.d/hashicorp.list https://apt.releases.hashicorp.com/gpg /usr/share/keyrings/hashicorp.gpg 1 \
        "deb [arch=amd64 signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $codename main" || return 1
    apt-get install -y terraform

    success "Terraform $(terraform --version | head -1) installed"
}

undo_terraform() {
    info "Removing Terraform..."
    apt_purge terraform
    rm -f /etc/apt/sources.list.d/hashicorp.list /usr/share/keyrings/hashicorp.gpg
    success "Terraform removed (package, repo & key)"
}
