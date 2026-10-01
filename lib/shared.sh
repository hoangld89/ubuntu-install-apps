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
        su - "$REAL_USER" -c "$NVM_LOAD"'; npm view corepack version' 2>/dev/null > "$cache" || rm -f "$cache"
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
