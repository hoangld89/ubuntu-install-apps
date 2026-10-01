# shellcheck shell=bash

TEAMS_REPO=/etc/apt/sources.list.d/teams-for-linux-packages.sources
TEAMS_KEY=/etc/apt/keyrings/teams-for-linux.asc

ensure_teams_repo() {
    [[ -f "$TEAMS_REPO" && -s "$TEAMS_KEY" ]] && return 0
    add_apt_repo "$TEAMS_REPO" https://repo.teamsforlinux.de/teams-for-linux.asc "$TEAMS_KEY" 0 "Types: deb
URIs: https://repo.teamsforlinux.de/debian/
Suites: stable
Components: main
Signed-By: $TEAMS_KEY
Architectures: amd64"
}

do_teams() {
    ensure_teams_repo || return 1

    if pkg_up_to_date teams-for-linux; then
        success "Teams for Linux already installed (updates via apt), skipping"
        return
    fi
    if pkg_installed teams-for-linux; then
        # Older runs installed the GitHub .deb, which never updates; this moves it onto the apt repo.
        info "Moving Teams for Linux onto its apt repo..."
    else
        info "Installing Teams for Linux..."
    fi
    apt-get install -y teams-for-linux
    success "Teams for Linux installed"
}

undo_teams() {
    info "Removing Teams for Linux..."
    apt_purge teams-for-linux
    rm -f "$TEAMS_REPO" "$TEAMS_KEY"
    success "Teams for Linux removed"
}
