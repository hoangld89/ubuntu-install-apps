# shellcheck shell=bash

declare -A SELECTED
CURSOR=0
declare -A GROUP_EXPANDED
for _g in "${APP_GROUPS[@]}"; do
    IFS='|' read -r _gk _ _ <<< "$_g"
    GROUP_EXPANDED[$_gk]=0
done

init_defaults() {
    # In uninstall mode start with everything OFF so nothing is removed by
    # accident — the user explicitly opts each app in.
    local def
    for entry in "${APPS[@]}"; do
        IFS='|' read -r key _ label default <<< "$entry"
        if [[ "$MODE" == "uninstall" ]]; then def=0; else def="$default"; fi
        SELECTED[$key]=$def
    done
}

count_selected() {
    local c=0
    for entry in "${APPS[@]}"; do
        IFS='|' read -r key _ _ <<< "$entry"
        [[ "${SELECTED[$key]}" == "1" ]] && c=$((c + 1))
    done
    echo "$c"
}

VIS_TYPES=()
VIS_KEYS=()

build_visible() {
    VIS_TYPES=()
    VIS_KEYS=()
    for g in "${APP_GROUPS[@]}"; do
        IFS='|' read -r gkey _ <<< "$g"
        gapps="${GROUP_APPS[$gkey]}"
        VIS_TYPES+=("group")
        VIS_KEYS+=("$gkey")
        if [[ "${GROUP_EXPANDED[$gkey]}" == "1" ]]; then
            IFS=',' read -ra apps <<< "$gapps"
            for app in "${apps[@]}"; do
                VIS_TYPES+=("item")
                VIS_KEYS+=("$app")
            done
        fi
    done
}

# Keep CURSOR inside the visible range. Collapsing a group shrinks VIS_*, and
# without this an out-of-range index trips `set -u` (unbound variable) the next
# time interactive_menu reads VIS_TYPES[$CURSOR].
clamp_cursor() {
    local n=${#VIS_TYPES[@]}
    (( n == 0 )) && { CURSOR=0; return 0; }
    (( CURSOR >= n )) && CURSOR=$((n - 1))
    (( CURSOR < 0 )) && CURSOR=0
    return 0   # never let a false (( )) become the function's exit status (set -e)
}

group_sel_count() {
    local gapps="$1"
    IFS=',' read -ra apps <<< "$gapps"
    local sel=0
    for app in "${apps[@]}"; do
        [[ "${SELECTED[$app]}" == "1" ]] && sel=$((sel + 1))
    done
    echo "$sel"
}

group_app_count() {
    local gapps="$1"
    IFS=',' read -ra apps <<< "$gapps"
    echo "${#apps[@]}"
}

toggle_group() {
    local target_gkey="$1"
    for g in "${APP_GROUPS[@]}"; do
        IFS='|' read -r gkey _ <<< "$g"
        gapps="${GROUP_APPS[$gkey]}"
        if [[ "$gkey" == "$target_gkey" ]]; then
            IFS=',' read -ra apps <<< "$gapps"
            local all_on=1
            for app in "${apps[@]}"; do
                if [[ "${SELECTED[$app]}" != "1" ]]; then
                    all_on=0
                    break
                fi
            done
            local val=1
            if [[ $all_on -eq 1 ]]; then
                val=0
            fi
            for app in "${apps[@]}"; do
                SELECTED[$app]=$val
            done
            return
        fi
    done
}

toggle_item() {
    local key="$1"
    if [[ "${SELECTED[$key]}" == "1" ]]; then
        SELECTED[$key]=0
    else
        SELECTED[$key]=1
    fi
}

select_all()   { for entry in "${APPS[@]}"; do IFS='|' read -r key _ _ <<< "$entry"; SELECTED[$key]=1; done; }
deselect_all() { for entry in "${APPS[@]}"; do IFS='|' read -r key _ _ <<< "$entry"; SELECTED[$key]=0; done; }

# Lines are buffered, then painted in one pass from the home position. Each
# line is cleared to EOL (\033[K) and the area below is cleared (\033[J) so
# nothing ever blanks-then-fills — no flicker, no full `clear`.

MENU_LINES=()

ui_rep() {  # repeat char $2, $1 times → stdout
    local n=$1 ch=$2 out
    printf -v out '%*s' "$n" ''
    printf '%s' "${out// /$ch}"
}

ui_add()  { MENU_LINES+=("$1"); }            # push a literal line
ui_addf() { local _l; printf -v _l "$@"; MENU_LINES+=("$_l"); }  # push formatted

render_menu() {
    local _l
    printf '\033[H'
    for _l in "${MENU_LINES[@]}"; do
        printf '%s\033[K\n' "$_l"
    done
    printf '\033[J'
}

ui_progress_bar() {  # $1 selected $2 total → colored "██████░░░░"
    local sel=$1 total=$2 width=18 filled
    (( total == 0 )) && total=1
    filled=$(( sel * width / total ))
    (( filled > width )) && filled=width
    printf '%b%s%b%s%b' "$MINT" "$(ui_rep "$filled" "$G_PROG_F")" \
        "$DIM" "$(ui_rep $((width - filled)) "$G_PROG_E")" "$NC"
}

ui_gradient_rule() {  # $1 width, $2 char → dark→light green gradient rule
    local width=${1:-55} ch=${2:-━}
    # ASCII mode has no per-cell color budget to spare — plain dim rule.
    if (( UI_ASCII == 1 )); then
        printf '%b%s%b' "$MINTD" "$(ui_rep "$width" "$G_RULE")" "$NC"
        return 0
    fi
    local ramp=(23 29 35 71 77 83 84 120 84 83 77 71 35 29)
    local n=${#ramp[@]} out="" i seg
    for (( i=0; i<width; i++ )); do
        seg=$(( i * n / width ))
        out+="\033[38;5;${ramp[$seg]}m${ch}"
    done
    out+="$NC"
    printf '%b' "$out"
}

print_banner() {
    local G1='\033[1;38;5;157m'  # brightest mint
    local G2='\033[1;38;5;120m'  # bright mint
    local G3='\033[38;5;113m'    # mint green
    local G4='\033[38;5;71m'     # leaf green
    local G5='\033[38;5;34m'     # dark green
    local G6='\033[38;5;22m'     # deep forest (shadow)

    ui_add  ""
    ui_addf "   ${G1}███████╗ ███████╗ ████████╗ ██╗   ██╗ ██████╗${NC}"
    ui_addf "   ${G2}██╔════╝ ██╔════╝ ╚══██╔══╝ ██║   ██║ ██╔══██╗${NC}"
    ui_addf "   ${G3}███████╗ █████╗      ██║    ██║   ██║ ██████╔╝${NC}"
    ui_addf "   ${G4}╚════██║ ██╔══╝      ██║    ██║   ██║ ██╔═══╝${NC}"
    ui_addf "   ${G5}███████║ ███████╗    ██║    ╚██████╔╝ ██║${NC}"
    ui_addf "   ${G6}╚══════╝ ╚══════╝    ╚═╝     ╚═════╝  ╚═╝${NC}"
    ui_add  ""
    if [[ "$MODE" == "uninstall" ]]; then
        ui_addf "      ${MINTB}ubuntu setup${NC} ${DIM}· uninstaller${NC}"
        ui_addf "      ${YELLOW}danger zone — selected apps will be wiped${NC}"
    else
        ui_addf "      ${MINTB}ubuntu setup${NC} ${DIM}· post-install toolkit${NC}"
        ui_addf "      ${MINTD}from bare install to battle-ready${NC}"
    fi
    ui_add  ""
    ui_add  "  $(ui_gradient_rule 55 ━)"
    ui_add  ""
}

print_menu() {
    build_visible
    clamp_cursor
    MENU_LINES=()
    local total=${#APPS[@]}
    local sel
    sel=$(count_selected)
    local rule; rule=$(ui_rep 55 "$G_RULE")

    # ── Banner ──
    print_banner

    # ── List ──
    local i=0
    for (( i=0; i<${#VIS_TYPES[@]}; i++ )); do
        local vtype="${VIS_TYPES[$i]}"
        local vkey="${VIS_KEYS[$i]}"
        local on_cursor=0
        [[ $i -eq $CURSOR ]] && on_cursor=1

        if [[ "$vtype" == "group" ]]; then
            local glabel="" gicon="" gapps="${GROUP_APPS[$vkey]}"
            for g in "${APP_GROUPS[@]}"; do
                IFS='|' read -r gk gl gi gia <<< "$g"
                if [[ "$gk" == "$vkey" ]]; then
                    glabel="$gl"; gicon="$gi"
                    (( UI_ASCII == 1 )) && gicon="$gia"
                    break
                fi
            done

            local gsel gtotal
            gsel=$(group_sel_count "$gapps")
            gtotal=$(group_app_count "$gapps")

            local arrow="$G_EXPAND"
            [[ "${GROUP_EXPANDED[$vkey]}" == "1" ]] && arrow="$G_COLLAPSE"

            local status_color="${MINT}" status_dot="$G_ON"
            if [[ "$gsel" -eq 0 ]]; then
                status_color="${DIM}"; status_dot="$G_OFF"
            elif [[ "$gsel" -lt "$gtotal" ]]; then
                status_color="${YELLOW}"; status_dot="$G_PART"
            fi

            if [[ $on_cursor -eq 1 ]]; then
                ui_addf "  ${MINTB}${G_BAR}${NC} ${MINTB}${arrow}${NC} ${MINTD}${gicon}${NC} ${BOLD}${WHITE}%-30s${NC} %b%s %s/%s${NC}" \
                    "$glabel" "$status_color" "$status_dot" "$gsel" "$gtotal"
            else
                ui_addf "    ${DIM}${arrow}${NC} ${MINTD}${gicon}${NC} ${BOLD}${WHITE}%-30s${NC} %b%s %s/%s${NC}" \
                    "$glabel" "$status_color" "$status_dot" "$gsel" "$gtotal"
            fi

        else
            # Label is "Name::tagline" — name is the highlighted column, tagline
            # the dim hint to its right. Items without "::" render name-only.
            local full="${APP_LABELS[$vkey]}"
            local name="$full" tag=""
            if [[ "$full" == *"::"* ]]; then
                name="${full%%::*}"; tag="${full#*::}"
            fi

            # Configurable items carry a live value chip after the tagline.
            local chip=""
            [[ "$vkey" == "dotnet" ]] && chip=" ${MINTD}[${DOTNET_VERSIONS[*]}]${NC}"
            [[ "$vkey" == "mirror" ]] && chip=" ${MINTD}[${MIRROR_HOST}]${NC}"
            [[ "$vkey" == "fcitx5" ]] && chip=" ${MINTD}[${IME_ENGINE}]${NC}"

            local marker="  "
            [[ $on_cursor -eq 1 ]] && marker="${MINTB}${G_BAR}${NC} "

            local namecell; printf -v namecell '%-20s' "$name"
            local mdot tagcol="$DIM"
            [[ $on_cursor -eq 1 ]] && tagcol="$MINTD"
            if [[ "${SELECTED[$vkey]}" == "1" ]]; then
                mdot="${MINT}${G_ON}${NC}"; namecell="${WHITE}${namecell}${NC}"
            else
                mdot="${DIM}${G_OFF}${NC}"; namecell="${DIM}${namecell}${NC}"
            fi
            ui_addf "  %b      %b %b %b%s%b%b" \
                "$marker" "$mdot" "$namecell" "$tagcol" "$tag" "$NC" "$chip"
        fi
    done

    # ── Footer ──
    ui_add  ""
    ui_addf "  ${DIM}%s${NC}" "$rule"
    ui_addf "  ${MINTB}%s${NC}${DIM}/%s selected${NC}   %s" \
        "$sel" "$total" "$(ui_progress_bar "$sel" "$total")"
    ui_add  ""
    if (( UI_ASCII == 1 )); then
        # Borderless hints — box-drawing alignment isn't worth the tofu risk.
        ui_addf "  ${MINTD}Navigate${NC}  ${BOLD}${WHITE}Up/Dn${NC} ${DIM}move${NC}   ${BOLD}${WHITE}Enter${NC} ${DIM}expand${NC}   ${BOLD}${WHITE}Space${NC} ${DIM}toggle${NC}"
        ui_addf "  ${MINTD}Select  ${NC}  ${BOLD}${WHITE}a${NC} ${DIM}all${NC}   ${BOLD}${WHITE}n${NC} ${DIM}none${NC}   ${BOLD}${WHITE}d${NC} ${DIM}.NET ver${NC}   ${BOLD}${WHITE}m${NC} ${DIM}mirror${NC}   ${BOLD}${WHITE}g${NC} ${DIM}input${NC}"
        ui_addf "  ${MINTD}Actions ${NC}  ${MINTB}i${NC} ${MINTB}%s${NC}   ${BOLD}${WHITE}q${NC} ${DIM}quit${NC}" "$ACTION_LABEL"
    else
        ui_addf "  ${DIM}┌─${NC} ${MINTD}Navigate${NC} ${DIM}─────┬─${NC} ${MINTD}Select${NC} ${DIM}───────┬─${NC} ${MINTD}Actions${NC} ${DIM}─────────┐${NC}"
        ui_addf "  ${DIM}│${NC}  ${BOLD}${WHITE}↑ ↓${NC}  ${DIM}Move${NC}     ${DIM}│${NC}  ${BOLD}${WHITE}Space${NC}  ${DIM}Toggle${NC} ${DIM}│${NC}  ${BOLD}${WHITE}d${NC}  ${DIM}.NET version${NC}  ${DIM}│${NC}"
        ui_addf "  ${DIM}│${NC}  ${BOLD}${WHITE}↵${NC}    ${DIM}Expand${NC}   ${DIM}│${NC}  ${BOLD}${WHITE}a${NC}      ${DIM}All${NC}    ${DIM}│${NC}  ${BOLD}${WHITE}m${NC}  ${DIM}APT mirror${NC}    ${DIM}│${NC}"
        ui_addf "  ${DIM}│${NC}                ${DIM}│${NC}  ${BOLD}${WHITE}n${NC}      ${DIM}None${NC}   ${DIM}│${NC}  ${BOLD}${WHITE}g${NC}  ${DIM}Input engine${NC}  ${DIM}│${NC}"
        ui_addf "  ${DIM}│${NC}                ${DIM}│${NC}                ${DIM}│${NC}  ${MINTB}i${NC}  ${MINTB}%-7s${NC}    ${MINT}▸${NC}  ${DIM}│${NC}" "$ACTION_LABEL"
        ui_addf "  ${DIM}│${NC}                ${DIM}│${NC}                ${DIM}│${NC}  ${BOLD}${WHITE}q${NC}  ${DIM}Quit${NC}          ${DIM}│${NC}"
        ui_addf "  ${DIM}└────────────────┴────────────────┴───────────────────┘${NC}"
    fi
    ui_add  ""

    render_menu
}

configure_dotnet() {
    echo ""
    echo -e "  ${DIM}Available:${NC} 8 ${YELLOW}(EOL 2026-11-10)${NC}  9 ${YELLOW}(EOL 2026-11-10)${NC}  10"
    echo -e "  ${DIM}Current: ${NC} ${BOLD}${DOTNET_VERSIONS[*]}${NC}"
    echo ""
    local input v picked=()
    read -rp "  Versions (e.g. '8 10'): " input
    [[ -n "$input" ]] || return 0
    read -ra picked <<< "$input"
    for v in "${picked[@]}"; do
        if [[ ! "$v" =~ ^(8|9|10)$ ]]; then
            warn "Unsupported .NET version '$v' — keeping ${DOTNET_VERSIONS[*]}"
            sleep 1.5
            return 0
        fi
    done
    mapfile -t DOTNET_VERSIONS < <(printf '%s\n' "${picked[@]}" | sort -nu)
    SELECTED[dotnet]=1
}

configure_mirror() {
    echo ""
    echo -e "  ${DIM}Pick the APT mirror closest to you (Vietnam):${NC}"
    echo ""
    local i=1 host label
    for m in "${MIRRORS[@]}"; do
        IFS='|' read -r host label <<< "$m"
        local mark="  "
        [[ "$host" == "$MIRROR_HOST" ]] && mark="${MINT}${G_ON}${NC}"
        echo -e "    ${mark} ${BOLD}${WHITE}${i}${NC}) ${label} ${DIM}(${host})${NC}"
        i=$((i + 1))
    done
    echo ""
    read -rp "  Choice [1-${#MIRRORS[@]}]: " input
    if [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 1 && input <= ${#MIRRORS[@]} )); then
        IFS='|' read -r MIRROR_HOST _ <<< "${MIRRORS[$((input - 1))]}"
        SELECTED[mirror]=1
    fi
}

configure_input_method() {
    echo ""
    echo -e "  ${DIM}Pick the Vietnamese input-method engine (fcitx5):${NC}"
    echo ""
    local i=1 ekey elabel
    for e in "${INPUT_ENGINES[@]}"; do
        IFS='|' read -r ekey elabel <<< "$e"
        local mark="  "
        [[ "$ekey" == "$IME_ENGINE" ]] && mark="${MINT}${G_ON}${NC}"
        local note=""
        [[ "$ekey" == "lotus" ]] && note=" ${DIM}(third-party apt repo)${NC}"
        echo -e "    ${mark} ${BOLD}${WHITE}${i}${NC}) ${elabel}${note}"
        i=$((i + 1))
    done
    echo ""
    read -rp "  Choice [1-${#INPUT_ENGINES[@]}]: " input
    if [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 1 && input <= ${#INPUT_ENGINES[@]} )); then
        IFS='|' read -r IME_ENGINE _ <<< "${INPUT_ENGINES[$((input - 1))]}"
        SELECTED[fcitx5]=1
    fi
}

read_key() {
    # `|| true` guards each read: a bare ESC press (or EOF) makes read return
    # non-zero, which would otherwise abort the whole script under `set -e`.
    local key rest="" st=0
    IFS= read -rsn1 key || st=$?
    # EOF (stdin closed) returns non-zero with no char — treat as quit so the
    # loop never spins forever on a closed/exhausted input.
    if (( st > 0 )) && [[ -z "$key" ]]; then echo "QUIT"; return 0; fi
    if [[ "$key" == $'\x1b' ]]; then
        read -rsn2 -t 0.1 rest || true
        # Application cursor mode (tmux, some terminals) sends ESC O A/B.
        case "$rest" in
            '[A'|'OA') echo "UP" ;;
            '[B'|'OB') echo "DOWN" ;;
            *)         echo "ESC" ;;
        esac
    elif [[ "$key" == "" ]]; then
        echo "ENTER"
    elif [[ "$key" == " " ]]; then
        echo "SPACE"
    elif [[ "$key" == k ]]; then
        echo "UP"
    elif [[ "$key" == j ]]; then
        echo "DOWN"
    else
        echo "$key"
    fi
}

menu_ui_start() { printf '\033[?1049h\033[H'; tput civis 2>/dev/null || true; }
menu_ui_stop()  { tput cnorm 2>/dev/null || true; printf '\033[?1049l'; }

interactive_menu() {
    menu_ui_start
    trap 'menu_ui_stop' EXIT
    trap 'menu_ui_stop; trap - EXIT; exit 130' INT TERM
    while true; do
        print_menu
        local key
        key=$(read_key)
        local vis_total=${#VIS_TYPES[@]}
        local vtype="${VIS_TYPES[$CURSOR]}"
        local vkey="${VIS_KEYS[$CURSOR]}"

        case "$key" in
            UP)
                if [[ $CURSOR -gt 0 ]]; then
                    CURSOR=$((CURSOR - 1))
                fi
                ;;
            DOWN)
                if [[ $CURSOR -lt $((vis_total - 1)) ]]; then
                    CURSOR=$((CURSOR + 1))
                fi
                ;;
            SPACE)
                if [[ "$vtype" == "group" ]]; then
                    toggle_group "$vkey"
                else
                    toggle_item "$vkey"
                fi
                ;;
            ENTER)
                if [[ "$vtype" == "group" ]]; then
                    if [[ "${GROUP_EXPANDED[$vkey]}" == "1" ]]; then
                        GROUP_EXPANDED[$vkey]=0
                    else
                        GROUP_EXPANDED[$vkey]=1
                    fi
                    build_visible
                    clamp_cursor
                fi
                ;;
            a) select_all ;;
            n) deselect_all ;;
            d) tput cnorm 2>/dev/null || true; configure_dotnet; tput civis 2>/dev/null || true ;;
            m) tput cnorm 2>/dev/null || true; configure_mirror; tput civis 2>/dev/null || true ;;
            g) tput cnorm 2>/dev/null || true; configure_input_method; tput civis 2>/dev/null || true ;;
            i) menu_ui_stop; trap - EXIT INT TERM; return ;;
            q|QUIT) menu_ui_stop; trap - EXIT INT TERM; echo "Cancelled."; exit 0 ;;
        esac
    done
}
