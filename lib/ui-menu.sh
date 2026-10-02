# shellcheck shell=bash

declare -A SELECTED
CURSOR=0
declare -A GROUP_EXPANDED
for _gk in "${GROUP_KEYS[@]}"; do
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
    for gkey in "${GROUP_KEYS[@]}"; do
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
    for gkey in "${GROUP_KEYS[@]}"; do
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

# Two-pane state is kept apart from CURSOR/GROUP_EXPANDED so a resize across 80 columns keeps both layouts' positions.
LAYOUT=one
FOCUS=groups
GROUP_CURSOR=0
APP_CURSOR=0
APP_TOP=0
FOCUS_APPS=()

clamp_panes() {
    local ng=${#GROUP_KEYS[@]}
    (( GROUP_CURSOR >= ng )) && GROUP_CURSOR=$(( ng - 1 ))
    (( GROUP_CURSOR < 0 )) && GROUP_CURSOR=0
    IFS=',' read -ra FOCUS_APPS <<< "${GROUP_APPS[${GROUP_KEYS[GROUP_CURSOR]}]}"
    (( APP_CURSOR >= ${#FOCUS_APPS[@]} )) && APP_CURSOR=$(( ${#FOCUS_APPS[@]} - 1 ))
    (( APP_CURSOR < 0 )) && APP_CURSOR=0
    return 0
}

move_group() {  # $1 delta
    local prev=$GROUP_CURSOR
    GROUP_CURSOR=$(( GROUP_CURSOR + $1 ))
    clamp_panes
    if (( GROUP_CURSOR != prev )); then APP_CURSOR=0; APP_TOP=0; fi
    return 0
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

FOCUS_COL=""
SEL_COL=""

ui_add() { MENU_LINES+=("$1"); }

SCROLL_FROM=0
SCROLL_TO=0

scroll_window() {  # $1 cursor $2 items $3 rows (2 kept for the more markers) $4 top-row variable name → SCROLL_FROM/SCROLL_TO
    local -n top=$4
    local window=$(( $3 - 2 ))
    (( $1 < top )) && top=$1
    (( $1 >= top + window )) && top=$(( $1 - window + 1 ))
    (( top > $2 - window )) && top=$(( $2 - window ))
    (( top < 0 )) && top=0
    SCROLL_FROM=$top; SCROLL_TO=$(( top + window ))
    return 0
}

registry_label() {  # $1 name of a "key|label" array $2 key → REPLY: its label, or the key when absent
    local -n entries=$1
    local e k l
    REPLY=$2
    for e in "${entries[@]}"; do
        IFS='|' read -r k l <<< "$e"
        if [[ "$k" == "$2" ]]; then REPLY=$l; break; fi
    done
    return 0
}

dotnet_text() {  # → REPLY: DOTNET_VERSIONS joined by G_DOT
    local v
    REPLY=""
    for v in "${DOTNET_VERSIONS[@]}"; do REPLY+="${REPLY:+ $G_DOT }$v"; done
}

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
}

ui_row() {  # $1 on_cursor $2 left $3 left plain length $4 right $5 right plain length
    local gap=$(( UI_W - 1 - $3 - $5 ))
    (( gap < 1 )) && gap=1
    ui_rep "$gap" ' '
    if (( $1 )); then
        ui_add "  ${BG_SURFACE}${FOCUS_COL}${G_BAR}${FG0}${2}${REPLY}${4}${NC}"
    else
        ui_add "   ${2}${REPLY}${4}${NC}"
    fi
}

GSTAT_SEL=0
GSTAT_TOTAL=0
GSTAT_COL=""

group_stats() {  # $1 group key → GSTAT_SEL, GSTAT_TOTAL and GSTAT_COL (all green, some yellow, none overlay)
    local app
    local -a apps
    IFS=',' read -ra apps <<< "${GROUP_APPS[$1]}"
    GSTAT_SEL=0; GSTAT_TOTAL=${#apps[@]}
    for app in "${apps[@]}"; do
        [[ "${SELECTED[$app]}" == "1" ]] && GSTAT_SEL=$(( GSTAT_SEL + 1 ))
    done
    GSTAT_COL=$C_GREEN
    if (( GSTAT_SEL == 0 )); then GSTAT_COL=$C_OVERLAY; elif (( GSTAT_SEL < GSTAT_TOTAL )); then GSTAT_COL=$C_YELLOW; fi
    return 0
}

group_icon() {  # $1 group key → REPLY
    REPLY=${GROUP_ICON[$1]}
    (( UI_ASCII )) && REPLY=${GROUP_ICON_ASCII[$1]}
    return 0
}

group_row() {  # $1 group key $2 on_cursor
    local label="${GROUP_LABEL[$1]}" icon arrow="$G_EXPAND" arrow_col="$C_OVERLAY" count
    group_icon "$1"; icon=$REPLY
    group_stats "$1"
    [[ "${GROUP_EXPANDED[$1]}" == "1" ]] && arrow="$G_COLLAPSE"
    (( $2 )) && arrow_col="$FOCUS_COL"
    printf -v count '%5s' "$GSTAT_SEL/$GSTAT_TOTAL"
    ui_bar "$GSTAT_SEL" "$GSTAT_TOTAL" 8 "$GSTAT_COL" "$G_MINI_F" "$G_MINI_E"
    ui_row "$2" " ${arrow_col}${arrow} ${C_LAVENDER}${icon}  ${C_TEXT}${BOLD}${label}${NOBOLD}" \
        $(( 6 + ${#label} )) "${REPLY} ${GSTAT_COL}${count}" 14
}

item_chip() {  # $1 app key → REPLY: live install setting shown at the row's right edge
    REPLY=""
    [[ "$MODE" == install ]] || return 0
    case "$1" in
        mirror) REPLY="$MIRROR_HOST" ;;
        dotnet) dotnet_text; REPLY=".NET $REPLY" ;;
        fcitx5) REPLY="$IME_ENGINE" ;;
        terminal)
            if [[ "${SELECTED[terminal]}" == 1 ]]; then
                if [[ "$ZSH_LOGIN_SHELL" == 1 ]]; then REPLY="login: yes"; else REPLY="login: no"; fi
            fi ;;
    esac
    return 0
}

CELL_NAME=""
CELL_TAG=""
CELL_DOT=""
CELL_DOTC=""
CELL_NAMEC=""
CELL_TAGC=""

app_cells() {  # $1 app key $2 on_cursor → CELL_*: name, tagline, dot and their colours
    local full=${APP_LABELS[$1]}
    CELL_NAME=${full%%::*}; CELL_TAG=""
    [[ "$full" == *"::"* ]] && CELL_TAG=${full#*::}
    if [[ "${SELECTED[$1]}" == "1" ]]; then
        CELL_DOT=$G_ON; CELL_DOTC=$SEL_COL; CELL_NAMEC=$C_TEXT
    else
        CELL_DOT=$G_OFF; CELL_DOTC=$C_OVERLAY; CELL_NAMEC=$C_SUBTEXT
    fi
    CELL_TAGC=$C_OVERLAY
    if (( $2 )); then CELL_NAMEC="${C_TEXT}${BOLD}"; CELL_TAGC=$C_SUBTEXT; fi
    return 0
}

item_row() {  # $1 app key $2 on_cursor
    local LC_ALL=C.UTF-8 chip namecell tag
    app_cells "$1" "$2"
    item_chip "$1"
    ui_trunc "$REPLY" $(( UI_W - 1 - 26 - 2 )); chip=$REPLY
    ui_pad "$CELL_NAME" 18; namecell=$REPLY
    ui_trunc "$CELL_TAG" $(( UI_W - 1 - 26 - ${#chip} - 1 )); tag=$REPLY
    ui_row "$2" "    ${CELL_DOTC}${CELL_DOT} ${CELL_NAMEC}${namecell}${NOBOLD}  ${CELL_TAGC}${tag}" $(( 26 + ${#tag} )) \
        "${C_SAPPHIRE}${chip}" "${#chip}"
}

PANE_SEP=$'\x01'
LEFT_W=28
RIGHT_W=40
PANE_L=()
PANE_R=()
PANE_ROWS=0
SHOW_BANNER=1

settings_row() {  # $1 key $2 name $3 value → one Settings row of the left pane
    local pill name
    ui_pill "$1"; pill=$REPLY
    ui_pad "$2" 7; name=$REPLY
    ui_pad "$3" 13
    PANE_L+=(" ${pill} ${C_SUBTEXT}${name}${C_SAPPHIRE}${REPLY} ${NC}")
}

groups_pane() {  # → PANE_L: group rows, then Settings in install mode
    local i g icon label count bar
    PANE_L=()
    for (( i = 0; i < ${#GROUP_KEYS[@]}; i++ )); do
        g=${GROUP_KEYS[i]}
        group_icon "$g"; icon=$REPLY
        group_stats "$g"
        ui_pad "${GROUP_SHORT[$g]}" 11; label=$REPLY
        printf -v count '%7s' "$GSTAT_SEL/$GSTAT_TOTAL"
        if (( i == GROUP_CURSOR )); then
            bar=" "
            [[ "$FOCUS" == groups ]] && bar="${FOCUS_COL}${G_BAR}"
            PANE_L+=("${BG_SURFACE} ${bar} ${C_LAVENDER}${icon} ${C_TEXT}${BOLD}${label}${NOBOLD}${GSTAT_COL}${count}   ${NC}")
        else
            PANE_L+=("   ${C_LAVENDER}${icon} ${C_TEXT}${label}${GSTAT_COL}${count}   ${NC}")
        fi
    done
    [[ "$MODE" == install ]] || return 0
    PANE_L+=("$PANE_SEP")
    registry_label MIRRORS "$MIRROR_HOST"; REPLY=${REPLY%% — *}; settings_row m mirror "${REPLY%% (*}"
    registry_label INPUT_ENGINES "$IME_ENGINE"; settings_row g IME "$REPLY"
    dotnet_text; settings_row d .NET "$REPLY"
    if [[ "$ZSH_LOGIN_SHELL" == 1 ]]; then settings_row s login zsh; else settings_row s login keep; fi
}

apps_pane() {  # $1 rows → PANE_R: apps of the focused group, scrolled to keep APP_CURSOR visible
    local LC_ALL=C.UTF-8 rows=$1 w=$(( RIGHT_W - 2 )) n=${#FOCUS_APPS[@]} from=0 to i key on lead name tag chip room
    local cells=$(( 3 + 18 + 2 ))
    PANE_R=()
    to=$n
    if (( n > rows )); then
        scroll_window "$APP_CURSOR" "$n" "$rows" APP_TOP
        from=$SCROLL_FROM; to=$SCROLL_TO
        if (( from > 0 )); then ui_pad "  ${G_UP} ${from} more" "$w"; else ui_rep "$w" ' '; fi
        PANE_R+=("${C_OVERLAY}${REPLY}${NC}")
    else
        APP_TOP=0
    fi
    for (( i = from; i < to; i++ )); do
        key=${FOCUS_APPS[i]}
        on=0
        if [[ "$FOCUS" == apps ]] && (( i == APP_CURSOR )); then on=1; fi
        app_cells "$key" "$on"
        ui_pad "$CELL_NAME" 18; name=$REPLY
        chip=""
        if [[ "$key" == dotnet ]]; then item_chip "$key"; chip=$REPLY; fi
        room=$(( w - cells - (${#chip} ? ${#chip} + 2 : 1) ))
        ui_pad "$CELL_TAG" "$room"; tag=$REPLY
        lead=" "
        (( on )) && lead="${BG_SURFACE}${FOCUS_COL}${G_BAR}"
        PANE_R+=("${lead}${CELL_DOTC}${CELL_DOT} ${CELL_NAMEC}${name}${NOBOLD}  ${CELL_TAGC}${tag}${chip:+ ${C_SAPPHIRE}${chip}} ${NC}")
    done
    if (( n > rows )); then
        if (( to < n )); then ui_pad "  ${G_DOWN} $(( n - to )) more" "$w"; else ui_rep "$w" ' '; fi
        PANE_R+=("${C_OVERLAY}${REPLY}${NC}")
    fi
    ui_rep "$w" ' '
    while (( ${#PANE_R[@]} < rows )); do PANE_R+=("$REPLY"); done
}

pane_top() {  # $1 width $2 title $3 right text $4 right colour $5 focused → REPLY
    local LC_ALL=C.UTF-8 right=$3 bc=$C_SURFACE2 tc=$C_SUBTEXT title tail="" extra=0
    if (( $5 )); then bc=$FOCUS_COL; tc="${FOCUS_COL}${BOLD}"; fi
    if [[ -n "$right" ]]; then extra=$(( ${#right} + 3 )); tail=" ${4}${right}${bc} ${RB_H}"; fi
    ui_trunc "$2" $(( $1 - 5 - extra )); title=$REPLY
    ui_rep $(( $1 - 5 - extra - ${#title} )) "$RB_H"
    REPLY="${bc}${RB_TL}${RB_H} ${tc}${title}${NOBOLD}${bc} ${REPLY}${tail}${RB_TR}${NC}"
}

pane_rule() {  # $1 width $2 colour $3 left corner $4 right corner → REPLY
    ui_rep $(( $1 - 2 )) "$RB_H"
    REPLY="${2}${3}${REPLY}${4}${NC}"
}

HINTS=()
HINT_LINES=()
HINT_LAST_LEN=0
HINTS_KEY=""
FOOTER_LINES=()

hint() {  # $1 key $2 label → one "plainlen|coloured" footer hint
    local LC_ALL=C.UTF-8 len=$(( ${#1} + 3 + ${#2} ))
    ui_pill "$1"
    HINTS+=("${len}|${REPLY} ${C_SUBTEXT}${2}${FG0}")
}

build_hints() {
    local key="$UI_W|$MODE|$UI_ASCII|$LAYOUT"
    [[ "$key" == "$HINTS_KEY" ]] && return 0
    HINTS_KEY=$key
    HINTS=()
    if (( UI_ASCII )); then hint "up/dn" move; else hint "↑↓" move; fi
    if [[ "$LAYOUT" == two ]]; then
        if (( UI_ASCII )); then hint "<-/->" panel; else hint "←→" panel; fi
        hint space toggle
    else
        hint space toggle; hint enter expand
    fi
    hint a all; hint n none
    if [[ "$LAYOUT" == one && "$MODE" == install ]]; then
        hint d .NET; hint m mirror; hint g IME; hint s zsh
    fi
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
    HINT_LAST_LEN=$len
}

build_footer() {  # $1 selected count → FOOTER_LINES: hints, then quit and the action button right-aligned
    local LC_ALL=C.UTF-8 n=$1 label=${ACTION_LABEL,,} btn text bg=$BG_MAUVE fg=$C_BASE right rlen last
    build_hints
    if (( UI_ASCII )); then
        fg=$FOCUS_COL
        (( n == 0 )) && fg=$C_OVERLAY
        text="[i ${label} ${n}]"
        btn="${fg}${BOLD}${text}${NOBOLD}${FG0}"
    else
        [[ "$MODE" == uninstall ]] && bg=$BG_RED
        (( n == 0 )) && bg=$BG_SURFACE fg=$C_OVERLAY
        text=" i  ${label} ${n} "
        btn="${bg}${fg}${BOLD}${text}${NOBOLD}${BG0}${FG0}"
    fi
    ui_pill q
    right="${REPLY} ${C_SUBTEXT}quit${FG0}   ${btn}"
    text="[q] quit   ${text}"
    rlen=${#text}
    FOOTER_LINES=("${HINT_LINES[@]}")
    if (( HINT_LAST_LEN + 3 + rlen <= UI_W )); then
        last=$(( ${#FOOTER_LINES[@]} - 1 ))
        ui_rep $(( UI_W - HINT_LAST_LEN - rlen )) ' '
        FOOTER_LINES[last]+="${REPLY}${right}${NC}"
    else
        ui_rep $(( UI_W - rlen )) ' '
        FOOTER_LINES+=("  ${REPLY}${right}${NC}")
    fi
}

pane_rows() {  # → PANE_ROWS (0 when the panes don't fit) and SHOW_BANNER; needs PANE_L built
    local avail=$(( UI_ROWS - 1 - ${#FOOTER_LINES[@]} - 2 )) left=${#PANE_L[@]} full
    full=$(( left > MAX_GROUP_SIZE ? left : MAX_GROUP_SIZE ))
    PANE_ROWS=0; SHOW_BANNER=0
    if (( avail - ${#BANNER_LINES[@]} >= full )); then
        PANE_ROWS=$full; SHOW_BANNER=1
    elif (( avail >= full )); then
        PANE_ROWS=$full
    elif (( avail >= left )); then
        PANE_ROWS=$avail
    fi
    return 0
}

two_pane_menu() {
    local lc=$C_SURFACE2 rc=$C_SURFACE2 lf=0 i l top_l bot_l
    RIGHT_W=$(( UI_W - LEFT_W - 1 ))
    if [[ "$FOCUS" == groups ]]; then lf=1; lc=$FOCUS_COL; else rc=$FOCUS_COL; fi
    (( SHOW_BANNER )) && MENU_LINES+=("${BANNER_LINES[@]}")
    ui_rep $(( LEFT_W - 2 )) ' '
    while (( ${#PANE_L[@]} < PANE_ROWS )); do PANE_L+=("$REPLY"); done
    apps_pane "$PANE_ROWS"
    pane_top "$LEFT_W" Groups "" "" "$lf"; top_l=$REPLY
    group_stats "${GROUP_KEYS[GROUP_CURSOR]}"
    pane_top "$RIGHT_W" "${GROUP_LABEL[${GROUP_KEYS[GROUP_CURSOR]}]}" "$GSTAT_SEL/$GSTAT_TOTAL" "$GSTAT_COL" $(( 1 - lf ))
    ui_add "  ${top_l} ${REPLY}"
    for (( i = 0; i < PANE_ROWS; i++ )); do
        if [[ "${PANE_L[i]}" == "$PANE_SEP" ]]; then
            pane_rule "$LEFT_W" "$lc" "$RB_LT" "$RB_RT"; l=$REPLY
        else
            l="${lc}${RB_V}${NC}${PANE_L[i]}${lc}${RB_V}${NC}"
        fi
        ui_add "  ${l} ${rc}${RB_V}${NC}${PANE_R[i]}${rc}${RB_V}${NC}"
    done
    pane_rule "$LEFT_W" "$lc" "$RB_BL" "$RB_BR"; bot_l=$REPLY
    pane_rule "$RIGHT_W" "$rc" "$RB_BL" "$RB_BR"
    ui_add "  ${bot_l} ${REPLY}"
    MENU_LINES+=("${FOOTER_LINES[@]}")
}

one_column_menu() {
    local n=${#VIS_TYPES[@]} footer_h avail list_h i on
    footer_h=$(( 1 + ${#FOOTER_LINES[@]} ))
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
        scroll_window "$CURSOR" "$n" "$list_h" MENU_TOP
        from=$SCROLL_FROM; to=$SCROLL_TO
    else
        MENU_TOP=0
    fi

    if (( scroll )); then
        if (( from > 0 )); then ui_add "   ${C_OVERLAY}${G_UP} ${from} more${NC}"; else ui_add ""; fi
    fi
    for (( i = from; i < to; i++ )); do
        on=0
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
    ui_add ""
    MENU_LINES+=("${FOOTER_LINES[@]}")
}

print_menu() {
    build_visible
    clamp_cursor
    clamp_panes
    ui_term_size
    FOCUS_COL=$C_MAUVE; SEL_COL=$C_GREEN
    if [[ "$MODE" == uninstall ]]; then FOCUS_COL=$C_RED; SEL_COL=$C_RED; fi
    build_banner
    MENU_LINES=()
    local sel=0 k
    for k in "${!SELECTED[@]}"; do
        [[ "${SELECTED[$k]}" == "1" ]] && sel=$(( sel + 1 ))
    done
    PANE_ROWS=0
    if (( UI_COLS >= 80 )); then
        LAYOUT=two
        build_footer "$sel"
        groups_pane
        pane_rows
    fi
    if (( PANE_ROWS > 0 )); then
        two_pane_menu
    else
        LAYOUT=one
        build_footer "$sel"
        one_column_menu
    fi
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
            '[C'|'OC') echo "RIGHT" ;;
            '[D'|'OD') echo "LEFT" ;;
            *)         echo "ESC" ;;
        esac
    elif [[ "$key" == "" ]]; then
        echo "ENTER"
    elif [[ "$key" == " " ]]; then
        echo "SPACE"
    elif [[ "$key" == $'\t' ]]; then
        echo "TAB"
    elif [[ "$key" == h ]]; then
        echo "LEFT"
    elif [[ "$key" == l ]]; then
        echo "RIGHT"
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
                if [[ "$LAYOUT" == two && "$FOCUS" == groups ]]; then
                    move_group -1
                elif [[ "$LAYOUT" == two ]]; then
                    if (( APP_CURSOR > 0 )); then APP_CURSOR=$((APP_CURSOR - 1)); fi
                elif [[ $CURSOR -gt 0 ]]; then
                    CURSOR=$((CURSOR - 1))
                fi
                ;;
            DOWN)
                if [[ "$LAYOUT" == two && "$FOCUS" == groups ]]; then
                    move_group 1
                elif [[ "$LAYOUT" == two ]]; then
                    if (( APP_CURSOR < ${#FOCUS_APPS[@]} - 1 )); then APP_CURSOR=$((APP_CURSOR + 1)); fi
                elif [[ $CURSOR -lt $((vis_total - 1)) ]]; then
                    CURSOR=$((CURSOR + 1))
                fi
                ;;
            LEFT|RIGHT|TAB)
                if [[ "$LAYOUT" == two ]]; then
                    case "$key" in
                        LEFT)  FOCUS=groups ;;
                        RIGHT) FOCUS=apps ;;
                        TAB)   if [[ "$FOCUS" == groups ]]; then FOCUS=apps; else FOCUS=groups; fi ;;
                    esac
                fi
                ;;
            SPACE)
                if [[ "$LAYOUT" == two && "$FOCUS" == groups ]]; then
                    toggle_group "${GROUP_KEYS[GROUP_CURSOR]}"
                elif [[ "$LAYOUT" == two ]]; then
                    toggle_item "${FOCUS_APPS[APP_CURSOR]}"
                elif [[ "$vtype" == "group" ]]; then
                    toggle_group "$vkey"
                else
                    toggle_item "$vkey"
                fi
                ;;
            ENTER)
                if [[ "$LAYOUT" == two ]]; then
                    FOCUS=apps
                elif [[ "$vtype" == "group" ]]; then
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
            d|m|g)
                if [[ "$MODE" == install ]]; then
                    tput cnorm 2>/dev/null || true
                    case "$key" in
                        d) configure_dotnet ;;
                        m) configure_mirror ;;
                        g) configure_input_method ;;
                    esac
                    tput civis 2>/dev/null || true
                fi
                ;;
            s) [[ "$MODE" == install ]] && toggle_login_shell ;;
            i) menu_ui_stop; trap - EXIT INT TERM; return ;;
            q|QUIT) menu_ui_stop; trap - EXIT INT TERM; echo "Cancelled."; exit 0 ;;
        esac
    done
}
