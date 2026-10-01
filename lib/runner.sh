# shellcheck shell=bash

# install | uninstall: picks the do_/undo_ prefix, menu labels and default selection.
MODE="install"
ALL=0
ZSH_LOGIN_SHELL=1           # Terminal Kit makes zsh the login shell; --keep-shell sets 0
ACTION_LABEL="Install"      # footer hint label
ACTION_GERUND="Installing"  # progress box verb
ACTION_PAST="installed"     # summary stat verb
STEP_CURRENT=0
STEP_TOTAL=0
STEP_TMP=""

usage() {
    cat <<EOF
SETUP v${TOOLKIT_VERSION} — Post-install toolkit for Ubuntu 26.04

Usage:
  ./install-app.sh              Interactive install menu
  ./install-app.sh --all        Install every app
  ./install-app.sh --uninstall  Interactive uninstall menu
  ./install-app.sh --uninstall --all   Uninstall every app
  ./install-app.sh --ascii      Force ASCII-only glyphs (fonts missing symbols)
  ./install-app.sh --keep-shell Keep the current login shell (default: switch to zsh with Terminal Kit)
  ./install-app.sh -h | --help  Show this help

Tip: if the menu shows boxes/tofu instead of icons, your terminal font
lacks the glyphs. Set it to a Nerd Font (e.g. "MesloLGS NF"), or run with
--ascii (or MINT_ASCII=1) for a plain-text menu.
EOF
}

RUN_SUCCEEDED=0
RUN_START=0
RUN_FAILED=()
RUN_FAILED_WHY=()
RUN_WARNED=()
RUN_WARNED_WHY=()
STEP_WARNINGS=()
RUNTIME_KEYS=(nvm bun pnpm yarn dotnet abp azcli claude)
ELECTRON_KEYS=(chrome edge teams vscode trae postman)
STEP_RC=0
CURRENT_STEP=""

start_logging() {
    mkdir -p "$LOG_DIR"
    LOG_FILE="$LOG_DIR/$(date +%Y%m%d-%H%M%S).log"
    find "$LOG_DIR" -maxdepth 1 -name '*.log' -printf '%T@ %p\n' | sort -rn | tail -n +20 | cut -d' ' -f2- | xargs -r rm -f
    printf 'install-app %s run, %s, user %s\n' "$MODE" "$(date -Is)" "$REAL_USER" > "$LOG_FILE"
}

cleanup_run() {
    spinner_stop
    rm -f "$APT_RUN_CONF"
    (( RUN_TTY )) && { tput cnorm 2>/dev/null || true; }
    return 0
}

interrupt_run() {
    trap - INT TERM
    spinner_stop
    if [[ -n "$CURRENT_STEP" ]]; then
        RUN_FAILED+=("$CURRENT_STEP")
        RUN_FAILED_WHY+=("interrupted mid-step — re-run to finish it")
    fi
    run_emit "  ${C_YELLOW}${G_WARN}${NC} Interrupted — stopping after ${RUN_SUCCEEDED} ${ACTION_PAST} step(s)"
    print_summary interrupted
    exit 130
}

# Must be called as a plain statement: inside an if/||/&& context bash ignores set -e and the ERR trap, even in the subshell.
run_step() {
    local step_fn="$1" err_file="$RUN_DIR/step-error" _rc=0 _cmd=""
    rm -f "$err_file"
    set +e
    ( set -eE
      trap '_rc=$?; if (( BASH_SUBSHELL == 1 )) && [[ ! -s "$err_file" ]]; then _cmd=${BASH_COMMAND//$'"'"'\n'"'"'/ }; printf "%s|%s|%s|%s\n" "$_rc" "$LINENO" "${FUNCNAME[0]:-}" "$_cmd" > "$err_file"; if [[ "${FUNCNAME[0]:-}" != run_step && "$_cmd" != return* ]]; then printf "  %s \"%s\" exited %s (%s, line %s)\n" "$G_ERR" "$_cmd" "$_rc" "${FUNCNAME[0]:-?}" "$LINENO" >&2; fi; fi' ERR
      ui_plain
      STEP_ACTIVE=1
      "$step_fn" ) >> "$LOG_FILE" 2>&1 < /dev/null
    STEP_RC=$?
    set -e
}

step_failure_reason() {
    local step_fn="$1" rc="$2" err_rc err_line err_func err_cmd
    if [[ -s "$RUN_DIR/step-error" ]]; then
        IFS='|' read -r err_rc err_line err_func err_cmd < "$RUN_DIR/step-error"
        if [[ "$err_func" != run_step && "$err_cmd" == return* ]]; then
            echo "a call in $err_func returned $err_rc (line $err_line, see the step output)"
            return
        elif [[ "$err_func" != run_step ]]; then
            echo "\"$err_cmd\" exited $err_rc ($err_func, line $err_line)"
            return
        fi
    fi
    echo "$step_fn returned $rc (see the step output)"
}

run_one_step() {  # $1 name $2 function $3 detail for the result line $4 counts
    local offset started why=""
    printf '\n==> %s (%s)\n' "$1" "$2" >> "$LOG_FILE"
    offset=$(stat -c %s "$LOG_FILE")
    started=$SECONDS
    rm -f "$RUN_DIR/step-warnings"
    ui_term_size
    CURRENT_STEP="$1"
    spinner_start "$1"
    run_step "$2"
    spinner_stop
    CURRENT_STEP=""
    STEP_WARNINGS=()
    [[ -s "$RUN_DIR/step-warnings" ]] && mapfile -t STEP_WARNINGS < "$RUN_DIR/step-warnings"
    if (( STEP_RC == 0 )); then
        (( $4 )) && RUN_SUCCEEDED=$((RUN_SUCCEEDED + 1))
        if (( ${#STEP_WARNINGS[@]} )); then
            local first="${STEP_WARNINGS[0]}"
            (( ${#STEP_WARNINGS[@]} > 1 )) && first+=" (+$(( ${#STEP_WARNINGS[@]} - 1 )) more)"
            RUN_WARNED+=("$1")
            RUN_WARNED_WHY+=("$first")
        fi
    else
        why=$(step_failure_reason "$2" "$STEP_RC")
        RUN_FAILED+=("$1")
        RUN_FAILED_WHY+=("$why")
    fi
    step_report "$1" "$STEP_RC" $(( SECONDS - started )) "$offset" "$3" "$why"
}

any_selected() {
    local k
    for k in "$@"; do
        [[ "${SELECTED[$k]:-}" == "1" ]] && return 0
    done
    return 1
}

needs_finalize() {
    [[ "$MODE" == uninstall ]] || any_selected "${RUNTIME_KEYS[@]}" "${ELECTRON_KEYS[@]}"
}

finalize_run() {
    if [[ "$MODE" == "install" ]]; then
        if any_selected "${RUNTIME_KEYS[@]}"; then
            local _rc
            while read -r _rc; do
                write_tool_integrations "$_rc" || warn "Could not update the Tool-integrations block in ${_rc##*/}"
            done < <(target_shell_rcs)
        fi
        # Electron apps pick Wayland from this hint, which lets fcitx5 type into them; X11 falls back.
        if any_selected "${ELECTRON_KEYS[@]}"; then
            if ! grep -q '^ELECTRON_OZONE_PLATFORM_HINT=' /etc/environment 2>/dev/null; then
                echo 'ELECTRON_OZONE_PLATFORM_HINT=auto' >> /etc/environment
                need_reboot "/etc/environment changed (Electron Wayland hint)"
            fi
            enable_wayland_ime || warn "Could not install the Wayland IME launcher hook"
        fi
    fi

    if [[ "$MODE" == "uninstall" ]]; then
        apt-get autoremove -y >/dev/null 2>&1 || true
        remove_wayland_ime_if_unused
    fi
}

main() {
    local arg
    for arg in "$@"; do
        case "$arg" in
            --all)       ALL=1 ;;
            --uninstall) MODE="uninstall" ;;
            --ascii)     UI_ASCII=1 ;;
            --keep-shell) ZSH_LOGIN_SHELL=0 ;;
            -h|--help)   usage; exit 0 ;;
            *)           warn "Unknown option: $arg"; usage; exit 1 ;;
        esac
    done

    # Pick the glyph set (Unicode vs ASCII) before anything is drawn.
    setup_glyphs
    validate_registry

    need_root "$@"

    if [[ "$REAL_USER" == root || -z "$REAL_HOME" ]]; then
        fail "Target user resolved to '${REAL_USER}' — run this as your normal user; it re-execs itself with sudo."
        exit 1
    fi

    local os_id os_ver codename
    os_id=$(. /etc/os-release && echo "${ID:-}")
    os_ver=$(. /etc/os-release && echo "${VERSION_ID:-}")
    codename=$(get_ubuntu_codename)
    if [[ "$codename" != resolute && ( "$os_id" != "ubuntu" || "$os_ver" != "26.04" ) ]]; then
        warn "This toolkit targets Ubuntu 26.04 — detected '${os_id:-unknown} ${os_ver:-?}'. It may still work, but nothing is guaranteed."
    fi

    if [[ "$MODE" == "uninstall" ]]; then
        ACTION_LABEL="Remove"; ACTION_GERUND="Removing"; ACTION_PAST="removed"
    fi

    init_defaults

    if [[ $ALL -eq 1 ]]; then
        select_all
    else
        interactive_menu
    fi

    STEP_TOTAL=$(count_selected)

    if [[ $STEP_TOTAL -eq 0 ]]; then
        echo ""
        warn "Nothing selected — exiting."
        echo ""
        exit 0
    fi

    if [[ "$MODE" == "uninstall" ]]; then
        echo ""
        printf "  %s?%s Remove %s%s%s selected app(s)? This cannot be undone. [y/N] " "$C_YELLOW" "$NC" "$BOLD" "$STEP_TOTAL" "$NC"
        local confirm="n"
        read -r confirm </dev/tty || confirm="n"
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo ""
            warn "Aborted — nothing was removed."
            echo ""
            exit 0
        fi
    fi

    local prefix="do_"
    [[ "$MODE" == "uninstall" ]] && prefix="undo_"

    start_logging
    trap cleanup_run EXIT
    trap interrupt_run INT TERM
    rm -rf "$RUN_DIR"
    mkdir -p "$RUN_DIR"
    echo 'DPkg::Lock::Timeout "600";' > "$APT_RUN_CONF"

    RUN_TTY=0
    [[ -t 1 ]] && RUN_TTY=1
    ui_term_size
    RUN_START=$SECONDS
    run_header
    (( RUN_TTY )) && { tput civis 2>/dev/null || true; }

    local entry key label
    for entry in "${APPS[@]}"; do
        IFS='|' read -r key _ label _ <<< "$entry"
        [[ "${SELECTED[$key]}" == "1" ]] || continue
        STEP_CURRENT=$((STEP_CURRENT + 1))
        # Drop the "::tagline" — only the name belongs in result & error lines.
        item_chip "$key"
        run_one_step "${label%%::*}" "${prefix}${key}" "$REPLY" 1
    done

    if needs_finalize; then
        STEP_CURRENT=$((STEP_TOTAL + 1))
        run_one_step "Finalizing" finalize_run "" 0
    fi

    trap - INT TERM
    print_summary finished
    [[ ${#RUN_FAILED[@]} -eq 0 ]]
}
