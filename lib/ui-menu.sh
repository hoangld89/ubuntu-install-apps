# shellcheck shell=bash

declare -A SELECTED
CURSOR=0
declare -A GROUP_EXPANDED
for _g in "${APP_GROUPS[@]}"; do
    IFS='|' read -r _gk _ _ <<< "$_g"
    GROUP_EXPANDED[$_gk]=0
done

init_defaults() {
    # Uninstall starts with nothing selected so nothing is removed by accident.
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

# Collapsing a group shrinks VIS_*; an out-of-range CURSOR would trip set -u.
clamp_cursor() {
    local n=${#VIS_TYPES[@]}
    (( n == 0 )) && { CURSOR=0; return 0; }
    (( CURSOR >= n )) && CURSOR=$((n - 1))
    (( CURSOR < 0 )) && CURSOR=0
    return 0   # never let a false (( )) become the function's exit status (set -e)
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

MENU_LINES=()
MENU_TOP=0
MENU_INFO=""
UI_COLS=80
UI_ROWS=24
UI_W=76
BANNER_LINES=()
BANNER_KEY=""

ui_add() { MENU_LINES+=("$1"); }

# Painting from home and clearing to EOL/below avoids the blank-then-fill flicker of `clear`.
render_menu() {
    local _l
    printf '\033[H'
    for _l in "${MENU_LINES[@]}"; do
        printf '%s\033[K\n' "$_l"
    done
    printf '\033[J'
}

ui_term_size() {
    UI_COLS=$(tput cols 2>/dev/null || echo 80)
    UI_ROWS=$(tput lines 2>/dev/null || echo 24)
    [[ "$UI_COLS" =~ ^[0-9]+$ ]] || UI_COLS=80
    [[ "$UI_ROWS" =~ ^[0-9]+$ ]] || UI_ROWS=24
    UI_W=$(( UI_COLS - 3 ))
    (( UI_W > 96 )) && UI_W=96
    (( UI_W < 40 )) && UI_W=40
    return 0
}

# shellcheck disable=SC2034  # read through the nameref in ui_gradient
UI_RAMP_INSTALL=(cba6f7:183 b4befe:147 89b4fa:111 74c7ec:117)
# shellcheck disable=SC2034
UI_RAMP_UNINSTALL=(f38ba8:211 eba0ac:217 fab387:216)

ui_gradient() {  # $1 text, $2 ramp array name → REPLY: each character coloured along the ramp
    local LC_ALL=C.UTF-8 text=$1 i n ch out="" num s f stops a b r g bl
    local -n ramp=$2
    n=${#text}; stops=${#ramp[@]}
    for (( i = 0; i < n; i++ )); do
        ch=${text:i:1}
        if [[ "$ch" == " " ]]; then out+=" "; continue; fi
        num=$(( i * (stops - 1) * 1000 / (n > 1 ? n - 1 : 1) ))
        s=$(( num / 1000 )); f=$(( num % 1000 ))
        if (( s >= stops - 1 )); then s=$(( stops - 2 )); f=1000; fi
        if (( TRUECOLOR )); then
            a=${ramp[s]%%:*}; b=${ramp[s+1]%%:*}
            r=$(( 0x${a:0:2} + (0x${b:0:2} - 0x${a:0:2}) * f / 1000 ))
            g=$(( 0x${a:2:2} + (0x${b:2:2} - 0x${a:2:2}) * f / 1000 ))
            bl=$(( 0x${a:4:2} + (0x${b:4:2} - 0x${a:4:2}) * f / 1000 ))
            out+=$'\033'"[38;2;${r};${g};${bl}m${ch}"
        else
            (( f >= 500 )) && s=$(( s + 1 ))
            out+=$'\033'"[38;5;${ramp[s]##*:}m${ch}"
        fi
    done
    REPLY="${out}${FG0}"
}

ui_pill() {  # $1 key → REPLY: key drawn as a pill (bracketed in ASCII mode)
    if (( UI_ASCII )); then
        REPLY="${C_TEXT}[${1}]${FG0}"
    else
        REPLY="${BG_SURFACE}${C_TEXT} ${1} ${BG0}${FG0}"
    fi
}

ui_bar() {  # $1 filled $2 total $3 width $4 fill colour $5 fill glyph $6 empty glyph → REPLY
    local total=$2 width=$3 filled full
    (( total == 0 )) && total=1
    filled=$(( $1 * width / total ))
    (( filled > width )) && filled=$width
    ui_rep "$filled" "$5"; full=$REPLY
    ui_rep $(( width - filled )) "$6"
    REPLY="${4}${full}${C_SURFACE2}${REPLY}${FG0}"
}

build_banner() {
    local key="$UI_W|$MODE|$UI_ASCII|$MENU_INFO"
    [[ "$key" == "$BANNER_KEY" ]] && return 0
    BANNER_KEY=$key
    BANNER_LINES=()
    local ramp=UI_RAMP_INSTALL sub="post-install toolkit" info
    [[ "$MODE" == "uninstall" ]] && ramp=UI_RAMP_UNINSTALL && sub="uninstaller"
    ui_trunc "$MENU_INFO" $(( UI_W - 22 )); info=$REPLY
    (( 22 + 15 + ${#sub} > UI_W )) && sub=""
    local title="${C_TEXT}${BOLD}ubuntu setup${NOBOLD}${sub:+ ${C_SUBTEXT}${G_DOT} ${sub}}${NC}"
    BANNER_LINES+=("")
    if (( UI_ASCII )); then
        BANNER_LINES+=("  ${BOLD}${C_MAUVE}SETUP${NOBOLD}  ${title}")
        BANNER_LINES+=("         ${C_OVERLAY}${info}${NC}")
    else
        ui_gradient "█▀▀ █▀▀ ▀█▀ █ █ █▀█" "$ramp"; BANNER_LINES+=("  ${REPLY}   ${title}")
        ui_gradient "▄▄█ ██▄  █  █▄█ █▀▀" "$ramp"; BANNER_LINES+=("  ${REPLY}   ${C_OVERLAY}${info}${NC}")
    fi
    [[ "$MODE" == "uninstall" ]] && BANNER_LINES+=("  ${C_RED}${G_WARN} danger zone ${G_DOT} selected apps will be removed${NC}")
    BANNER_LINES+=("")
    ui_rep "$UI_W" "$G_HEAVY"
    if (( UI_ASCII )); then
        BANNER_LINES+=("  ${C_SURFACE2}${REPLY}${NC}")
    else
        ui_gradient "$REPLY" "$ramp"; BANNER_LINES+=("  ${REPLY}${NC}")
    fi
    BANNER_LINES+=("")
}

ui_row() {  # $1 on_cursor $2 left $3 left plain length $4 right $5 right plain length
    local gap=$(( UI_W - 1 - $3 - $5 ))
    (( gap < 1 )) && gap=1
    ui_rep "$gap" ' '
    if (( $1 )); then
        ui_add "  ${BG_SURFACE}${C_MAUVE}${G_BAR}${FG0}${2}${REPLY}${4}${NC}"
    else
        ui_add "   ${2}${REPLY}${4}${NC}"
    fi
}

group_row() {  # $1 group key $2 on_cursor
    local label="${GROUP_LABEL[$1]}" icon="${GROUP_ICON[$1]}" app gsel=0 gtotal=0
    local arrow="$G_EXPAND" arrow_col="$C_OVERLAY" bar_col="$C_GREEN" count
    (( UI_ASCII )) && icon="${GROUP_ICON_ASCII[$1]}"
    local -a apps
    IFS=',' read -ra apps <<< "${GROUP_APPS[$1]}"
    for app in "${apps[@]}"; do
        [[ "${SELECTED[$app]}" == "1" ]] && gsel=$(( gsel + 1 ))
    done
    gtotal=${#apps[@]}
    [[ "${GROUP_EXPANDED[$1]}" == "1" ]] && arrow="$G_COLLAPSE"
    (( $2 )) && arrow_col="$C_MAUVE"
    if (( gsel == 0 )); then bar_col="$C_OVERLAY"; elif (( gsel < gtotal )); then bar_col="$C_YELLOW"; fi
    printf -v count '%5s' "$gsel/$gtotal"
    ui_bar "$gsel" "$gtotal" 8 "$bar_col" "$G_MINI_F" "$G_MINI_E"
    ui_row "$2" " ${arrow_col}${arrow} ${C_LAVENDER}${icon}  ${C_TEXT}${BOLD}${label}${NOBOLD}" \
        $(( 6 + ${#label} )) "${REPLY} ${bar_col}${count}" 14
}

item_chip() {  # $1 app key → REPLY: live install setting shown at the row's right edge
    REPLY=""
    [[ "$MODE" == install ]] || return 0
    case "$1" in
        mirror) REPLY="$MIRROR_HOST" ;;
        dotnet) REPLY=".NET ${DOTNET_VERSIONS[*]}" ;;
        fcitx5) REPLY="$IME_ENGINE" ;;
        terminal)
            if [[ "${SELECTED[terminal]}" == 1 ]]; then
                if [[ "$ZSH_LOGIN_SHELL" == 1 ]]; then REPLY="login: yes"; else REPLY="login: no"; fi
            fi ;;
    esac
    return 0
}

item_row() {  # $1 app key $2 on_cursor
    local LC_ALL=C.UTF-8
    local full="${APP_LABELS[$1]}" name tag="" chip namecell dot dotc namec tagc
    name="${full%%::*}"
    [[ "$full" == *"::"* ]] && tag="${full#*::}"
    item_chip "$1"
    ui_trunc "$REPLY" $(( UI_W - 1 - 26 - 2 )); chip=$REPLY
    printf -v namecell '%-18s' "$name"
    if [[ "${SELECTED[$1]}" == "1" ]]; then
        dot="$G_ON"; dotc="$C_GREEN"; namec="$C_TEXT"; tagc="$C_SUBTEXT"
    else
        dot="$G_OFF"; dotc="$C_OVERLAY"; namec="$C_OVERLAY"; tagc="$C_SURFACE2"
    fi
    (( $2 )) && namec="${C_TEXT}${BOLD}" && tagc="$C_SUBTEXT"
    ui_trunc "$tag" $(( UI_W - 1 - 26 - ${#chip} - 1 )); tag=$REPLY
    ui_row "$2" "    ${dotc}${dot} ${namec}${namecell}${NOBOLD}  ${tagc}${tag}" $(( 26 + ${#tag} )) \
        "${C_SAPPHIRE}${chip}" "${#chip}"
}

HINTS=()
HINT_LINES=()
HINTS_KEY=""

hint() {  # $1 key $2 label [$3 colour] → one "plainlen|coloured" footer hint
    local LC_ALL=C.UTF-8 len=$(( ${#1} + 3 + ${#2} ))
    ui_pill "$1"
    if [[ -n "${3:-}" ]]; then
        HINTS+=("${len}|${3}${BOLD}${REPLY}${3}${BOLD} ${2}${NOBOLD}${FG0}")
    else
        HINTS+=("${len}|${REPLY} ${C_SUBTEXT}${2}${FG0}")
    fi
}

build_hints() {
    local key="$UI_W|$MODE|$UI_ASCII"
    [[ "$key" == "$HINTS_KEY" ]] && return 0
    HINTS_KEY=$key
    HINTS=()
    if (( UI_ASCII )); then hint "up/dn" move; else hint "↑↓" move; fi
    hint space toggle; hint enter expand; hint a all; hint n none
    hint d .NET; hint m mirror; hint g IME
    [[ "$MODE" == install ]] && hint s zsh
    hint i "$ACTION_LABEL" "$C_MAUVE"; hint q quit
    HINT_LINES=()
    local line="" len=0 item ilen
    for item in "${HINTS[@]}"; do
        ilen=${item%%|*}; item=${item#*|}
        if (( len > 0 && len + 2 + ilen > UI_W )); then
            HINT_LINES+=("  ${line}${NC}"); line=""; len=0
        fi
        (( len > 0 )) && line+="  " && len=$(( len + 2 ))
        line+="$item"; len=$(( len + ilen ))
    done
    HINT_LINES+=("  ${line}${NC}")
}

print_menu() {
    build_visible
    clamp_cursor
    ui_term_size
    build_banner
    build_hints
    MENU_LINES=()
    local total=${#APPS[@]} sel=0 n=${#VIS_TYPES[@]} footer_h avail list_h window i k
    for k in "${!SELECTED[@]}"; do
        [[ "${SELECTED[$k]}" == "1" ]] && sel=$(( sel + 1 ))
    done
    footer_h=$(( 4 + ${#HINT_LINES[@]} ))
    avail=$(( UI_ROWS - 1 - footer_h ))
    local min_list=$(( n < 8 ? n : 8 ))
    if (( avail - ${#BANNER_LINES[@]} >= min_list )); then
        MENU_LINES+=("${BANNER_LINES[@]}")
        list_h=$(( avail - ${#BANNER_LINES[@]} ))
    else
        list_h=$avail
    fi

    local from=0 to=$n scroll=0
    if (( n > list_h && list_h >= 3 )); then
        scroll=1
        window=$(( list_h - 2 ))
        (( CURSOR < MENU_TOP )) && MENU_TOP=$CURSOR
        (( CURSOR >= MENU_TOP + window )) && MENU_TOP=$(( CURSOR - window + 1 ))
        (( MENU_TOP > n - window )) && MENU_TOP=$(( n - window ))
        (( MENU_TOP < 0 )) && MENU_TOP=0
        from=$MENU_TOP; to=$(( MENU_TOP + window ))
    else
        MENU_TOP=0
    fi

    if (( scroll )); then
        if (( from > 0 )); then ui_add "   ${C_OVERLAY}${G_UP} ${from} more${NC}"; else ui_add ""; fi
    fi
    for (( i = from; i < to; i++ )); do
        local on=0
        (( i == CURSOR )) && on=1
        if [[ "${VIS_TYPES[$i]}" == "group" ]]; then
            group_row "${VIS_KEYS[$i]}" "$on"
        else
            item_row "${VIS_KEYS[$i]}" "$on"
        fi
    done
    if (( scroll )); then
        if (( to < n )); then ui_add "   ${C_OVERLAY}${G_DOWN} $(( n - to )) more${NC}"; else ui_add ""; fi
    fi

    local count_txt="$sel/$total selected"
    ui_add ""
    ui_rep "$UI_W" "$G_RULE"
    ui_add "  ${C_SURFACE2}${REPLY}${NC}"
    ui_bar "$sel" "$total" $(( UI_W - ${#count_txt} - 2 )) "$C_MAUVE" "$G_PROG_F" "$G_PROG_E"
    ui_add "  ${C_MAUVE}${BOLD}${sel}${NOBOLD}${C_SUBTEXT}/${total} selected  ${REPLY}${NC}"
    ui_add ""
    MENU_LINES+=("${HINT_LINES[@]}")

    render_menu
}

configure_dotnet() {
    echo ""
    echo -e "  ${C_SUBTEXT}Available:${NC} 8 ${C_YELLOW}(EOL 2026-11-10)${NC}  9 ${C_YELLOW}(EOL 2026-11-10)${NC}  10"
    echo -e "  ${C_SUBTEXT}Current: ${NC} ${BOLD}${DOTNET_VERSIONS[*]}${NC}"
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
    echo -e "  ${C_SUBTEXT}Pick the APT mirror closest to you (Vietnam):${NC}"
    echo ""
    local i=1 host label
    for m in "${MIRRORS[@]}"; do
        IFS='|' read -r host label <<< "$m"
        local mark="  "
        [[ "$host" == "$MIRROR_HOST" ]] && mark="${C_GREEN}${G_ON}${NC}"
        echo -e "    ${mark} ${BOLD}${C_TEXT}${i}${NC}) ${label} ${C_SUBTEXT}(${host})${NC}"
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
    echo -e "  ${C_SUBTEXT}Pick the Vietnamese input-method engine (fcitx5):${NC}"
    echo ""
    local i=1 ekey elabel
    for e in "${INPUT_ENGINES[@]}"; do
        IFS='|' read -r ekey elabel <<< "$e"
        local mark="  "
        [[ "$ekey" == "$IME_ENGINE" ]] && mark="${C_GREEN}${G_ON}${NC}"
        local note=""
        [[ "$ekey" == "lotus" ]] && note=" ${C_SUBTEXT}(third-party apt repo)${NC}"
        echo -e "    ${mark} ${BOLD}${C_TEXT}${i}${NC}) ${elabel}${note}"
        i=$((i + 1))
    done
    echo ""
    read -rp "  Choice [1-${#INPUT_ENGINES[@]}]: " input
    if [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 1 && input <= ${#INPUT_ENGINES[@]} )); then
        IFS='|' read -r IME_ENGINE _ <<< "${INPUT_ENGINES[$((input - 1))]}"
        SELECTED[fcitx5]=1
    fi
}

toggle_login_shell() {
    if [[ "$ZSH_LOGIN_SHELL" == 1 ]]; then
        ZSH_LOGIN_SHELL=0
    else
        ZSH_LOGIN_SHELL=1
        SELECTED[terminal]=1
    fi
}

read_key() {
    # A bare ESC or EOF makes read fail, which would abort the script under set -e.
    local key rest="" st=0
    IFS= read -rsn1 key || st=$?
    # EOF means quit, so a closed stdin can't spin the loop forever.
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
    local login_shell
    login_shell=$(user_login_shell)
    MENU_INFO="v${TOOLKIT_VERSION} ${G_DOT} Ubuntu $(get_ubuntu_version) ${G_DOT} ${REAL_USER} ${G_DOT} ${login_shell##*/} ${G_DOT} ${#APPS[@]} apps"
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
            s) [[ "$MODE" == install ]] && toggle_login_shell ;;
            i) menu_ui_stop; trap - EXIT INT TERM; return ;;
            q|QUIT) menu_ui_stop; trap - EXIT INT TERM; echo "Cancelled."; exit 0 ;;
        esac
    done
}
