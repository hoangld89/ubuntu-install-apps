#!/usr/bin/env bash
# Re-exec under bash if launched with `sh`/dash — avoids bash array-syntax errors
# (e.g. `sh: Syntax error: "(" unexpected`). dash reads line-by-line, so this
# guard runs before any bash-only syntax further down is ever parsed.
if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi
set -euo pipefail

# ============================================================
# SETUP — Post-install toolkit for Ubuntu 24.04
# Interactive app selector for a fresh Ubuntu 24.04 (noble) machine
#   ./install-app.sh              interactive install
#   ./install-app.sh --all        install everything
#   ./install-app.sh --uninstall  interactive uninstall
#   ./install-app.sh --uninstall --all
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

# Leaf-green accent palette on neutral chrome
MINT='\033[38;5;113m'        # leaf green (≈ #87CF3E)
MINTB='\033[1;38;5;113m'     # bold leaf green
MINTD='\033[38;5;108m'       # muted sage green
LEAF='\033[38;5;71m'         # darker leaf green

# --- Glyph set ---------------------------------------------------------------
# The menu leans on box-drawing and geometric symbols. Terminals whose font
# lacks them (e.g. a bare VS Code integrated terminal, minimal SSH sessions)
# render "tofu" boxes instead. UI_ASCII swaps every glyph for a 7-bit-safe
# equivalent so the menu stays legible on any font. Defaults below are the
# pretty Unicode set; setup_glyphs() flips them when ASCII mode is active.
UI_ASCII=0
# selection / tree
G_ON="●"; G_OFF="○"; G_PART="◐"
G_EXPAND="▸"; G_COLLAPSE="▾"; G_BAR="▌"
# bars & rules
G_PROG_F="█"; G_PROG_E="░"; G_RULE="─"
# status / log markers
G_INFO="▸"; G_OK="✓"; G_WARN="!"; G_ERR="✗"
G_DIAMOND="◈"; G_REFRESH="⟳"; G_CLOCK="⏱"
# rounded box (summary panels)
RB_TL="╭"; RB_TR="╮"; RB_BL="╰"; RB_BR="╯"; RB_H="─"; RB_V="│"
# group icons, keyed by group key
declare -A G_ICON=( [system]="⚙" [dev]="◆" [devops]="▲" [database]="⬡" [desktop]="◎" )

setup_glyphs() {
    # Auto-enable ASCII in an explicitly non-UTF-8 locale — multibyte glyphs
    # can't render there. A blank locale (sudo may strip it) is left as-is and
    # assumed UTF-8. MINT_ASCII / --ascii force it on regardless.
    local loc="${LC_ALL:-}${LC_CTYPE:-}${LANG:-}"
    [[ -n "$loc" && "$loc" != *[Uu][Tt][Ff]* ]] && UI_ASCII=1
    [[ "${MINT_ASCII:-0}" == "1" ]] && UI_ASCII=1
    (( UI_ASCII == 0 )) && return 0

    G_ON="*"; G_OFF="-"; G_PART="~"
    G_EXPAND=">"; G_COLLAPSE="v"; G_BAR="|"
    G_PROG_F="#"; G_PROG_E="."; G_RULE="-"
    G_INFO=">"; G_OK="+"; G_WARN="!"; G_ERR="x"
    G_DIAMOND="*"; G_REFRESH="~"; G_CLOCK="~"
    RB_TL="+"; RB_TR="+"; RB_BL="+"; RB_BR="+"; RB_H="-"; RB_V="|"
    G_ICON=( [system]="#" [dev]=">" [devops]="^" [database]="=" [desktop]="@" )
}

# --- Run mode ----------------------------------------------------------------
# install | uninstall — set in main() from CLI flags. Drives menu labels,
# default selection, and which dispatch prefix (do_ / undo_) main() calls.
MODE="install"
ALL=0
ACTION_LABEL="Install"      # footer hint label
ACTION_GERUND="Installing"  # progress box verb
ACTION_PAST="installed"     # summary stat verb

# --- App registry -----------------------------------------------------------
# Format: "key|Name::tagline|default_on"
# The `::` splits the display name (highlighted) from a dim one-line tagline.
APPS=(
    # ── System ──
    "mirror|APT Mirror::route apt through Vietnam's fastest mirrors|1"
    "update|System Update::refresh sources & upgrade every package|1"
    "swap|Swap File::8 GB swap · swappiness dialed to 10|1"

    # ── Shell & Terminal ──
    "terminal|Terminal Kit::zsh · oh-my-zsh · tmux · fzf · rg · bat · jq|1"
    "font|Nerd Font::MesloLGS glyphs for prompts & icons|1"
    "eza|eza::a modern ls with icons & git awareness|1"

    # ── Languages & Runtime ──
    "nvm|Node.js 24::managed by nvm, swap versions on the fly|1"
    "bun|Bun::all-in-one JS runtime & toolkit, blazing fast|1"
    "pnpm|pnpm::fast, disk-efficient package manager via corepack|1"
    "yarn|Yarn::the classic JS package manager via corepack|1"
    "dotnet|.NET SDK::build & run cross-platform .NET|1"
    "abp|ABP CLI::ABP Studio CLI for building ABP apps|1"

    # ── Browser ──
    "chrome|Google Chrome::the web's default browser|1"
    "edge|Microsoft Edge::Chromium with a Microsoft accent|1"

    # ── Communication ──
    "teams|Microsoft Teams::a native client built for Linux|1"

    # ── IDE & Editor ──
    "vscode|VS Code::the editor that does it all|1"
    "trae|Trae IDE::AI-native coding by ByteDance|1"

    # ── DevOps & Infrastructure ──
    "terraform|Terraform::infrastructure as code, done right|1"
    "azcli|Azure CLI::command the Azure cloud from your shell|1"
    "azcopy|AzCopy::blazing-fast Azure Storage transfers|1"
    "docker|Docker::container engine + Compose plugin|1"
    "browserstack|BrowserStack Local::secure tunnel for local cross-browser testing|1"

    # ── Database Tools ──
    "mysqlclient|MySQL Client::CLI shell + mysqldump backups|1"
    "pgclient|PostgreSQL Client::psql shell + pg_dump backups|1"
    "dbeaver|DBeaver CE::one GUI for every database|1"
    "navicat|Navicat Lite::a sleek database workbench|1"

    # ── Productivity ──
    "fcitx5|Fcitx5::Vietnamese typing — Unikey / Bamboo / Lotus|1"
    "postman|Postman::the API platform for building & testing|1"
    "waydroid|Waydroid::run Android apps in a container (Wayland)|1"
    "vlc|VLC::plays every media format on earth|1"

    # ── Media & Capture ──
    "obs|OBS Studio::record & stream your screen, pro-grade|1"

    # ── Remote Desktop ──
    "anydesk|AnyDesk::fast remote desktop & support|1"
    "teamviewer|TeamViewer::remote control & support, cross-platform|1"

    # ── AI Tools ──
    "claude|Claude Code::Anthropic's agentic dev CLI|1"
)

declare -A SELECTED
DOTNET_VERSIONS=(10)
CURSOR=0

# Vietnamese input-method engine for fcitx5 — default Unikey. Press 'g' in the
# menu to switch. `lotus` is a third-party fcitx5 addon (own apt repo); the
# other two ship in Ubuntu's official archive.
IME_ENGINE="unikey"
INPUT_ENGINES=(
    "unikey|Unikey"
    "bamboo|Bamboo"
    "lotus|Lotus"
)

# APT mirror — default to the official Ubuntu Vietnam mirror. Press 'm' in the
# menu to pick another nearby mirror.
MIRROR_HOST="mirror.bizflycloud.vn"
MIRRORS=(
    "mirror.bizflycloud.vn|BizFly Cloud — VCCorp (1 Gbps)"
    "vn.archive.ubuntu.com|Ubuntu VN Official — XTDV CDN"
    "mirror.viettelcloud.vn|Viettel Cloud (1 Gbps, HTTP only)"
    "mirrors.gofiber.vn|GoFiber (1 Gbps)"
    "mirrors.tino.org|Tino Group — HCM"
    "mirror.clearsky.vn|ClearSky"
)

APP_GROUPS=(
    "system|System & Shell|⚙|mirror,update,swap,terminal,font,eza"
    "dev|Languages & IDEs|◆|nvm,bun,pnpm,yarn,dotnet,abp,vscode,trae,claude"
    "devops|DevOps & Cloud|▲|terraform,azcli,azcopy,docker,browserstack"
    "database|Databases|⬡|mysqlclient,pgclient,dbeaver,navicat"
    "desktop|Apps & Desktop|◎|chrome,edge,teams,fcitx5,postman,waydroid,vlc,obs,anydesk,teamviewer"
)

declare -A GROUP_EXPANDED
for _g in "${APP_GROUPS[@]}"; do
    IFS='|' read -r _gk _ _ _ <<< "$_g"
    GROUP_EXPANDED[$_gk]=0
done

declare -A APP_LABELS
for _entry in "${APPS[@]}"; do
    IFS='|' read -r _k _l _ <<< "$_entry"
    APP_LABELS[$_k]="$_l"
done

init_defaults() {
    # In uninstall mode start with everything OFF so nothing is removed by
    # accident — the user explicitly opts each app in.
    local def
    for entry in "${APPS[@]}"; do
        IFS='|' read -r key label default <<< "$entry"
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
        IFS='|' read -r gkey _ _ gapps <<< "$g"
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
        IFS='|' read -r gkey _ _ gapps <<< "$g"
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

# --- Flicker-free rendering -------------------------------------------------
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
            local glabel="" gapps=""
            for g in "${APP_GROUPS[@]}"; do
                IFS='|' read -r gk gl gi ga <<< "$g"
                if [[ "$gk" == "$vkey" ]]; then
                    glabel="$gl"; gapps="$ga"
                    break
                fi
            done
            local gicon="${G_ICON[$vkey]}"

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
    echo -e "  ${DIM}Available:${NC} 6  7  8  9  10"
    echo -e "  ${DIM}Current: ${NC} ${BOLD}${DOTNET_VERSIONS[*]}${NC}"
    echo ""
    read -rp "  Versions (e.g. '8 9 10'): " input
    if [[ -n "$input" ]]; then
        read -ra DOTNET_VERSIONS <<< "$input"
        SELECTED[dotnet]=1
    fi
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
        case "$rest" in
            '[A') echo "UP" ;;
            '[B') echo "DOWN" ;;
            *)    echo "ESC" ;;
        esac
    elif [[ "$key" == "" ]]; then
        echo "ENTER"
    elif [[ "$key" == " " ]]; then
        echo "SPACE"
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

# --- Helpers -----------------------------------------------------------------

STEP_CURRENT=0
STEP_TOTAL=0

info()    { echo -e "\n  ${MINT}${G_INFO}${NC} $*"; }
success() { echo -e "  ${MINT}${G_OK}${NC} $*"; }
warn()    { echo -e "  ${YELLOW}${G_WARN}${NC} $*"; }
fail()    { echo -e "  ${RED}${G_ERR}${NC} $*"; }

print_step_header() {
    local label="$1"
    STEP_CURRENT=$((STEP_CURRENT + 1))
    echo ""
    echo -e "  ${MINTB}[${STEP_CURRENT}/${STEP_TOTAL}]${NC} ${BOLD}${WHITE}${label}${NC}"
    echo -e "  ${DIM}$(ui_rep 50 "$G_RULE")${NC}"
}

need_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}Requesting sudo privileges...${NC}"
        # Pass the original CLI args along — otherwise flags like --uninstall /
        # --all are dropped on the sudo re-exec.
        exec sudo bash "$0" "$@"
    fi
}

REAL_USER="${SUDO_USER:-${USER:-$(id -un)}}"
REAL_HOME=$(eval echo "~$REAL_USER")

get_ubuntu_codename() {
    . /etc/os-release
    echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}"
}

get_ubuntu_version() {
    if command -v lsb_release &>/dev/null; then
        lsb_release -rs
    else
        ( . /etc/os-release && echo "${VERSION_ID:-}" )
    fi
}

ensure_microsoft_gpg() {
    if [[ ! -f /usr/share/keyrings/microsoft.gpg ]]; then
        apt install -y wget gpg apt-transport-https >/dev/null 2>&1
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
            | gpg --dearmor -o /usr/share/keyrings/microsoft.gpg
    fi
}

# Purge packages without ever aborting the run (missing packages are fine).
apt_purge() {
    DEBIAN_FRONTEND=noninteractive apt-get purge -y "$@" >/dev/null 2>&1 || true
}

# Download a .deb to $dest, retrying on flaky networks, then verify the archive
# is a well-formed Debian package before the caller hands it to apt. A truncated
# download (wget can exit 0 on a partial transfer through some proxies) yields a
# corrupt .deb that apt rejects with "could not locate member control.tar" /
# "could not read meta" — so we validate with `dpkg-deb` and fail loudly instead.
# `--contents` (not `--info`) is used on purpose: it reads data.tar, the final
# archive member, so a download truncated anywhere is caught; `--info` only reads
# the control member near the start and passes on a partial file.
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

# Remove a marked block from the user's shell rc files. Install steps wrap their
# additions in `# --- <label> ---` … `# --- end <label> ---` so this deletes them
# cleanly from wherever they landed (.zshrc when zsh is installed, else .bashrc).
# Runs as root but rewrites REAL_USER's files and restores ownership.
strip_rc_block() {
    local label="$1" rc
    for rc in "$REAL_HOME/.zshrc" "$REAL_HOME/.bashrc"; do
        [[ -f "$rc" ]] || continue
        sed -i "/^# --- ${label} ---\$/,/^# --- end ${label} ---\$/d" "$rc"
        chown "$REAL_USER:$REAL_USER" "$rc" 2>/dev/null || true
    done
}

# Which shell rc should tool integrations & aliases be written to? If the user
# installs (or already uses) zsh, target ~/.zshrc; otherwise leave zsh untouched
# and write to ~/.bashrc so bash — the default shell — picks up the settings.
resolve_shell_rc() {
    local login_shell
    login_shell=$(getent passwd "$REAL_USER" | cut -d: -f7)
    if [[ "${SELECTED[terminal]:-0}" == "1" || "$login_shell" == *zsh ]]; then
        echo "$REAL_HOME/.zshrc"
    else
        echo "$REAL_HOME/.bashrc"
    fi
}

# Append the shared "Tool integrations" block (PATH/env for nvm, bun, pnpm,
# .NET, Azure CLI, Claude, cargo) to the given rc file, once. Written as root
# then chowned back. The block is shell-agnostic: existence guards keep it inert
# for tools that aren't installed, and the Azure completion is gated on the
# running shell so bash never trips over zsh's `autoload`/`bashcompinit`.
write_tool_integrations() {
    local rc="$1"
    [[ -n "$rc" ]] || return 0
    touch "$rc"
    if ! grep -q '# --- Tool integrations ---' "$rc" 2>/dev/null; then
        cat >> "$rc" <<'TOOLEOF'

# --- Tool integrations ---
# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Bun
[ -d "$HOME/.bun" ] && export BUN_INSTALL="$HOME/.bun" && export PATH="$BUN_INSTALL/bin:$PATH"

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in *":$PNPM_HOME:"*) ;; *) export PATH="$PNPM_HOME:$PATH" ;; esac

# .NET
if [ -d "/usr/share/dotnet" ]; then
    export DOTNET_ROOT="/usr/share/dotnet"
    export PATH="$PATH:$DOTNET_ROOT"
fi
[ -d "$HOME/.dotnet/tools" ] && export PATH="$PATH:$HOME/.dotnet/tools"

# Azure CLI completions
if [ -f /etc/bash_completion.d/azure-cli ]; then
    if [ -n "$ZSH_VERSION" ]; then
        autoload -U +X bashcompinit && bashcompinit
    fi
    source /etc/bash_completion.d/azure-cli
fi

# Claude Code
[ -d "$HOME/.claude/bin" ] && export PATH="$PATH:$HOME/.claude/bin"

# Cargo / Rust
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
# --- end Tool integrations ---
TOOLEOF
    fi
    chown "$REAL_USER:$REAL_USER" "$rc" 2>/dev/null || true
}

# Wayland input-method flags for Chromium/Electron apps — without them fcitx5
# can't type into these apps under a Wayland session. `-hint=auto` picks Wayland
# when available and falls back to X11, so the flags are safe on either session.
WAYLAND_IME_FLAGS="--enable-features=UseOzonePlatform --ozone-platform-hint=auto --enable-wayland-ime --wayland-text-input-version=3"

# Inject the flags into every Exec= line of a .desktop file (right after the
# executable, before any %U/%F field codes). Idempotent: skips files that
# already carry them. Runs after an app installs so its launcher gets the flags.
enable_wayland_ime() {
    local desktop="$1"
    [[ -f "$desktop" ]] || return 0
    grep -q -- '--enable-wayland-ime' "$desktop" && return 0
    sed -i -E "s#^(Exec=[^ ]+)#\1 ${WAYLAND_IME_FLAGS}#" "$desktop"
}

# --- Install functions -------------------------------------------------------

do_mirror() {
    info "Switching APT mirror to ${MIRROR_HOST}..."

    local changed=0 f
    local targets=(
        /etc/apt/sources.list                                       # legacy
        /etc/apt/sources.list.d/ubuntu.sources                      # deb822 (24.04+)
    )

    for f in "${targets[@]}"; do
        if [[ -f "$f" ]] && grep -vE 'security\.ubuntu\.com' "$f" | grep -qE 'https?://[a-zA-Z0-9._-]+/ubuntu'; then
            cp -n "$f" "$f.bak"
            sed -i -E '/security\.ubuntu\.com/!s#https?://[a-zA-Z0-9._-]+/ubuntu#http://'"${MIRROR_HOST}"'/ubuntu#g' "$f"
            success "Updated $(basename "$f") (backup: ${f##*/}.bak)"
            changed=1
        fi
    done

    if [[ $changed -eq 0 ]]; then
        warn "No Ubuntu archive entries found — mirror left unchanged"
        return
    fi

    apt update
    success "APT mirror switched to ${MIRROR_HOST}"
}

do_update() {
    info "Updating system packages..."
    apt update && apt upgrade -y && apt autoremove -y
    success "System updated"
}

do_swap() {
    info "Configuring 8GB swap with swappiness 10..."

    if swapon --show | grep -q '/swapfile'; then
        local current_size
        current_size=$(stat -c%s /swapfile 2>/dev/null || echo 0)
        if [[ "$current_size" -eq $((8 * 1024 * 1024 * 1024)) ]]; then
            success "Swap 8GB already configured, skipping"
            return
        fi
        swapoff /swapfile 2>/dev/null || true
        rm -f /swapfile
    fi

    fallocate -l 8G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile

    if ! grep -q '/swapfile' /etc/fstab; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi

    sed -i '/^vm.swappiness/d' /etc/sysctl.conf
    echo 'vm.swappiness=10' >> /etc/sysctl.conf
    sysctl vm.swappiness=10

    success "Swap 8GB active, swappiness=10 (persistent)"
}

do_terminal() {
    info "Installing terminal utilities..."

    apt install -y zsh tmux htop jq ripgrep fzf git curl

    if ! command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
        apt install -y bat 2>/dev/null || apt install -y batcat 2>/dev/null || true
    fi
    if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
        ln -sf "$(which batcat)" /usr/local/bin/bat
    fi

    if ! command -v yq &>/dev/null; then
        info "Installing yq..."
        wget -q -O /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"
        chmod +x /usr/local/bin/yq
    fi

    info "Configuring Oh My Zsh + plugins for '$REAL_USER'..."
    local setup_script
    setup_script=$(mktemp /tmp/zsh-setup-XXXXXX.sh)
    cat > "$setup_script" << 'SETUP_EOF'
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    export RUNZSH=no CHSH=no
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" 2>/dev/null || true
git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" 2>/dev/null || true

# Minimal, sane defaults. zsh-syntax-highlighting MUST be last.
sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "$HOME/.zshrc"
SETUP_EOF
    chmod a+rx "$setup_script"
    su - "$REAL_USER" -c "bash $setup_script"
    rm -f "$setup_script"

    # PATH/env for the runtimes lives in the shared Tool-integrations block.
    write_tool_integrations "$REAL_HOME/.zshrc"

    local cur_shell
    cur_shell=$(getent passwd "$REAL_USER" | cut -d: -f7)
    if [[ "$cur_shell" == "$(which zsh)" ]]; then
        success "zsh is already the default shell for '$REAL_USER'"
    else
        local set_default="n"
        printf "  ${CYAN}?${NC} Set zsh as the default shell for '%s'? [y/N] " "$REAL_USER"
        read -r set_default </dev/tty || set_default="n"
        if [[ "$set_default" =~ ^[Yy]$ ]]; then
            chsh -s "$(which zsh)" "$REAL_USER"
            success "Default shell changed to zsh (re-login to apply)"
        else
            warn "Keeping current shell. zsh is installed — run 'zsh' anytime to use it"
        fi
    fi

    success "Terminal tools installed: zsh + oh-my-zsh (3 plugins), tmux, htop, jq, yq, rg, fzf, bat"
}

# Point gnome-terminal's default profile at the Nerd Font so icons render
# without a manual settings change. Runs as REAL_USER because gsettings needs
# that user's own dconf store and DBus session bus — not root's.
apply_terminal_font() {
    command -v gnome-terminal &>/dev/null || return 0
    command -v gsettings     &>/dev/null || return 0

    local font_script
    font_script=$(mktemp /tmp/term-font-XXXXXX.sh)
    cat > "$font_script" << 'FONT_EOF'
runtime_bus="/run/user/$(id -u)/bus"
[ -S "$runtime_bus" ] && export DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_bus"

profile=$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'")
[ -z "$profile" ] && exit 1
base="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$profile/"
gsettings set "$base" use-system-font false || exit 1
gsettings set "$base" font 'MesloLGS NF 12'  || exit 1
FONT_EOF
    chmod a+rx "$font_script"

    if su - "$REAL_USER" -c "bash $font_script" 2>/dev/null; then
        success "gnome-terminal font set to 'MesloLGS NF' (reopen the terminal to see icons)"
    else
        warn "Could not auto-set the terminal font — set it to 'MesloLGS NF' manually so icons render"
    fi
    rm -f "$font_script"
}

do_font() {
    info "Installing MesloLGS Nerd Font (icons for eza & terminal)..."

    # fontconfig provides fc-list / fc-cache — required for an accurate check.
    apt install -y fontconfig wget >/dev/null 2>&1 || apt install -y fontconfig wget

    if fc-list 2>/dev/null | grep -qi 'MesloLGS NF'; then
        success "MesloLGS Nerd Font already installed, skipping ($(fc-list 2>/dev/null | grep -ci 'MesloLGS NF') faces)"
        apply_terminal_font
        return
    fi

    local font_dir="/usr/local/share/fonts/MesloLGS-NF"
    mkdir -p "$font_dir"
    local base_url="https://github.com/romkatv/powerlevel10k-media/raw/master"
    local font ok=1
    for font in "MesloLGS NF Regular.ttf" "MesloLGS NF Bold.ttf" \
                "MesloLGS NF Italic.ttf" "MesloLGS NF Bold Italic.ttf"; do
        if ! wget -q -O "$font_dir/$font" "$base_url/${font// /%20}"; then
            warn "Failed to download: $font"
            ok=0
        fi
    done
    # Rebuild the WHOLE font cache, not just "$font_dir": caching a single
    # subdir can leave fontconfig's parent-dir cache stale so an immediate
    # fc-list misses the new faces. A full -f makes fc-list see them at once.
    fc-cache -f >/dev/null 2>&1 || true

    # The .ttf files on disk are the real source of truth for "installed".
    # fc-list is only confirmation, and its cache can lag a beat — so retry it
    # briefly, and if files are present treat that as success even if fc-list
    # hasn't caught up (icons will render once the cache settles).
    local faces=0 i
    for i in 1 2 3; do
        faces=$(fc-list 2>/dev/null | grep -ci 'MesloLGS NF')
        [[ $faces -gt 0 ]] && break
        fc-cache -f >/dev/null 2>&1 || true
    done
    local on_disk
    on_disk=$(find "$font_dir" -maxdepth 1 -iname 'MesloLGS NF*.ttf' 2>/dev/null | wc -l)

    if [[ $faces -gt 0 ]]; then
        success "MesloLGS Nerd Font installed & verified ($faces faces)"
        apply_terminal_font
    elif [[ $ok -eq 1 && $on_disk -gt 0 ]]; then
        success "MesloLGS Nerd Font installed ($on_disk files); fontconfig cache will refresh on next login"
        apply_terminal_font
    else
        [[ $ok -eq 0 ]] && fail "Some font files failed to download"
        fail "Nerd Font not detected after install — eza/terminal icons may not render"
        return 1
    fi
}

do_eza() {
    info "Installing eza..."

    if ! command -v eza &>/dev/null; then
        if apt install -y eza 2>/dev/null; then
            success "eza installed via apt"
        else
            apt install -y gpg
            mkdir -p /etc/apt/keyrings
            wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
                | gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
            chmod 644 /etc/apt/keyrings/gierens.gpg
            echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
                > /etc/apt/sources.list.d/gierens.list
            chmod 644 /etc/apt/sources.list.d/gierens.list
            apt update
            apt install -y eza
            success "eza installed via deb repo"
        fi
    else
        success "eza already installed, skipping"
    fi

    # Aliases go to whichever rc the user's shell reads (.zshrc with zsh, else
    # .bashrc) so they take effect even when the Terminal Kit / zsh isn't chosen.
    local rc; rc=$(resolve_shell_rc)
    touch "$rc"
    if ! grep -q '# --- eza aliases ---' "$rc" 2>/dev/null; then
        cat >> "$rc" <<'EZAEOF'

# --- eza aliases ---
alias ls='eza --icons --group-directories-first'
alias ll='eza -l --icons --group-directories-first --git'
alias la='eza -la --icons --group-directories-first --git'
alias lt='eza --tree --icons --level=2'
# --- end eza aliases ---
EZAEOF
    fi
    chown "$REAL_USER:$REAL_USER" "$rc" 2>/dev/null || true

    success "eza installed (ls/ll/la/lt aliases added to $(basename "$rc"))"
}

do_nvm() {
    if [[ -s "$REAL_HOME/.nvm/nvm.sh" ]]; then
        success "NVM already installed, skipping"
        return
    fi

    info "Installing NVM + Node.js 24 for user '$REAL_USER'..."
    apt install -y curl

    su - "$REAL_USER" -c '
        export NVM_DIR="$HOME/.nvm"
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
        . "$NVM_DIR/nvm.sh"
        nvm install 24
        nvm alias default 24
    '

    success "NVM + Node.js 24 installed for '$REAL_USER'"
}

do_bun() {
    if [[ -x "$REAL_HOME/.bun/bin/bun" ]]; then
        success "Bun already installed, skipping"
        return
    fi

    info "Installing Bun for user '$REAL_USER'..."
    # The installer downloads a zip and needs unzip; curl to fetch install.sh.
    apt install -y curl unzip

    # Official per-user installer (into ~/.bun). PATH is wired up by the
    # Bun block in the Tool-integrations section of .zshrc (added by do_terminal).
    su - "$REAL_USER" -c 'curl -fsSL https://bun.sh/install | bash'

    if [[ -x "$REAL_HOME/.bun/bin/bun" ]]; then
        success "Bun $("$REAL_HOME/.bun/bin/bun" --version 2>/dev/null || echo 'ready') installed for '$REAL_USER'"
    else
        fail "Bun install did not produce ~/.bun/bin/bun"
        return 1
    fi
}

do_pnpm() {
    if su - "$REAL_USER" -c 'command -v pnpm' &>/dev/null; then
        success "pnpm already installed, skipping"
        return
    fi

    info "Installing pnpm for user '$REAL_USER'..."
    apt install -y curl

    # Preferred path: corepack (bundled with Node ≥16.9) — it shims pnpm against
    # the user's nvm-managed Node. Falls back to pnpm's standalone installer when
    # Node/corepack isn't present.
    local ok=0
    if su - "$REAL_USER" -c '
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        command -v corepack >/dev/null 2>&1
    '; then
        su - "$REAL_USER" -c '
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
            corepack enable pnpm 2>/dev/null || corepack enable
            corepack prepare pnpm@latest --activate
        ' && ok=1
    fi

    if [[ $ok -eq 0 ]]; then
        warn "corepack unavailable (install Node.js first for the cleanest setup) — using the standalone pnpm installer"
        su - "$REAL_USER" -c 'curl -fsSL https://get.pnpm.io/install.sh | sh -' && ok=1
    fi

    if [[ $ok -eq 1 ]]; then
        success "pnpm installed for '$REAL_USER' (open a new shell to use it)"
    else
        fail "pnpm install failed"
        return 1
    fi
}

do_yarn() {
    if su - "$REAL_USER" -c 'command -v yarn' &>/dev/null; then
        success "Yarn already installed, skipping"
        return
    fi

    info "Installing Yarn for user '$REAL_USER'..."
    apt install -y curl

    # Preferred path: corepack (bundled with Node ≥16.9) — it shims yarn against
    # the user's nvm-managed Node. Falls back to `npm install -g yarn` when
    # corepack isn't present.
    local ok=0
    if su - "$REAL_USER" -c '
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        command -v corepack >/dev/null 2>&1
    '; then
        su - "$REAL_USER" -c '
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
            corepack enable yarn 2>/dev/null || corepack enable
            corepack prepare yarn@stable --activate
        ' && ok=1
    fi

    if [[ $ok -eq 0 ]]; then
        warn "corepack unavailable (install Node.js first for the cleanest setup) — falling back to npm"
        su - "$REAL_USER" -c '
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
            command -v npm >/dev/null 2>&1 && npm install -g yarn
        ' && ok=1
    fi

    if [[ $ok -eq 1 ]]; then
        success "Yarn installed for '$REAL_USER' (open a new shell to use it)"
    else
        fail "Yarn install failed (Node.js/npm required)"
        return 1
    fi
}

do_abp() {
    if ! su - "$REAL_USER" -c '
        export DOTNET_ROOT="/usr/share/dotnet"
        export PATH="$PATH:$DOTNET_ROOT:$HOME/.dotnet/tools"
        command -v dotnet >/dev/null 2>&1
    '; then
        warn "ABP CLI needs the .NET SDK — select .NET SDK too, then re-run"
        return 1
    fi

    # `abp` is provided by the Volo.Abp.Studio.Cli dotnet global tool (into
    # ~/.dotnet/tools, already on PATH via the Tool-integrations block).
    if su - "$REAL_USER" -c '
        export PATH="$PATH:$HOME/.dotnet/tools"
        command -v abp
    ' &>/dev/null; then
        success "ABP CLI already installed, skipping"
        return
    fi

    info "Installing ABP CLI (Volo.Abp.Studio.Cli) for user '$REAL_USER'..."
    if su - "$REAL_USER" -c '
        export DOTNET_ROOT="/usr/share/dotnet"
        export PATH="$PATH:$DOTNET_ROOT:$HOME/.dotnet/tools"
        dotnet tool install -g Volo.Abp.Studio.Cli
    '; then
        success "ABP CLI installed for '$REAL_USER' (open a new shell, then run: abp)"
    else
        fail "ABP CLI install failed"
        return 1
    fi
}

do_dotnet() {
    info "Installing .NET SDK (versions: ${DOTNET_VERSIONS[*]})..."
    ensure_microsoft_gpg

    local codename
    codename=$(get_ubuntu_codename)
    local ubuntu_ver
    ubuntu_ver=$(get_ubuntu_version)

    # Nếu repo prod đã được khai báo ở file khác (vd: microsoft-prod.list từ
    # gói packages-microsoft-prod.deb), không ghi thêm dotnet.list để tránh
    # xung đột "Conflicting values set for option Signed-By".
    if grep -rqsl "packages.microsoft.com/ubuntu/$ubuntu_ver/prod" \
        /etc/apt/sources.list.d/ --include='*.list' --exclude='dotnet.list'; then
        info "Microsoft prod repo already configured, skipping dotnet.list"
        rm -f /etc/apt/sources.list.d/dotnet.list
    else
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/ubuntu/$ubuntu_ver/prod $codename main" \
            > /etc/apt/sources.list.d/dotnet.list
    fi
    apt update

    local installed=()
    local failed_ver=()

    for ver in "${DOTNET_VERSIONS[@]}"; do
        local pkg="dotnet-sdk-${ver}.0"
        if dpkg -s "$pkg" &>/dev/null; then
            success "$pkg already installed, skipping"
            installed+=("$ver")
            continue
        fi
        info "Installing $pkg..."
        if apt install -y "$pkg" 2>/dev/null; then
            installed+=("$ver")
        else
            warn "$pkg not found in repo, trying install script..."
            local tmp
            tmp=$(mktemp /tmp/dotnet-install-XXXXXX.sh)
            wget -q -O "$tmp" "https://dot.net/v1/dotnet-install.sh"
            chmod +x "$tmp"
            if bash "$tmp" --channel "$ver.0" --install-dir /usr/share/dotnet; then
                installed+=("$ver")
            else
                failed_ver+=("$ver")
            fi
            rm -f "$tmp"
        fi
    done

    if [[ ! -L /usr/bin/dotnet && -f /usr/share/dotnet/dotnet ]]; then
        ln -sf /usr/share/dotnet/dotnet /usr/bin/dotnet
    fi

    if [[ ${#installed[@]} -gt 0 ]]; then
        success ".NET SDK installed: ${installed[*]}"
    fi
    if [[ ${#failed_ver[@]} -gt 0 ]]; then
        warn ".NET SDK failed: ${failed_ver[*]}"
    fi
}

do_chrome() {
    if command -v google-chrome-stable &>/dev/null; then
        success "Google Chrome already installed, skipping"
        return
    fi

    info "Installing Google Chrome..."
    local tmp
    tmp=$(mktemp /tmp/chrome-XXXXXX.deb)
    if ! download_deb "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" "$tmp"; then
        rm -f "$tmp"
        return 1
    fi
    apt install -y "$tmp"
    rm -f "$tmp"
    enable_wayland_ime /usr/share/applications/google-chrome.desktop
    success "Google Chrome installed"
}

do_edge() {
    if command -v microsoft-edge-stable &>/dev/null; then
        success "Microsoft Edge already installed, skipping"
        return
    fi

    info "Installing Microsoft Edge..."
    ensure_microsoft_gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/edge stable main" \
        > /etc/apt/sources.list.d/microsoft-edge.list
    apt update
    apt install -y microsoft-edge-stable
    enable_wayland_ime /usr/share/applications/microsoft-edge.desktop
    success "Microsoft Edge installed"
}

do_teams() {
    if dpkg -s teams-for-linux &>/dev/null; then
        success "Teams for Linux already installed, skipping"
        return
    fi

    info "Installing Teams for Linux..."
    apt install -y curl wget

    local download_url
    download_url=$(curl -fsSL "https://api.github.com/repos/IsmaelMartinez/teams-for-linux/releases/latest" \
        | grep -oP '"browser_download_url":\s*"\K[^"]*_amd64\.deb' | head -1)

    if [[ -z "$download_url" ]]; then
        fail "Could not find Teams for Linux download URL (GitHub API may be rate-limited, try again later)"
        return 1
    fi

    local tmp
    tmp=$(mktemp /tmp/teams-for-linux-XXXXXX.deb)
    if ! download_deb "$download_url" "$tmp"; then
        rm -f "$tmp"
        return 1
    fi
    apt install -y "$tmp"
    rm -f "$tmp"
    enable_wayland_ime /usr/share/applications/teams-for-linux.desktop
    success "Teams for Linux installed"
}

do_vscode() {
    if command -v code &>/dev/null; then
        success "VS Code already installed, skipping"
        return
    fi

    info "Installing Visual Studio Code..."
    ensure_microsoft_gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
        > /etc/apt/sources.list.d/vscode.list
    apt update
    apt install -y code
    enable_wayland_ime /usr/share/applications/code.desktop
    success "VS Code installed"
}

do_trae() {
    if command -v trae &>/dev/null; then
        success "Trae IDE already installed, skipping"
        return
    fi

    info "Installing Trae IDE..."
    local tmp
    tmp=$(mktemp /tmp/trae-XXXXXX.deb)
    if ! download_deb "https://lf-cdn.trae.ai/obj/trae-ai-us/pkg/Trae_latest_linux_x64.deb" "$tmp"; then
        rm -f "$tmp"
        return 1
    fi
    apt install -y "$tmp"
    rm -f "$tmp"
    enable_wayland_ime /usr/share/applications/trae.desktop
    success "Trae IDE installed"
}

do_terraform() {
    if command -v terraform &>/dev/null; then
        success "Terraform already installed, skipping"
        return
    fi

    info "Installing Terraform..."
    apt install -y gnupg software-properties-common curl

    local codename
    codename=$(get_ubuntu_codename)

    curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $codename main" \
        > /etc/apt/sources.list.d/hashicorp.list
    apt update
    apt install -y terraform

    success "Terraform $(terraform --version | head -1) installed"
}

do_azcli() {
    if command -v az &>/dev/null; then
        success "Azure CLI already installed, skipping"
        return
    fi

    info "Installing Azure CLI..."
    apt install -y ca-certificates curl apt-transport-https lsb-release gnupg
    ensure_microsoft_gpg

    local codename
    codename=$(get_ubuntu_codename)

    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $codename main" \
        > /etc/apt/sources.list.d/azure-cli.list
    apt update
    apt install -y azure-cli

    success "Azure CLI $(az version --output tsv 2>/dev/null | head -1) installed"
}

do_azcopy() {
    if command -v azcopy &>/dev/null; then
        success "AzCopy already installed, skipping"
        return
    fi

    info "Installing AzCopy..."
    apt install -y wget tar

    local tmp_dir
    tmp_dir=$(mktemp -d /tmp/azcopy-XXXXXX)
    # aka.ms link always redirects to the latest v10 linux tarball
    wget -q -O "$tmp_dir/azcopy.tar.gz" "https://aka.ms/downloadazcopy-v10-linux"
    # tarball nests the binary in azcopy_linux_amd64_x.y.z/ — flatten with --strip-components
    tar -xzf "$tmp_dir/azcopy.tar.gz" -C "$tmp_dir" --strip-components=1
    install -m 755 "$tmp_dir/azcopy" /usr/local/bin/azcopy
    rm -rf "$tmp_dir"

    success "AzCopy $(azcopy --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1 || echo 'ready') installed"
}

do_docker() {
    if command -v docker &>/dev/null; then
        success "Docker already installed, skipping"
        return
    fi

    info "Installing Docker + Docker Compose..."

    apt install -y ca-certificates curl gnupg

    install -m 0755 -d /etc/apt/keyrings
    local distro="ubuntu"

    local codename
    codename=$(get_ubuntu_codename)

    curl -fsSL "https://download.docker.com/linux/$distro/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Remove any conflicting deb822-style source / armored key left by a prior
    # install. apt refuses to read sources when the same repo is declared twice
    # with different Signed-By values (docker.gpg vs docker.asc).
    rm -f /etc/apt/sources.list.d/docker.sources /etc/apt/keyrings/docker.asc

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$distro $codename stable" \
        > /etc/apt/sources.list.d/docker.list

    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    usermod -aG docker "$REAL_USER"

    systemctl enable docker
    systemctl start docker

    success "Docker + Compose installed (user '$REAL_USER' added to docker group — re-login to apply)"
}

do_browserstack() {
    if [[ -x /usr/local/bin/BrowserStackLocal ]]; then
        success "BrowserStack Local already installed, skipping"
        return
    fi

    info "Installing BrowserStack Local..."
    apt install -y wget unzip

    local tmp
    tmp=$(mktemp /tmp/bstack-XXXXXX.zip)
    wget -q -O "$tmp" "https://local-downloads.browserstack.com/BrowserStackLocal-linux-x64.zip"
    # -o overwrite, -j junk paths (the zip holds a single bare binary).
    unzip -o -j "$tmp" BrowserStackLocal -d /usr/local/bin
    rm -f "$tmp"
    chmod +x /usr/local/bin/BrowserStackLocal

    success "BrowserStack Local installed (run 'BrowserStackLocal --key <ACCESS_KEY>')"
}

do_mysqlclient() {
    info "Installing MySQL Client..."
    apt install -y mysql-client
    success "MySQL Client installed (mysqldump $(mysqldump --version 2>/dev/null | grep -oP 'Distrib \K[^,]+' || echo 'ready'))"
}

do_pgclient() {
    info "Installing PostgreSQL Client..."
    apt install -y postgresql-client
    success "PostgreSQL Client installed (pg_dump $(pg_dump --version 2>/dev/null | grep -oP '\d+\.\d+' || echo 'ready'))"
}

do_dbeaver() {
    if command -v dbeaver &>/dev/null; then
        success "DBeaver already installed, skipping"
        return
    fi

    info "Installing DBeaver Community..."
    local tmp
    tmp=$(mktemp /tmp/dbeaver-XXXXXX.deb)
    if ! download_deb "https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb" "$tmp"; then
        rm -f "$tmp"
        return 1
    fi
    apt install -y "$tmp"
    rm -f "$tmp"
    success "DBeaver Community installed"
}

do_navicat() {
    if [[ -f /opt/navicat-premium-lite/navicat.AppImage ]]; then
        success "Navicat Premium Lite already installed, skipping"
        return
    fi

    info "Installing Navicat Premium Lite..."
    local tmp_dir
    tmp_dir=$(mktemp -d /tmp/navicat-XXXXXX)

    local appimage="$tmp_dir/navicat.AppImage"
    wget -q -O "$appimage" "https://download.navicat.com/download/navicat17-premium-lite-en-x86_64.AppImage"
    chmod +x "$appimage"

    local install_dir="/opt/navicat-premium-lite"
    mkdir -p "$install_dir"
    mv "$appimage" "$install_dir/navicat.AppImage"

    cat > /usr/share/applications/navicat-premium-lite.desktop <<DEOF
[Desktop Entry]
Name=Navicat Premium Lite
Exec=$install_dir/navicat.AppImage
Type=Application
Icon=navicat
Categories=Development;Database;
Comment=Database Management Tool
DEOF

    ln -sf "$install_dir/navicat.AppImage" /usr/local/bin/navicat

    rm -rf "$tmp_dir"
    success "Navicat Premium Lite installed (run 'navicat' or from app menu)"
}

do_fcitx5() {
    info "Installing Fcitx5 with Vietnamese input (engine: ${IME_ENGINE})..."

    # Base fcitx5 runtime + GTK/Qt frontends — shared across every engine.
    apt install -y fcitx5 fcitx5-config-qt \
        fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 fcitx5-frontend-qt5

    # Per-engine package, plus the IM addon name written into the fcitx5 profile.
    local im_name
    case "$IME_ENGINE" in
        bamboo)
            apt install -y fcitx5-bamboo
            im_name="bamboo"
            ;;
        lotus)
            # Lotus is a third-party fcitx5 addon distributed via its own signed
            # apt repo (not in Ubuntu's archive), keyed per release codename.
            install -m 0755 -d /etc/apt/keyrings
            if [[ ! -f /etc/apt/keyrings/fcitx5-lotus.gpg ]]; then
                wget -qO- https://fcitx5-lotus.pages.dev/pubkey.gpg \
                    | gpg --dearmor -o /etc/apt/keyrings/fcitx5-lotus.gpg
                chmod a+r /etc/apt/keyrings/fcitx5-lotus.gpg
            fi
            local lotus_codename
            lotus_codename=$(get_ubuntu_codename)
            echo "deb [signed-by=/etc/apt/keyrings/fcitx5-lotus.gpg] https://fcitx5-lotus.pages.dev/apt/${lotus_codename} ${lotus_codename} main" \
                > /etc/apt/sources.list.d/fcitx5-lotus.list
            apt update
            apt install -y fcitx5-lotus
            im_name="lotus"
            ;;
        *)
            apt install -y fcitx5-unikey
            im_name="unikey"
            ;;
    esac

    # ── IM environment variables ──────────────────────────────────────────
    # Ubuntu 24.04 dropped PAM's reading of ~/.pam_environment, and on Wayland
    # (GNOME default) ~/.xprofile is never sourced. /etc/environment is read by
    # pam_env for every login session — X11 *and* Wayland — so it's the one
    # reliable place for IM vars.
    local env_file="/etc/environment"
    sed -i -E '/^(GTK_IM_MODULE|QT_IM_MODULE|XMODIFIERS|SDL_IM_MODULE|GLFW_IM_MODULE)=/d' "$env_file"
    cat >> "$env_file" <<'ENVEOF'
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
GLFW_IM_MODULE=ibus
ENVEOF

    # ── Autostart on login (X11 + Wayland) ────────────────────────────────
    # The fcitx5 package ships a system autostart entry; we add a per-user one
    # explicitly so it starts regardless of session type / desktop.
    local autostart_dir="$REAL_HOME/.config/autostart"
    mkdir -p "$autostart_dir"
    cat > "$autostart_dir/fcitx5.desktop" <<'DEOF'
[Desktop Entry]
Type=Application
Name=Fcitx 5
Icon=fcitx
Exec=fcitx5
X-GNOME-Autostart-Phase=Applications
X-GNOME-Autostart-enabled=true
DEOF

    # ── Preselect Unikey ──────────────────────────────────────────────────
    local fcitx_conf_dir="$REAL_HOME/.config/fcitx5"
    local profile_file="$fcitx_conf_dir/profile"
    mkdir -p "$fcitx_conf_dir"
    cat > "$profile_file" <<PROFEOF
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=${im_name}

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=${im_name}
Layout=

[GroupOrder]
0=Default
PROFEOF
    chown -R "$REAL_USER:$REAL_USER" "$autostart_dir" "$fcitx_conf_dir"

    # Migrate away from the legacy locations an older script version may have
    # written, so stale settings don't fight the new ones.
    rm -f "$REAL_HOME/.pam_environment"
    if [[ -f "$REAL_HOME/.xprofile" ]]; then
        sed -i '/fcitx/d; /GTK_IM_MODULE/d; /QT_IM_MODULE/d; /XMODIFIERS/d' "$REAL_HOME/.xprofile"
        chown "$REAL_USER:$REAL_USER" "$REAL_HOME/.xprofile" 2>/dev/null || true
    fi

    success "Fcitx5 + ${im_name} installed & configured (log out and back in to activate)"
}

do_postman() {
    if [[ -x /opt/Postman/Postman ]]; then
        success "Postman already installed, skipping"
        return
    fi

    info "Installing Postman..."
    apt install -y wget

    local tmp
    tmp=$(mktemp /tmp/postman-XXXXXX.tar.gz)
    wget -q -O "$tmp" "https://dl.pstmn.io/download/latest/linux_64"
    rm -rf /opt/Postman
    tar -xzf "$tmp" -C /opt          # unpacks into /opt/Postman
    rm -f "$tmp"
    ln -sf /opt/Postman/Postman /usr/local/bin/postman

    cat > /usr/share/applications/postman.desktop <<'DEOF'
[Desktop Entry]
Type=Application
Name=Postman
GenericName=API Client
Comment=The API platform for building and testing
Exec=/opt/Postman/Postman %U
Icon=/opt/Postman/app/resources/app/assets/icon.png
Terminal=false
Categories=Development;
StartupWMClass=Postman
DEOF

    enable_wayland_ime /usr/share/applications/postman.desktop
    success "Postman installed (/opt/Postman)"
}

do_waydroid() {
    if command -v waydroid &>/dev/null; then
        success "Waydroid already installed, skipping"
        return
    fi

    info "Installing Waydroid..."
    apt install -y curl ca-certificates

    # Official Waydroid apt repo — the helper detects the release codename and
    # writes the source + key for us.
    curl -fsSL https://repo.waydro.id | bash

    apt install -y waydroid

    warn "Waydroid needs a Wayland session and the kernel 'binder' module. Run 'waydroid init' once, then launch it from your app menu."
    success "Waydroid installed"
}

do_vlc() {
    info "Installing VLC..."
    apt install -y vlc
    success "VLC installed"
}

do_obs() {
    if command -v obs &>/dev/null; then
        success "OBS Studio already installed, skipping"
        return
    fi
    info "Installing OBS Studio..."
    # Official OBS PPA — newest builds with PipeWire screen capture for Wayland.
    # `add-apt-repository -y` refreshes the apt cache itself, so no extra update.
    command -v add-apt-repository &>/dev/null || apt install -y software-properties-common
    add-apt-repository -y ppa:obsproject/obs-studio
    apt install -y obs-studio
    success "OBS Studio installed"
}

do_anydesk() {
    if command -v anydesk &>/dev/null; then
        success "AnyDesk already installed, skipping"
        return
    fi

    info "Installing AnyDesk..."
    apt install -y wget gpg ca-certificates apt-transport-https

    # Official AnyDesk apt repo. The repo is single-arch (amd64) and uses the
    # legacy `all main` suite regardless of Ubuntu codename.
    wget -qO- https://keys.anydesk.com/repos/DEB-GPG-KEY \
        | gpg --dearmor -o /usr/share/keyrings/anydesk.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/anydesk.gpg] http://deb.anydesk.com/ all main" \
        > /etc/apt/sources.list.d/anydesk.list
    apt update
    apt install -y anydesk
    success "AnyDesk installed"
}

do_teamviewer() {
    if command -v teamviewer &>/dev/null; then
        success "TeamViewer already installed, skipping"
        return
    fi

    info "Installing TeamViewer..."
    apt install -y wget

    local tmp
    tmp=$(mktemp /tmp/teamviewer-XXXXXX.deb)
    if ! download_deb "https://download.teamviewer.com/download/linux/teamviewer_amd64.deb" "$tmp"; then
        rm -f "$tmp"
        return 1
    fi
    apt install -y "$tmp"
    rm -f "$tmp"
    success "TeamViewer installed"
}

do_claude() {
    if su - "$REAL_USER" -c 'command -v claude' &>/dev/null; then
        success "Claude Code already installed, skipping"
        return
    fi

    info "Installing Claude Code..."
    su - "$REAL_USER" -c 'curl -fsSL https://claude.ai/install.sh | bash'
    success "Claude Code installed (run 'claude' to start)"
}

# --- Uninstall functions -----------------------------------------------------
# Each undo_<key> mirrors do_<key>: removes packages, the APT repo file + key,
# downloaded binaries and (best-effort) the config it wrote. System-state steps
# that cannot be reversed (update) are skipped with a warning.

undo_mirror() {
    info "Restoring original APT mirror from backups..."
    local restored=0 f
    local targets=(
        /etc/apt/sources.list
        /etc/apt/sources.list.d/ubuntu.sources
    )
    for f in "${targets[@]}"; do
        if [[ -f "$f.bak" ]]; then
            mv -f "$f.bak" "$f"
            success "Restored $(basename "$f")"
            restored=1
        fi
    done
    if [[ $restored -eq 1 ]]; then
        apt update || true
        success "Original APT mirror restored"
    else
        warn "No mirror backup (*.bak) found — nothing to restore"
    fi
}

undo_update() {
    warn "A system update/upgrade cannot be rolled back — skipping"
}

undo_swap() {
    info "Removing swap & resetting swappiness..."
    swapoff /swapfile 2>/dev/null || true
    rm -f /swapfile
    sed -i '\#/swapfile#d' /etc/fstab
    sed -i '/^vm.swappiness/d' /etc/sysctl.conf
    sysctl -w vm.swappiness=60 >/dev/null 2>&1 || true
    success "Swap removed, swappiness reset to default (60)"
}

undo_terminal() {
    info "Removing terminal tools..."

    # Revert the login shell to bash before removing zsh.
    local cur_shell
    cur_shell=$(getent passwd "$REAL_USER" | cut -d: -f7)
    if [[ "$cur_shell" == *zsh ]]; then
        chsh -s "$(command -v bash)" "$REAL_USER" 2>/dev/null || true
        success "Default shell reverted to bash (re-login to apply)"
    fi

    # git/curl are intentionally kept — too many other things depend on them.
    apt_purge zsh tmux htop jq ripgrep fzf bat batcat
    rm -f /usr/local/bin/yq /usr/local/bin/bat

    su - "$REAL_USER" -c 'rm -rf "$HOME/.oh-my-zsh"' 2>/dev/null || true
    strip_rc_block "Tool integrations"
    warn "Shell rc files left in place (Tool-integrations block removed)"
    success "Terminal tools removed (kept git & curl)"
}

# Revert gnome-terminal's default profile back to the system font, so it does
# not keep pointing at a font we are about to delete. Best-effort, as REAL_USER.
revert_terminal_font() {
    command -v gnome-terminal &>/dev/null || return 0
    command -v gsettings     &>/dev/null || return 0

    local font_script
    font_script=$(mktemp /tmp/term-font-XXXXXX.sh)
    cat > "$font_script" << 'FONT_EOF'
runtime_bus="/run/user/$(id -u)/bus"
[ -S "$runtime_bus" ] && export DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_bus"

profile=$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'")
[ -z "$profile" ] && exit 1
base="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$profile/"
# Only revert if we are the one who set it, to avoid clobbering a user choice.
[ "$(gsettings get "$base" font 2>/dev/null | tr -d "'")" = "MesloLGS NF 12" ] || exit 0
gsettings set "$base" use-system-font true
FONT_EOF
    chmod a+rx "$font_script"
    su - "$REAL_USER" -c "bash $font_script" 2>/dev/null || true
    rm -f "$font_script"
}

undo_font() {
    info "Removing MesloLGS Nerd Font..."
    revert_terminal_font
    rm -rf /usr/local/share/fonts/MesloLGS-NF
    fc-cache -f >/dev/null 2>&1 || true
    if fc-list 2>/dev/null | grep -qi 'MesloLGS NF'; then
        warn "MesloLGS NF still detected — it may be installed elsewhere (e.g. user fonts)"
    else
        success "MesloLGS Nerd Font removed"
    fi
}

undo_eza() {
    info "Removing eza..."
    apt_purge eza
    rm -f /etc/apt/sources.list.d/gierens.list /etc/apt/keyrings/gierens.gpg
    strip_rc_block "eza aliases"
    success "eza removed (repo, key & aliases cleaned)"
}

undo_nvm() {
    info "Removing NVM + Node.js..."
    su - "$REAL_USER" -c 'rm -rf "$HOME/.nvm"' 2>/dev/null || true
    success "NVM removed (PATH cleared on next login; .zshrc NVM lines live in the Tool-integrations block)"
}

undo_bun() {
    info "Removing Bun..."
    su - "$REAL_USER" -c 'rm -rf "$HOME/.bun"' 2>/dev/null || true
    # Strip the block the Bun installer appends to the user's rc files (our own
    # Bun line lives in the Tool-integrations block and is conditional/harmless).
    local rc
    for rc in "$REAL_HOME/.bashrc" "$REAL_HOME/.zshrc"; do
        [[ -f "$rc" ]] || continue
        sed -i '/^# bun$/,/\.bun\/bin/d' "$rc"
        chown "$REAL_USER:$REAL_USER" "$rc" 2>/dev/null || true
    done
    success "Bun removed (.bun dir & installer rc block cleaned)"
}

undo_pnpm() {
    info "Removing pnpm..."
    su - "$REAL_USER" -c '
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        command -v corepack >/dev/null 2>&1 && corepack disable pnpm
    ' 2>/dev/null || true
    su - "$REAL_USER" -c 'rm -rf "$HOME/.local/share/pnpm" "$HOME/.config/pnpm"' 2>/dev/null || true
    success "pnpm removed (corepack shim disabled, pnpm dirs cleaned)"
}

undo_yarn() {
    info "Removing Yarn..."
    su - "$REAL_USER" -c '
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        command -v corepack >/dev/null 2>&1 && corepack disable yarn
        command -v npm >/dev/null 2>&1 && npm uninstall -g yarn
    ' 2>/dev/null || true
    su - "$REAL_USER" -c 'rm -rf "$HOME/.yarn" "$HOME/.cache/yarn"' 2>/dev/null || true
    success "Yarn removed (corepack shim disabled, yarn dirs cleaned)"
}

undo_abp() {
    info "Removing ABP CLI..."
    su - "$REAL_USER" -c '
        export DOTNET_ROOT="/usr/share/dotnet"
        export PATH="$PATH:$DOTNET_ROOT:$HOME/.dotnet/tools"
        command -v dotnet >/dev/null 2>&1 && dotnet tool uninstall -g Volo.Abp.Studio.Cli
    ' 2>/dev/null || true
    success "ABP CLI removed"
}

undo_dotnet() {
    info "Removing .NET SDK..."
    local pkgs
    pkgs=$(dpkg-query -W -f='${Package}\n' 'dotnet-sdk-*' 'dotnet-runtime-*' 'dotnet-host*' 'aspnetcore-runtime-*' 2>/dev/null || true)
    if [[ -n "$pkgs" ]]; then
        # shellcheck disable=SC2086
        apt_purge $pkgs
    fi
    rm -f /etc/apt/sources.list.d/dotnet.list
    rm -rf /usr/share/dotnet
    [[ -L /usr/bin/dotnet ]] && rm -f /usr/bin/dotnet
    success ".NET SDK removed (packages, repo & symlink)"
}

undo_chrome() {
    info "Removing Google Chrome..."
    apt_purge google-chrome-stable
    rm -f /etc/apt/sources.list.d/google-chrome.list
    success "Google Chrome removed"
}

undo_edge() {
    info "Removing Microsoft Edge..."
    apt_purge microsoft-edge-stable
    rm -f /etc/apt/sources.list.d/microsoft-edge.list
    success "Microsoft Edge removed"
}

undo_teams() {
    info "Removing Teams for Linux..."
    apt_purge teams-for-linux
    success "Teams for Linux removed"
}

undo_vscode() {
    info "Removing VS Code..."
    apt_purge code
    rm -f /etc/apt/sources.list.d/vscode.list
    success "VS Code removed"
}

undo_trae() {
    info "Removing Trae IDE..."
    apt_purge trae
    success "Trae IDE removed"
}

undo_terraform() {
    info "Removing Terraform..."
    apt_purge terraform
    rm -f /etc/apt/sources.list.d/hashicorp.list /usr/share/keyrings/hashicorp.gpg
    success "Terraform removed (package, repo & key)"
}

undo_azcli() {
    info "Removing Azure CLI..."
    apt_purge azure-cli
    rm -f /etc/apt/sources.list.d/azure-cli.list
    success "Azure CLI removed"
}

undo_azcopy() {
    info "Removing AzCopy..."
    rm -f /usr/local/bin/azcopy
    success "AzCopy removed"
}

undo_docker() {
    info "Removing Docker + Docker Compose..."
    apt_purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
    rm -f /etc/apt/sources.list.d/docker.list /etc/apt/sources.list.d/docker.sources \
          /etc/apt/keyrings/docker.gpg /etc/apt/keyrings/docker.asc
    gpasswd -d "$REAL_USER" docker 2>/dev/null || true
    warn "/var/lib/docker (images, volumes, containers) left intact — remove manually if desired"
    success "Docker removed (packages, repo, key & group membership)"
}

undo_browserstack() {
    info "Removing BrowserStack Local..."
    rm -f /usr/local/bin/BrowserStackLocal
    success "BrowserStack Local removed"
}

undo_mysqlclient() {
    info "Removing MySQL Client..."
    apt_purge mysql-client
    success "MySQL Client removed"
}

undo_pgclient() {
    info "Removing PostgreSQL Client..."
    apt_purge postgresql-client
    success "PostgreSQL Client removed"
}

undo_dbeaver() {
    info "Removing DBeaver Community..."
    apt_purge dbeaver-ce
    success "DBeaver removed"
}

undo_navicat() {
    info "Removing Navicat Premium Lite..."
    rm -rf /opt/navicat-premium-lite
    rm -f /usr/share/applications/navicat-premium-lite.desktop
    rm -f /usr/local/bin/navicat
    success "Navicat Premium Lite removed"
}

undo_fcitx5() {
    info "Removing Fcitx5..."
    # Purge every engine we might have installed, whichever was selected.
    apt_purge fcitx5 fcitx5-unikey fcitx5-bamboo fcitx5-lotus fcitx5-config-qt \
        fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 fcitx5-frontend-qt5

    # Drop the third-party Lotus apt repo + key if they were added.
    rm -f /etc/apt/sources.list.d/fcitx5-lotus.list /etc/apt/keyrings/fcitx5-lotus.gpg

    # Strip the IM vars from /etc/environment (leave the rest untouched).
    sed -i -E '/^(GTK_IM_MODULE|QT_IM_MODULE|XMODIFIERS|SDL_IM_MODULE|GLFW_IM_MODULE)=/d' /etc/environment

    # Remove the config + autostart entry this script created.
    su - "$REAL_USER" -c 'rm -rf "$HOME/.config/fcitx5" "$HOME/.config/autostart/fcitx5.desktop"' 2>/dev/null || true

    # Clean up legacy locations from older script versions.
    rm -f "$REAL_HOME/.pam_environment"
    if [[ -f "$REAL_HOME/.xprofile" ]]; then
        sed -i '/fcitx/d; /GTK_IM_MODULE/d; /QT_IM_MODULE/d; /XMODIFIERS/d' "$REAL_HOME/.xprofile"
        chown "$REAL_USER:$REAL_USER" "$REAL_HOME/.xprofile" 2>/dev/null || true
    fi

    success "Fcitx5 removed (packages, env vars & config cleaned — re-login to apply)"
}

undo_postman() {
    info "Removing Postman..."
    rm -rf /opt/Postman
    rm -f /usr/local/bin/postman /usr/share/applications/postman.desktop
    success "Postman removed"
}

undo_waydroid() {
    info "Removing Waydroid..."
    su - "$REAL_USER" -c 'waydroid session stop' 2>/dev/null || true
    systemctl stop waydroid-container 2>/dev/null || true
    systemctl disable waydroid-container 2>/dev/null || true
    apt_purge waydroid
    rm -f /etc/apt/sources.list.d/waydroid.list /usr/share/keyrings/waydroid.gpg
    rm -rf /var/lib/waydroid
    su - "$REAL_USER" -c 'rm -rf "$HOME/.local/share/waydroid"' 2>/dev/null || true
    warn "Waydroid data removed; a reboot clears the leftover container/network state"
    success "Waydroid removed"
}

undo_vlc() {
    info "Removing VLC..."
    apt_purge vlc
    success "VLC removed"
}

undo_obs() {
    info "Removing OBS Studio..."
    apt_purge obs-studio
    # `--remove` handles the deb822 `.sources` file on 24.04; glob covers both formats.
    add-apt-repository -y --remove ppa:obsproject/obs-studio 2>/dev/null || true
    rm -f /etc/apt/sources.list.d/obsproject-ubuntu-obs-studio-*.list \
          /etc/apt/sources.list.d/obsproject-ubuntu-obs-studio-*.sources
    su - "$REAL_USER" -c 'rm -rf "$HOME/.config/obs-studio"' 2>/dev/null || true
    success "OBS Studio removed"
}

undo_anydesk() {
    info "Removing AnyDesk..."
    apt_purge anydesk
    rm -f /etc/apt/sources.list.d/anydesk.list /usr/share/keyrings/anydesk.gpg
    su - "$REAL_USER" -c 'rm -rf "$HOME/.anydesk"' 2>/dev/null || true
    success "AnyDesk removed"
}

undo_teamviewer() {
    info "Removing TeamViewer..."
    apt_purge teamviewer
    # The teamviewer .deb drops its own apt repo + key; clear both.
    rm -f /etc/apt/sources.list.d/teamviewer.list \
          /etc/apt/trusted.gpg.d/teamviewer*.asc
    su - "$REAL_USER" -c 'rm -rf "$HOME/.config/teamviewer"' 2>/dev/null || true
    success "TeamViewer removed"
}

undo_claude() {
    info "Removing Claude Code..."
    if su - "$REAL_USER" -c 'command -v claude' &>/dev/null; then
        su - "$REAL_USER" -c 'claude uninstall --yes' 2>/dev/null \
            || su - "$REAL_USER" -c 'claude uninstall' 2>/dev/null || true
    fi
    su - "$REAL_USER" -c 'rm -f "$HOME/.claude/bin/claude" "$HOME/.local/bin/claude"' 2>/dev/null || true
    warn "~/.claude config directory left intact — remove manually if desired"
    success "Claude Code removed"
}

# --- Main --------------------------------------------------------------------

usage() {
    cat <<EOF
SETUP — Post-install toolkit for Ubuntu 24.04

Usage:
  ./install-app.sh              Interactive install menu
  ./install-app.sh --all        Install every app
  ./install-app.sh --uninstall  Interactive uninstall menu
  ./install-app.sh --uninstall --all   Uninstall every app
  ./install-app.sh --ascii      Force ASCII-only glyphs (fonts missing symbols)
  ./install-app.sh -h | --help  Show this help

Tip: if the menu shows boxes/tofu instead of icons, your terminal font
lacks the glyphs. Set it to a Nerd Font (e.g. "MesloLGS NF"), or run with
--ascii (or MINT_ASCII=1) for a plain-text menu.
EOF
}

main() {
    # Parse flags (order-independent).
    local arg
    for arg in "$@"; do
        case "$arg" in
            --all)       ALL=1 ;;
            --uninstall) MODE="uninstall" ;;
            --ascii)     UI_ASCII=1 ;;
            -h|--help)   usage; exit 0 ;;
            *)           warn "Unknown option: $arg"; usage; exit 1 ;;
        esac
    done

    # Pick the glyph set (Unicode vs ASCII) before anything is drawn.
    setup_glyphs

    need_root "$@"

    # This toolkit targets Ubuntu 24.04 — warn (don't refuse) on anything else.
    local os_id os_ver
    os_id=$(. /etc/os-release && echo "${ID:-}")
    os_ver=$(. /etc/os-release && echo "${VERSION_ID:-}")
    if [[ "$os_id" != "ubuntu" || "$os_ver" != "24.04" ]]; then
        warn "This toolkit targets Ubuntu 24.04 — detected '${os_id:-unknown} ${os_ver:-?}'. It may still work, but nothing is guaranteed."
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

    local border; border=$(ui_rep 53 "$RB_H")
    echo ""
    echo -e "  ${DIM}${RB_TL}${border}${RB_TR}${NC}"
    printf "  ${DIM}${RB_V}${NC}  ${MINTB}${G_DIAMOND}${NC}  ${BOLD}${WHITE}%-48s${NC}${DIM}${RB_V}${NC}\n" "${ACTION_GERUND} ${STEP_TOTAL} packages..."
    echo -e "  ${DIM}${RB_BL}${border}${RB_BR}${NC}"

    local failed=()
    local succeeded=0
    local start_time=$SECONDS

    for entry in "${APPS[@]}"; do
        IFS='|' read -r key label _ <<< "$entry"
        # Drop the "::tagline" — only the name belongs in headers & error lines.
        local name="${label%%::*}"
        if [[ "${SELECTED[$key]}" == "1" ]]; then
            print_step_header "$name"
            if "${prefix}${key}"; then
                succeeded=$((succeeded + 1))
            else
                fail "$name — ${MODE} failed"
                failed+=("$name")
            fi
        fi
    done

    if [[ "$MODE" == "install" ]]; then
        # Wire runtime PATH/env into the shell rc even when the zsh Terminal Kit
        # was skipped, so bash — the default shell — still sees the tools.
        local _rt
        for _rt in nvm bun pnpm dotnet azcli claude; do
            if [[ "${SELECTED[$_rt]}" == "1" ]]; then
                write_tool_integrations "$(resolve_shell_rc)"
                break
            fi
        done
        # Electron apps read this hint to auto-select Wayland, which is what lets
        # fcitx5 type into them. Harmless on X11 (falls back automatically).
        local _el
        for _el in chrome edge teams vscode trae postman; do
            if [[ "${SELECTED[$_el]}" == "1" ]]; then
                grep -q '^ELECTRON_OZONE_PLATFORM_HINT=' /etc/environment 2>/dev/null \
                    || echo 'ELECTRON_OZONE_PLATFORM_HINT=auto' >> /etc/environment
                break
            fi
        done
    fi

    # Sweep up packages orphaned by an uninstall pass.
    if [[ "$MODE" == "uninstall" ]]; then
        apt-get autoremove -y >/dev/null 2>&1 || true
    fi

    local elapsed=$(( SECONDS - start_time ))
    local mins=$(( elapsed / 60 ))
    local secs=$(( elapsed % 60 ))

    border=$(ui_rep 53 "$RB_H")
    echo ""
    echo ""
    echo -e "  ${DIM}${RB_TL}${border}${RB_TR}${NC}"
    echo -e "  ${DIM}${RB_V}${NC}                                                     ${DIM}${RB_V}${NC}"
    if [[ ${#failed[@]} -eq 0 ]]; then
        echo -e "  ${DIM}${RB_V}${NC}   ${MINT}${G_OK}${NC}  ${BOLD}${WHITE}All done!${NC}                                      ${DIM}${RB_V}${NC}"
    else
        echo -e "  ${DIM}${RB_V}${NC}   ${YELLOW}${G_WARN}${NC}  ${BOLD}Completed with errors${NC}                           ${DIM}${RB_V}${NC}"
    fi
    echo -e "  ${DIM}${RB_V}${NC}                                                     ${DIM}${RB_V}${NC}"
    local stats="${succeeded} ${ACTION_PAST}"
    [[ ${#failed[@]} -gt 0 ]] && stats="${stats}  ${#failed[@]} failed"
    local time_str="${mins}m ${secs}s"
    printf "  ${DIM}${RB_V}${NC}   ${MINT}${G_ON}${NC} %-44s${DIM}${RB_V}${NC}\n" "$stats"
    printf "  ${DIM}${RB_V}${NC}   ${DIM}${G_CLOCK}  %-44s${NC}${DIM}${RB_V}${NC}\n" "$time_str"
    echo -e "  ${DIM}${RB_V}${NC}                                                     ${DIM}${RB_V}${NC}"
    echo -e "  ${DIM}${RB_BL}${border}${RB_BR}${NC}"

    if [[ ${#failed[@]} -gt 0 ]]; then
        echo ""
        echo -e "  ${RED}Failed:${NC}"
        for f in "${failed[@]}"; do
            echo -e "    ${RED}${G_ERR}${NC} ${DIM}$f${NC}"
        done
    fi

    echo ""
    echo -e "  ${YELLOW}${G_REFRESH}${NC}  ${DIM}Reboot or re-login to apply all changes${NC}"
    echo ""
}

# Only run main when executed directly — allows sourcing for tests.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
