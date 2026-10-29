# shellcheck shell=bash

# zsh-syntax-highlighting must load last or it misses widgets defined by later plugins.
ensure_zsh_plugins() {
    local zshrc="$1" line p have=() missing=() want=()
    shift
    line=$(grep -m1 -E '^plugins=\(.*\)[[:space:]]*$' "$zshrc" 2>/dev/null || true)
    if [[ -z "$line" ]]; then
        warn "No single-line plugins=(…) in $(basename "$zshrc") — add $* manually"
        return 0
    fi
    read -ra have <<< "$(sed -E 's/^plugins=\((.*)\)[[:space:]]*$/\1/' <<< "$line")"
    for p in "$@"; do
        [[ " ${have[*]} " == *" $p "* ]] || missing+=("$p")
    done
    if [[ ${#missing[@]} -eq 0 ]]; then
        success "Oh My Zsh plugins already enabled: ${have[*]}"
        return 0
    fi
    for p in "${have[@]}" "${missing[@]}"; do
        [[ "$p" == zsh-syntax-highlighting ]] || want+=("$p")
    done
    [[ " ${have[*]} ${missing[*]} " == *" zsh-syntax-highlighting "* ]] && want+=(zsh-syntax-highlighting)
    filter_rc "$zshrc" '!done && $0 == old { print new; done = 1; next } { print }' \
        -v "old=$line" -v "new=plugins=(${want[*]})"
    success "Oh My Zsh plugins: ${want[*]}"
}

# nvm is not `set -e` safe, so su blocks source it first and switch -e on afterwards.
NVM_LOAD='export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"'

# Steps run in subshells, so the npm registry lookup is cached per run; empty when offline.
corepack_latest() {
    local cache="$RUN_DIR/corepack-latest"
    if [[ ! -s "$cache" ]]; then
        mkdir -p "$RUN_DIR"
        npm_latest corepack > "$cache"
    fi
    cat "$cache" 2>/dev/null || true
}

# Node ≥ 25 no longer bundles corepack, so pnpm/yarn come from the standalone corepack npm package (its bins provide both).
ensure_corepack() {
    local latest
    latest=$(corepack_latest)
    [[ -n "$latest" ]] || { fail "Could not query the corepack version from npm (offline, or Node.js missing?)"; return 1; }
    su - "$REAL_USER" -c "$NVM_LOAD"'
        command -v npm >/dev/null 2>&1 || { echo "npm not found — select Node.js (nvm) too" >&2; exit 1; }
        set -e
        [ "$(corepack --version 2>/dev/null)" = "'"$latest"'" ] && exit 0
        npm install -g "corepack@'"$latest"'"
    '
}

npm_latest() {  # $1 package → its latest version on npm, empty when offline
    su - "$REAL_USER" -c "$NVM_LOAD"'; npm view '"$1"' version' 2>/dev/null || true
}

redirect_target() {  # $1 URL → the URL it finally redirects to, empty when offline
    local url
    url=$(curl -fsSLI --connect-timeout 10 --max-time 30 -o /dev/null -w '%{url_effective}' "$1" 2>/dev/null) && printf '%s' "$url"
    return 0
}

github_latest_tag() {  # $1 owner/repo → tag of its latest release (vX.Y.Z or X.Y.Z), empty when offline; avoids the API rate limit
    [[ "$(redirect_target "https://github.com/$1/releases/latest")" =~ /tag/(v?[0-9.]+)$ ]] && printf '%s' "${BASH_REMATCH[1]}"
    return 0
}

corepack_pm_version() {
    local latest
    latest=$(corepack_latest)
    su - "$REAL_USER" -c "$NVM_LOAD"'
        latest="'"$latest"'"
        command -v corepack >/dev/null 2>&1 || exit 1
        [ -z "$latest" ] || [ "$(corepack --version 2>/dev/null)" = "$latest" ] || exit 1
        bin=$(command -v '"$1"') || exit 1
        case "$(readlink -f "$bin")" in */node_modules/corepack/*) ;; *) exit 1 ;; esac
        COREPACK_ENABLE_DOWNLOAD_PROMPT=0 '"$1"' --version
    ' 2>/dev/null
}

corepack_install_pm() {
    local label="$1" spec="$2"
    info "Installing $label via corepack for user '$REAL_USER'..."
    ensure_corepack || { fail "Could not install the corepack npm package (Node.js/npm required)"; return 1; }
    su - "$REAL_USER" -c "$NVM_LOAD"'
        set -e
        export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
        corepack install -g '"$spec" || { fail "corepack install -g $spec failed"; return 1; }
    success "$label installed for '$REAL_USER' via corepack (open a new shell to use it)"
}

# gsettings and the portal permission store need REAL_USER's dconf and DBus session, so the script on stdin runs as that user.
run_in_user_session() {
    {
        echo 'runtime_bus="/run/user/$(id -u)/bus"'
        echo '[ -S "$runtime_bus" ] && export DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_bus"'
        declare -f gsettings_list_add gsettings_list_remove
        cat
    } | su - "$REAL_USER" -c 'bash -s'
}

# run_in_user_session ships these to REAL_USER's shell, so they must not use toolkit globals or helpers.
gsettings_list_add() {
    local list
    list=$(gsettings get "$1" "$2") || return 1
    case "$list" in
        *"'$3'"*) return 0 ;;
        "@as []"|"[]") list="['$3']" ;;
        *) list="${list%]}, '$3']" ;;
    esac
    gsettings set "$1" "$2" "$list"
}

gsettings_list_remove() {
    local list
    list=$(gsettings get "$1" "$2") || return 1
    case "$list" in *"'$3'"*) ;; *) return 0 ;; esac
    list=$(printf '%s' "$list" | sed -e "s#, '$3'##" -e "s#'$3', ##" -e "s#'$3'##")
    gsettings set "$1" "$2" "$list"
}

download_verified() {  # $1 URL, $2 expected sha256, $3 destination file
    [[ -n "$2" ]] || { fail "Could not fetch the checksum for $1"; return 1; }
    if ! curl -fsSL --retry 3 --connect-timeout 15 --max-time 300 -o "$3" "$1"; then
        fail "Could not download $1"
        return 1
    fi
    if ! sha256sum -c --status <<< "$2  $3"; then
        fail "Could not verify the checksum of $1"
        return 1
    fi
}

install_verified_binary() {  # $1 URL, $2 expected sha256, $3 destination path
    local tmp
    step_tmpdir && [[ -n "$STEP_TMP" ]] || { fail "Could not create a temp dir"; return 1; }
    tmp="$STEP_TMP/${3##*/}"
    download_verified "$1" "$2" "$tmp" || return 1
    install -m 755 "$tmp" "$3"
}

install_release_tarball() {  # $1 .tar.gz URL, $2 checksums.txt URL listing it, $3 binary inside the tarball → /usr/local/bin/$3
    local archive=${1##*/} sha
    sha=$(curl -fsSL --retry 3 --max-time 30 "$2" 2>/dev/null | awk -v f="$archive" '$2 == f { print $1 }' || true)
    step_tmpdir && [[ -n "$STEP_TMP" ]] || { fail "Could not create a temp dir"; return 1; }
    download_verified "$1" "$sha" "$STEP_TMP/$archive" || return 1
    if ! tar -xzf "$STEP_TMP/$archive" -C "$STEP_TMP" "$3"; then
        fail "Could not extract $3 from $archive"
        return 1
    fi
    install -m 755 "$STEP_TMP/$3" "/usr/local/bin/$3"
}

ensure_multiverse() {  # $1 package that lives in multiverse
    apt-cache policy "$1" 2>/dev/null | grep -q 'Candidate: [0-9]' && return 0
    add-apt-repository -y multiverse >/dev/null 2>&1 || true
    apt-get update >/dev/null 2>&1 || true
}
