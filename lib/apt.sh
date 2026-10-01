# shellcheck shell=bash

# Download a repo signing key to $2 (dearmored when $3 is 1) through a temp file, so a failed fetch never leaves a broken key.
fetch_key() {
    local url="$1" dest="$2" dearmor="$3" tmp
    tmp=$(mktemp)
    if ! curl -fsSL --retry 3 --connect-timeout 15 --max-time 60 -o "$tmp" "$url" || [[ ! -s "$tmp" ]]; then
        rm -f "$tmp"
        fail "Could not download the repo key from $url"
        return 1
    fi
    if [[ "$dearmor" == 1 ]]; then
        if ! gpg --batch --yes --dearmor -o "$tmp.gpg" "$tmp"; then
            rm -f "$tmp" "$tmp.gpg"
            fail "Could not dearmor the repo key from $url"
            return 1
        fi
        mv -f "$tmp.gpg" "$tmp"
    fi
    mkdir -p "$(dirname "$dest")"
    chmod 644 "$tmp"
    mv -f "$tmp" "$dest"
}

ensure_microsoft_gpg() {
    [[ -s /usr/share/keyrings/microsoft.gpg ]] && return 0
    fetch_key https://packages.microsoft.com/keys/microsoft.asc /usr/share/keyrings/microsoft.gpg 1
}

# Refreshes only the new source, so a broken unrelated repo can't get this one rolled back.
add_apt_source() {
    local list="$1" content="$2"
    printf '%s\n' "$content" > "$list" || return 1
    chmod 644 "$list"
    if ! apt-get update -o Dir::Etc::sourcelist="$list" -o Dir::Etc::sourceparts=- -o APT::Get::List-Cleanup=0; then
        rm -f "$list"
        fail "apt-get update failed for $(basename "$list") — source removed"
        return 1
    fi
}

# add-apt-repository can leave a half-written source behind when it fails.
add_ppa() {
    command -v add-apt-repository &>/dev/null || apt-get install -y software-properties-common || return 1
    if ! add-apt-repository -y "$1"; then
        add-apt-repository -y --remove "$1" >/dev/null 2>&1 || true
        fail "Could not add $1"
        return 1
    fi
}

# A failed key fetch or apt-get update removes both the key and the list, so a bad repo never breaks later steps.
add_apt_repo() {
    local list="$1" key_url="$2" key="$3" dearmor="$4" content="$5"
    fetch_key "$key_url" "$key" "$dearmor" || { rm -f "$list" "$key"; return 1; }
    add_apt_source "$list" "$content" || { rm -f "$key"; return 1; }
}

# Download a remote installer to a temp file (never piped) so a failed fetch runs nothing, then run it as $1 with command $2 (may be `env VAR=… sh`); extra args go to the script.
run_remote_script() {
    local run_user="$1" url="$3" script rc=0 cmd
    read -ra cmd <<< "$2"
    shift 3
    script=$(mktemp /tmp/remote-install-XXXXXX.sh)
    if ! curl -fsSL --retry 3 --connect-timeout 15 --max-time 300 -o "$script" "$url"; then
        rm -f "$script"
        fail "Could not download $url"
        return 1
    fi
    chmod 644 "$script"
    if [[ "$run_user" == root ]]; then
        "${cmd[@]}" "$script" "$@" || rc=$?
    else
        su - "$run_user" -c "$(printf '%q ' "${cmd[@]}" "$script" "$@")" || rc=$?
    fi
    rm -f "$script"
    return $rc
}

# Purge only the installed packages among $@ (one unknown name fails the whole purge) and never abort the run.
apt_purge() {
    local p installed=()
    for p in "$@"; do
        pkg_installed "$p" && installed+=("$p")
    done
    (( ${#installed[@]} )) || return 0
    apt-get purge -y "${installed[@]}" >/dev/null 2>&1 || true
}

# wget can exit 0 on a truncated download; `dpkg-deb --contents` reads the last archive member (--info stops at control), so truncation fails here, not in apt.
download_deb() {
    local url="$1" dest="$2" attempt
    for attempt in 1 2 3; do
        if wget --tries=3 --timeout=30 --continue -q -O "$dest" "$url" \
            && dpkg-deb --contents "$dest" >/dev/null 2>&1; then
            return 0
        fi
        warn "Download attempt $attempt failed or produced a corrupt package, retrying..."
        rm -f "$dest"
    done
    fail "Could not download a valid .deb from $url"
    return 1
}
