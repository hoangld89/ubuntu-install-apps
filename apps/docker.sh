# shellcheck shell=bash

do_docker() {
    if pkg_installed docker-ce; then
        success "Docker already installed, skipping"
        return
    fi

    info "Installing Docker + Docker Compose..."
    # Docker's install docs: distro packages with these names conflict with docker-ce.
    apt_purge docker.io docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc

    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings

    local codename
    codename=$(get_ubuntu_codename)

    # Remove any conflicting deb822-style source / armored key left by a prior
    # install. apt refuses to read sources when the same repo is declared twice
    # with different Signed-By values (docker.gpg vs docker.asc).
    rm -f /etc/apt/sources.list.d/docker.sources /etc/apt/keyrings/docker.asc

    add_apt_repo /etc/apt/sources.list.d/docker.list https://download.docker.com/linux/ubuntu/gpg /etc/apt/keyrings/docker.gpg 1 \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $codename stable" \
        || return 1
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    if ! id -nG "$REAL_USER" | grep -qw docker; then
        usermod -aG docker "$REAL_USER"
        need_reboot "'$REAL_USER' added to the docker group"
    fi
    systemctl enable --now docker

    success "Docker + Compose installed (user '$REAL_USER' is in the docker group)"
}

undo_docker() {
    info "Removing Docker + Docker Compose..."
    apt_purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
    rm -f /etc/apt/sources.list.d/docker.list /etc/apt/sources.list.d/docker.sources \
          /etc/apt/keyrings/docker.gpg /etc/apt/keyrings/docker.asc
    gpasswd -d "$REAL_USER" docker 2>/dev/null || true
    warn "/var/lib/docker, /var/lib/containerd and /etc/docker (images, volumes, config) left intact — remove manually if desired"
    success "Docker removed (packages, repo, key & group membership)"
}
