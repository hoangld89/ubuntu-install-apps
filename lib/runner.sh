# shellcheck shell=bash

# install | uninstall — set in main() from CLI flags. Drives menu labels,
# default selection, and which dispatch prefix (do_ / undo_) main() calls.
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
SETUP — Post-install toolkit for Ubuntu 26.04

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
TEE_PID=""
STEP_RC=0
CURRENT_STEP=""

start_logging() {
    mkdir -p "$LOG_DIR"
    LOG_FILE="$LOG_DIR/$(date +%Y%m%d-%H%M%S).log"
    find "$LOG_DIR" -maxdepth 1 -name '*.log' -printf '%T@ %p\n' | sort -rn | tail -n +20 | cut -d' ' -f2- | xargs -r rm -f
    exec 3>&1 4>&2
    # tee ignores INT/TERM so a Ctrl-C summary still reaches the terminal and the log.
    exec > >(trap '' INT TERM; exec tee -a "$LOG_FILE") 2>&1
    TEE_PID=$!
}

cleanup_run() {
    rm -f "$APT_RUN_CONF"
    [[ -n "$TEE_PID" ]] || return 0
    exec 1>&3 2>&4 3>&- 4>&-
    # A daemon started by a postinst can inherit stdout and keep tee alive forever.
    local i
    for i in {1..50}; do
        kill -0 "$TEE_PID" 2>/dev/null || break
        sleep 0.1
    done
    kill "$TEE_PID" 2>/dev/null || true
    TEE_PID=""
}

print_summary() {
    local headline="$1" elapsed=$(( SECONDS - RUN_START ))
    local border; border=$(ui_rep 53 "$RB_H")
    echo ""
    echo ""
    echo -e "  ${DIM}${RB_TL}${border}${RB_TR}${NC}"
    echo -e "  ${DIM}${RB_V}${NC}                                                     ${DIM}${RB_V}${NC}"
    if [[ "$headline" == interrupted ]]; then
        printf "  ${DIM}${RB_V}${NC}   ${YELLOW}${G_WARN}${NC}  ${BOLD}%-46s${NC}${DIM}${RB_V}${NC}\n" "Interrupted"
    elif [[ ${#RUN_FAILED[@]} -eq 0 ]]; then
        echo -e "  ${DIM}${RB_V}${NC}   ${MINT}${G_OK}${NC}  ${BOLD}${WHITE}All done!${NC}                                      ${DIM}${RB_V}${NC}"
    else
        echo -e "  ${DIM}${RB_V}${NC}   ${YELLOW}${G_WARN}${NC}  ${BOLD}Completed with errors${NC}                           ${DIM}${RB_V}${NC}"
    fi
    echo -e "  ${DIM}${RB_V}${NC}                                                     ${DIM}${RB_V}${NC}"
    local stats="${RUN_SUCCEEDED} ${ACTION_PAST}"
    [[ ${#RUN_FAILED[@]} -gt 0 ]] && stats="${stats}  ${#RUN_FAILED[@]} failed"
    printf "  ${DIM}${RB_V}${NC}   ${MINT}${G_ON}${NC} %-44s${DIM}${RB_V}${NC}\n" "$stats"
    printf "  ${DIM}${RB_V}${NC}   ${DIM}${G_CLOCK}  %-44s${NC}${DIM}${RB_V}${NC}\n" "$(( elapsed / 60 ))m $(( elapsed % 60 ))s"
    echo -e "  ${DIM}${RB_V}${NC}                                                     ${DIM}${RB_V}${NC}"
    echo -e "  ${DIM}${RB_BL}${border}${RB_BR}${NC}"

    local i
    if [[ ${#RUN_FAILED[@]} -gt 0 ]]; then
        echo ""
        echo -e "  ${RED}Failed:${NC}"
        for i in "${!RUN_FAILED[@]}"; do
            echo -e "    ${RED}${G_ERR}${NC} ${BOLD}${RUN_FAILED[$i]}${NC} ${DIM}— ${RUN_FAILED_WHY[$i]}${NC}"
        done
    fi

    local reasons=() r
    [[ -s "$RUN_DIR/reboot-reasons" ]] && mapfile -t reasons < <(sort -u "$RUN_DIR/reboot-reasons")
    [[ -f /var/run/reboot-required ]] && reasons+=("system packages need a reboot (/var/run/reboot-required)")
    if [[ ${#reasons[@]} -gt 0 ]]; then
        echo ""
        echo -e "  ${YELLOW}${G_REFRESH}${NC}  ${BOLD}Reboot or re-login to apply:${NC}"
        for r in "${reasons[@]}"; do
            echo -e "     ${DIM}${G_INFO} ${r}${NC}"
        done
    fi

    [[ -n "$LOG_FILE" ]] && echo -e "\n  ${DIM}Log: ${LOG_FILE}${NC}"
    echo ""
}

interrupt_run() {
    trap - INT TERM
    if [[ -n "$CURRENT_STEP" ]]; then
        RUN_FAILED+=("$CURRENT_STEP")
        RUN_FAILED_WHY+=("interrupted mid-step — re-run to finish it")
    fi
    echo ""
    warn "Interrupted — stopping after ${RUN_SUCCEEDED} ${ACTION_PAST} step(s)"
    print_summary interrupted
    exit 130
}

# Must be called as a plain statement: inside an if/||/&& context bash ignores set -e and the ERR trap, even in the subshell.
run_step() {
    local step_fn="$1" err_file="$RUN_DIR/step-error" _rc=0 _cmd=""
    rm -f "$err_file"
    set +e
    ( set -eE
      trap '_rc=$?; if (( BASH_SUBSHELL == 1 )) && [[ ! -s "$err_file" ]]; then _cmd=${BASH_COMMAND//$'"'"'\n'"'"'/ }; printf "%s|%s|%s|%s\n" "$_rc" "$LINENO" "${FUNCNAME[0]:-}" "$_cmd" > "$err_file"; if [[ "${FUNCNAME[0]:-}" != run_step && "$_cmd" != return* ]]; then printf "  %b%s%b \"%s\" exited %s (%s, line %s)\n" "$RED" "$G_ERR" "$NC" "$_cmd" "$_rc" "${FUNCNAME[0]:-?}" "$LINENO" >&2; fi; fi' ERR
      "$step_fn" )
    STEP_RC=$?
    set -e
}

step_failure_reason() {
    local step_fn="$1" rc="$2" err_rc err_line err_func err_cmd
    if [[ -s "$RUN_DIR/step-error" ]]; then
        IFS='|' read -r err_rc err_line err_func err_cmd < "$RUN_DIR/step-error"
        if [[ "$err_func" != run_step && "$err_cmd" == return* ]]; then
            echo "a call in $err_func returned $err_rc (line $err_line, see the messages above)"
            return
        elif [[ "$err_func" != run_step ]]; then
            echo "\"$err_cmd\" exited $err_rc ($err_func, line $err_line)"
            return
        fi
    fi
    echo "$step_fn returned $rc (see the messages above)"
}

main() {
    # Parse flags (order-independent).
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

    # This toolkit targets Ubuntu 26.04 — warn (don't refuse) on anything else.
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

    # Uninstalling is destructive — confirm once before touching anything.
    if [[ "$MODE" == "uninstall" ]]; then
        echo ""
        printf "  ${YELLOW}?${NC} Remove ${BOLD}%s${NC} selected app(s)? This cannot be undone. [y/N] " "$STEP_TOTAL"
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

    local border; border=$(ui_rep 53 "$RB_H")
    echo ""
    echo -e "  ${DIM}${RB_TL}${border}${RB_TR}${NC}"
    printf "  ${DIM}${RB_V}${NC}  ${MINTB}${G_DIAMOND}${NC}  ${BOLD}${WHITE}%-48s${NC}${DIM}${RB_V}${NC}\n" "${ACTION_GERUND} ${STEP_TOTAL} packages..."
    echo -e "  ${DIM}${RB_BL}${border}${RB_BR}${NC}"

    RUN_START=$SECONDS
    local entry key label name
    for entry in "${APPS[@]}"; do
        IFS='|' read -r key _ label _ <<< "$entry"
        [[ "${SELECTED[$key]}" == "1" ]] || continue
        # Drop the "::tagline" — only the name belongs in headers & error lines.
        name="${label%%::*}"
        print_step_header "$name"
        CURRENT_STEP="$name"
        run_step "${prefix}${key}"
        CURRENT_STEP=""
        if [[ $STEP_RC -eq 0 ]]; then
            RUN_SUCCEEDED=$((RUN_SUCCEEDED + 1))
        else
            fail "$name — ${MODE} failed"
            RUN_FAILED+=("$name")
            RUN_FAILED_WHY+=("$(step_failure_reason "${prefix}${key}" "$STEP_RC")")
        fi
    done

    if [[ "$MODE" == "install" ]]; then
        # Wire runtime PATH/env into the shell rc even when the zsh Terminal Kit
        # was skipped, so bash — the default shell — still sees the tools.
        local _rt
        for _rt in nvm bun pnpm yarn dotnet abp azcli claude; do
            if [[ "${SELECTED[$_rt]}" == "1" ]]; then
                local _rc
                while read -r _rc; do
                    write_tool_integrations "$_rc" || warn "Could not update the Tool-integrations block in ${_rc##*/}"
                done < <(target_shell_rcs)
                break
            fi
        done
        # Electron apps read this hint to auto-select Wayland, which is what lets
        # fcitx5 type into them. Harmless on X11 (falls back automatically).
        local _el
        for _el in chrome edge teams vscode trae postman; do
            if [[ "${SELECTED[$_el]}" == "1" ]]; then
                if ! grep -q '^ELECTRON_OZONE_PLATFORM_HINT=' /etc/environment 2>/dev/null; then
                    echo 'ELECTRON_OZONE_PLATFORM_HINT=auto' >> /etc/environment
                    need_reboot "/etc/environment changed (Electron Wayland hint)"
                fi
                enable_wayland_ime || warn "Could not install the Wayland IME launcher hook"
                break
            fi
        done
    fi

    # Sweep up packages orphaned by an uninstall pass.
    if [[ "$MODE" == "uninstall" ]]; then
        apt-get autoremove -y >/dev/null 2>&1 || true
        remove_wayland_ime_if_unused
    fi

    trap - INT TERM
    print_summary finished
    [[ ${#RUN_FAILED[@]} -eq 0 ]]
}
