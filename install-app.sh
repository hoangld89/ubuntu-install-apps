#!/usr/bin/env bash
# Re-exec under bash if launched with `sh`/dash — avoids bash array-syntax errors
# (e.g. `sh: Syntax error: "(" unexpected`). dash reads line-by-line, so this
# guard runs before any bash-only syntax further down is ever parsed.
if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi
set -euo pipefail

# ============================================================
# SETUP — Post-install toolkit for Ubuntu 26.04
# Interactive app selector for a fresh Ubuntu 26.04 (resolute) machine
#   ./install-app.sh              interactive install
#   ./install-app.sh --all        install everything
#   ./install-app.sh --uninstall  interactive uninstall
#   ./install-app.sh --uninstall --all
# ============================================================

RED='\033[0;31m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

# Leaf-green accent palette on neutral chrome
MINT='\033[38;5;113m'        # leaf green (≈ #87CF3E)
MINTB='\033[1;38;5;113m'     # bold leaf green
MINTD='\033[38;5;108m'       # muted sage green

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
ZSH_LOGIN_SHELL=1           # Terminal Kit makes zsh the login shell; --keep-shell sets 0
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
    "font|Fonts::Nerd Font glyphs + Vietnamese web fonts (Facebook/Chrome)|1"
    "msfonts|MS Fonts::Arial, Times New Roman, Calibri & ClearType fonts|1"
    "eza|eza::a modern ls with icons & git awareness|1"
    "fastfetch|Fastfetch::system info at a glance, neofetch reborn|1"

    # ── Languages & Runtime ──
    "nvm|Node.js LTS::managed by nvm, swap versions on the fly|1"
    "bun|Bun::all-in-one JS runtime & toolkit, blazing fast|1"
    "pnpm|pnpm::fast, disk-efficient package manager via corepack|1"
    "yarn|Yarn 4::the Berry JS package manager via corepack|1"
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
    "navicat|Navicat Lite 18::a sleek database workbench|1"

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

# APT mirror — default to BizFly Cloud (first entry). Press 'm' in the menu to
# pick another nearby mirror.
MIRROR_HOST="mirror.bizflycloud.vn"
MIRRORS=(
    "mirror.bizflycloud.vn|BizFly Cloud — VCCorp (1 Gbps)"
    "vn.archive.ubuntu.com|Ubuntu VN Official — XTDV CDN"
    "mirror.viettelcloud.vn|Viettel Cloud (1 Gbps, HTTP only)"
    "mirrors.gofiber.vn|GoFiber (1 Gbps)"
    "mirrors.tino.org|Tino Group — HCM"
    "mirror.clearsky.vn|ClearSky"
)

# Format: "groupkey|Title|csv,of,app,keys" — icons live in G_ICON.
APP_GROUPS=(
    "system|System & Shell|mirror,update,swap,terminal,font,msfonts,eza,fastfetch"
    "dev|Languages & IDEs|nvm,bun,pnpm,yarn,dotnet,abp,vscode,trae,claude"
    "devops|DevOps & Cloud|terraform,azcli,azcopy,docker,browserstack"
    "database|Databases|mysqlclient,pgclient,dbeaver,navicat"
    "desktop|Apps & Desktop|chrome,edge,teams,fcitx5,postman,waydroid,vlc,obs,anydesk,teamviewer"
)

declare -A GROUP_EXPANDED
for _g in "${APP_GROUPS[@]}"; do
    IFS='|' read -r _gk _ _ <<< "$_g"
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
        IFS='|' read -r gkey _ gapps <<< "$g"
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
        IFS='|' read -r gkey _ gapps <<< "$g"
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
                IFS='|' read -r gk gl ga <<< "$g"
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

# --- Helpers -----------------------------------------------------------------

STEP_CURRENT=0
STEP_TOTAL=0
STEP_TMP=""

RUN_DIR=/run/install-app            # per-run scratch: reboot reasons, step errors
STATE_DIR=/var/lib/install-app      # markers that must survive a reboot
LOG_DIR=/var/log/install-app
LOG_FILE=""
APT_RUN_CONF=/etc/apt/apt.conf.d/99install-app-run

export DEBIAN_FRONTEND=noninteractive

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
        exec sudo env "MINT_ASCII=${MINT_ASCII:-0}" bash "$0" "$@"
    fi
}

REAL_USER="${SUDO_USER:-${USER:-$(id -un)}}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6 || true)

get_ubuntu_codename() {
    ( . /etc/os-release && echo "${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}" )
}

get_ubuntu_version() {
    if command -v lsb_release &>/dev/null; then
        lsb_release -rs
    else
        ( . /etc/os-release && echo "${VERSION_ID:-}" )
    fi
}

# Every APPS key must sit in exactly one group and have both do_/undo_ functions, or the menu/dispatch breaks mid-run.
validate_registry() {
    local entry g key gapps apps
    local -A in_apps=() seen=()
    for entry in "${APPS[@]}"; do
        IFS='|' read -r key _ <<< "$entry"
        in_apps[$key]=1
    done
    for g in "${APP_GROUPS[@]}"; do
        IFS='|' read -r _ _ gapps <<< "$g"
        IFS=',' read -ra apps <<< "$gapps"
        for key in "${apps[@]}"; do
            [[ -n "${in_apps[$key]:-}" ]] || { echo "Registry error: group lists unknown app '$key'" >&2; exit 1; }
            seen[$key]=$(( ${seen[$key]:-0} + 1 ))
        done
    done
    for entry in "${APPS[@]}"; do
        IFS='|' read -r key _ <<< "$entry"
        [[ "${seen[$key]:-0}" == 1 ]] \
            || { echo "Registry error: app '$key' is in ${seen[$key]:-0} APP_GROUPS lists (expected 1)" >&2; exit 1; }
        declare -F "do_$key" >/dev/null && declare -F "undo_$key" >/dev/null \
            || { echo "Registry error: app '$key' needs both do_$key and undo_$key" >&2; exit 1; }
    done
}

pkg_installed() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'; }

pkg_up_to_date() {
    local policy installed candidate
    policy=$(apt-cache policy "$1" 2>/dev/null) || return 1
    installed=$(awk '/Installed:/ { print $2; exit }' <<< "$policy")
    candidate=$(awk '/Candidate:/ { print $2; exit }' <<< "$policy")
    [[ -n "$installed" && "$installed" != "(none)" && "$installed" == "$candidate" ]]
}

# grep must read all of fc-list: an early `grep -q` exit SIGPIPEs fc-list and pipefail turns a match into a failure.
has_font() { fc-list 2>/dev/null | grep -i -- "$1" >/dev/null; }

# Steps run in subshells, so reboot reasons go to a file the parent reads for the summary.
need_reboot() { mkdir -p "$RUN_DIR"; echo "$*" >> "$RUN_DIR/reboot-reasons"; }

# Scratch dir for the current step; each step is its own subshell, so the EXIT trap fires when the step ends.
step_tmpdir() {
    [[ -n "$STEP_TMP" ]] && return 0
    STEP_TMP=$(mktemp -d /tmp/install-app-XXXXXX)
    trap 'rm -rf -- "$STEP_TMP"' EXIT
}

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

# add_apt_repo <list-path> <key-url> <key-path> <dearmor:0|1> <repo-content>
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
# cleanly from every rc they landed in (.bashrc, plus .zshrc when zsh is installed).
# Runs as root but rewrites REAL_USER's files and restores ownership.
strip_rc_block() {
    local label="$1" rc
    shift
    local files=("$@")
    (( ${#files[@]} )) || files=("$REAL_HOME/.zshrc" "$REAL_HOME/.bashrc")
    # An unclosed start marker is printed back untouched instead of eating the rest of the file.
    for rc in "${files[@]}"; do
        filter_rc "$rc" '
            $0 == s && !open { open = 1; buf = $0 ORS; next }
            open { buf = buf $0 ORS; if ($0 == e) { open = 0; buf = "" }; next }
            { print }
            END { if (open) printf "%s", buf }' -v "s=# --- $label ---" -v "e=# --- end $label ---" || return 1
    done
}

filter_rc() {
    local rc="$1" prog="$2" tmp
    shift 2
    [[ -f "$rc" ]] || return 0
    tmp=$(mktemp)
    if ! awk "$@" "$prog" "$rc" > "$tmp"; then
        rm -f "$tmp"
        return 1
    fi
    if ! cmp -s "$tmp" "$rc"; then
        # One .bak per run, so several edits to the same rc still leave the pre-run copy.
        local marker="$RUN_DIR/bak${rc//\//_}"
        if [[ ! -e "$marker" ]]; then
            cp -p "$rc" "$rc.bak" || { rm -f "$tmp"; return 1; }
            mkdir -p "$RUN_DIR" && touch "$marker"
        fi
        cat "$tmp" > "$rc" || { cp -p "$rc.bak" "$rc"; rm -f "$tmp"; return 1; }
        chown "$REAL_USER:$REAL_USER" "$rc" "$rc.bak" 2>/dev/null || true
    fi
    rm -f "$tmp"
}

# Shell config goes to every installed shell, so the login-shell choice never decides whether tools are on PATH.
target_shell_rcs() {
    echo "$REAL_HOME/.bashrc"
    if command -v zsh &>/dev/null; then echo "$REAL_HOME/.zshrc"; fi
}

runtimes_present() {
    [[ -d "$REAL_HOME/.nvm" || -d "$REAL_HOME/.bun" || -x /usr/bin/dotnet || -d "$REAL_HOME/.dotnet/tools" \
        || -x /usr/bin/az || -e "$REAL_HOME/.local/bin/claude" || -d "$REAL_HOME/.local/share/pnpm" ]]
}

tool_integrations_block() {
    cat <<'TOOLEOF'
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
if [ -x /usr/bin/dotnet ]; then
    DOTNET_ROOT="$(dirname "$(readlink -f /usr/bin/dotnet)")"
    export DOTNET_ROOT
fi
[ -d "$HOME/.dotnet/tools" ] && export PATH="$PATH:$HOME/.dotnet/tools"

# Azure CLI completions
if [ -f /etc/bash_completion.d/azure-cli ]; then
    if [ -n "$ZSH_VERSION" ]; then
        autoload -U +X bashcompinit && bashcompinit
    fi
    source /etc/bash_completion.d/azure-cli
fi

# Claude Code (native installer symlinks the CLI into ~/.local/bin)
if [ -d "$HOME/.local/bin" ]; then
    case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
fi
# --- end Tool integrations ---
TOOLEOF
}

# Write the shared Tool-integrations block into $1, replacing an existing copy in place so script updates reach old machines.
write_tool_integrations() {
    local rc="$1" block
    [[ -n "$rc" ]] || return 0
    [[ -e "$rc" ]] || touch "$rc"
    block=$(mktemp) || return 1
    tool_integrations_block > "$block"
    if grep -qxF '# --- Tool integrations ---' "$rc" && grep -qxF '# --- end Tool integrations ---' "$rc"; then
        filter_rc "$rc" '
            $0 == s && !done { while ((getline line < f) > 0) print line; skip = 1; next }
            skip { if ($0 == e) { skip = 0; done = 1 }; next }
            { print }' -v "f=$block" -v "s=# --- Tool integrations ---" -v "e=# --- end Tool integrations ---" \
            || { rm -f "$block"; return 1; }
    else
        { echo ""; cat "$block"; } >> "$rc" || { rm -f "$block"; return 1; }
    fi
    rm -f "$block"
    chown "$REAL_USER:$REAL_USER" "$rc" 2>/dev/null || true
}

# Wayland input-method flags for Chromium/Electron apps — without them fcitx5
# can't type into these apps under a Wayland session. `-hint=auto` picks Wayland
# when available and falls back to X11, so the flags are safe on either session.
WAYLAND_IME_FLAGS="--enable-features=UseOzonePlatform --ozone-platform-hint=auto --enable-wayland-ime --wayland-text-input-version=3"

# Chromium/Electron launchers that get the flags. Both VS Code names are listed:
# newer `code` packages ship com.microsoft.VSCode.desktop instead of code.desktop.
WAYLAND_IME_LAUNCHERS=(
    /usr/share/applications/google-chrome.desktop
    /usr/share/applications/microsoft-edge.desktop
    /usr/share/applications/teams-for-linux.desktop
    /usr/share/applications/com.microsoft.VSCode.desktop
    /usr/share/applications/code.desktop
    /usr/share/applications/trae.desktop
    /usr/share/applications/postman.desktop
)
WAYLAND_IME_HOOK=/usr/local/sbin/wayland-ime-launchers
WAYLAND_IME_APT_CONF=/etc/apt/apt.conf.d/99wayland-ime-launchers

# Package upgrades rewrite their .desktop files and drop the flags, so instead of
# patching once we install a helper that dpkg re-runs after every apt operation.
# The helper is idempotent: the x11-strip is a no-op when absent, and the flag
# injection skips files that already carry them. Missing launchers are skipped.
enable_wayland_ime() {
    # Ubuntu 26.04 is Wayland-first. Some launchers (e.g. teams-for-linux) ship a
    # hard `--ozone-platform=x11` that conflicts with our `-hint=auto`: the
    # explicit flag wins and pins the app to X11, which breaks Wayland IME and —
    # on some GPUs — crashes the app (SIGILL/GPU-process). Strip it so the Ozone
    # platform resolves consistently through the hint.
    cat > "$WAYLAND_IME_HOOK" <<HOOKEOF
#!/bin/sh
# Generated by install-app.sh: re-applies Wayland IME flags after every dpkg run.
for f in ${WAYLAND_IME_LAUNCHERS[*]}; do
    [ -f "\$f" ] || continue
    if grep -q -- ' --ozone-platform=x11' "\$f"; then
        sed -i -E 's# --ozone-platform=x11\\b##g' "\$f"
    fi
    if ! grep -q -- '--enable-wayland-ime' "\$f"; then
        sed -i -E 's#^(Exec=(env( +[A-Za-z_][A-Za-z0-9_]*=[^ ]*)+ +)?[^ ]+)#\\1 ${WAYLAND_IME_FLAGS}#' "\$f"
    fi
done
HOOKEOF
    [[ -s "$WAYLAND_IME_HOOK" ]] || return 1
    chmod 755 "$WAYLAND_IME_HOOK" || return 1
    echo "DPkg::Post-Invoke { \"[ -x ${WAYLAND_IME_HOOK} ] && ${WAYLAND_IME_HOOK} || true\"; };" \
        > "$WAYLAND_IME_APT_CONF" || return 1
    "$WAYLAND_IME_HOOK" || true
}

# Drop the dpkg hook once the last app it patches has been uninstalled.
remove_wayland_ime_if_unused() {
    local f
    for f in "${WAYLAND_IME_LAUNCHERS[@]}"; do
        [[ -f "$f" ]] && return 0
    done
    rm -f "$WAYLAND_IME_HOOK" "$WAYLAND_IME_APT_CONF"
    if grep -q '^ELECTRON_OZONE_PLATFORM_HINT=' /etc/environment 2>/dev/null; then
        sed -i '/^ELECTRON_OZONE_PLATFORM_HINT=/d' /etc/environment
        need_reboot "/etc/environment changed (Electron Wayland hint removed)"
    fi
}

# --- Install functions -------------------------------------------------------

do_mirror() {
    info "Switching APT mirror to ${MIRROR_HOST}..."

    local found=0 f staged changed=()
    local targets=(
        /etc/apt/sources.list                                       # legacy
        /etc/apt/sources.list.d/ubuntu.sources                      # deb822 (24.04+)
    )

    step_tmpdir
    for f in "${targets[@]}"; do
        if [[ -f "$f" ]] && awk '!/security\.ubuntu\.com/ && /https?:\/\/[a-zA-Z0-9._-]+\/ubuntu/ { found = 1 } END { exit !found }' "$f"; then
            found=1
            staged="$STEP_TMP/${f##*/}"
            sed -E '/security\.ubuntu\.com/!s#https?://[a-zA-Z0-9._-]+/ubuntu#http://'"${MIRROR_HOST}"'/ubuntu#g' "$f" > "$staged"
            cmp -s "$staged" "$f" && continue
            [[ -e "$f.bak" ]] || cp -p "$f" "$f.bak"
            cp -p "$f" "$staged.prev"
            cat "$staged" > "$f"
            changed+=("$f")
            success "Updated $(basename "$f") (backup: ${f##*/}.bak)"
        fi
    done

    if [[ $found -eq 0 ]]; then
        warn "No Ubuntu archive entries found — mirror left unchanged"
        return
    fi
    if [[ ${#changed[@]} -eq 0 ]]; then
        success "APT already uses ${MIRROR_HOST}, skipping"
        return
    fi

    if ! apt-get update; then
        fail "apt-get update failed on ${MIRROR_HOST} — restoring the previous sources"
        for f in "${changed[@]}"; do
            cat "$STEP_TMP/${f##*/}.prev" > "$f"
        done
        apt-get update || true
        return 1
    fi
    success "APT mirror switched to ${MIRROR_HOST}"
}

do_update() {
    info "Updating system packages..."
    apt-get update \
        && apt-get -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold upgrade -y --with-new-pkgs \
        && apt-get autoremove -y \
        || return 1
    success "System updated"
}

# Ubuntu 26.04 has no /etc/sysctl.conf and systemd-sysctl only reads sysctl.d.
SWAPPINESS_CONF=/etc/sysctl.d/99-swappiness.conf

# The Ubuntu installer provisions /swap.img — reuse it rather than stacking a second swap file.
resolve_swapfile() {
    if grep -q '^/swap.img[[:space:]]' /etc/fstab 2>/dev/null; then echo /swap.img; else echo /swapfile; fi
}

remove_swapfile() {
    local f="$1"
    if swapon --show=NAME --noheadings | grep -qx "$f"; then
        swapoff "$f" || { fail "Cannot swapoff $f (not enough free RAM to page it back in?)"; return 1; }
    fi
    rm -f "$f"
    sed -i "\#^${f}[[:space:]]#d" /etc/fstab
}

do_swap() {
    info "Configuring 8GB swap with swappiness 10..."

    local swapfile size
    swapfile=$(resolve_swapfile)
    # Earlier runs stacked /swapfile on top of the installer's /swap.img.
    if [[ "$swapfile" == /swap.img ]] && { [[ -e /swapfile ]] || grep -q '^/swapfile[[:space:]]' /etc/fstab; }; then
        remove_swapfile /swapfile || return 1
        info "Removed extra /swapfile (reusing /swap.img)"
    fi

    size=$(stat -c%s "$swapfile" 2>/dev/null || echo 0)
    if [[ "$size" -ge $((8 * 1024 * 1024 * 1024)) ]]; then
        swapon --show=NAME --noheadings | grep -qx "$swapfile" || swapon "$swapfile" || return 1
        success "Swap 8GB already configured ($swapfile), skipping"
    else
        remove_swapfile "$swapfile" || return 1
        { fallocate -l 8G "$swapfile" && chmod 600 "$swapfile" && mkswap "$swapfile" >/dev/null && swapon "$swapfile"; } \
            || { fail "Failed to create $swapfile"; return 1; }
        success "Swap 8GB active ($swapfile)"
    fi
    grep -q "^${swapfile}[[:space:]]" /etc/fstab || echo "$swapfile none swap sw 0 0" >> /etc/fstab

    [[ -f /etc/sysctl.conf ]] && sed -i '/^vm.swappiness/d' /etc/sysctl.conf
    echo 'vm.swappiness=10' > "$SWAPPINESS_CONF"
    sysctl -q -w vm.swappiness=10 || return 1
    success "swappiness=10 (persistent via $SWAPPINESS_CONF)"
}

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

do_terminal() {
    info "Installing terminal utilities..."

    local p missing=()
    for p in zsh tmux htop jq ripgrep fzf git curl bat; do
        pkg_installed "$p" || missing+=("$p")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        apt-get install -y "${missing[@]}"
    fi
    if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
        ln -sf "$(command -v batcat)" /usr/local/bin/bat
    fi

    if ! command -v yq &>/dev/null; then
        info "Installing yq..."
        step_tmpdir
        if wget -q --tries=3 --timeout=30 -O "$STEP_TMP/yq" "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64" \
            && [[ -s "$STEP_TMP/yq" ]]; then
            install -m 755 "$STEP_TMP/yq" /usr/local/bin/yq
        else
            warn "Could not download yq, skipping"
        fi
    fi

    if [[ -d "$REAL_HOME/.oh-my-zsh" ]]; then
        success "Oh My Zsh already installed for '$REAL_USER'"
    else
        info "Installing Oh My Zsh for '$REAL_USER'..."
        # --unattended implies RUNZSH=no CHSH=no, which `su -` would otherwise strip from the environment.
        run_remote_script "$REAL_USER" sh https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh --unattended \
            || { fail "Oh My Zsh install failed"; return 1; }
    fi

    local plugin
    for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
        [[ -d "$REAL_HOME/.oh-my-zsh/custom/plugins/$plugin" ]] && continue
        su - "$REAL_USER" -c "git clone --depth 1 https://github.com/zsh-users/$plugin \"\$HOME/.oh-my-zsh/custom/plugins/$plugin\"" \
            || { fail "Could not clone $plugin"; return 1; }
    done
    ensure_zsh_plugins "$REAL_HOME/.zshrc" git zsh-autosuggestions zsh-syntax-highlighting

    # PATH/env for the runtimes lives in the shared Tool-integrations block.
    write_tool_integrations "$REAL_HOME/.zshrc"

    local cur_shell zsh_bin
    cur_shell=$(getent passwd "$REAL_USER" | cut -d: -f7)
    zsh_bin=$(command -v zsh)
    if [[ "$cur_shell" == "$zsh_bin" ]]; then
        success "zsh is already the default shell for '$REAL_USER'"
    elif [[ "$ZSH_LOGIN_SHELL" == 1 ]]; then
        chsh -s "$zsh_bin" "$REAL_USER"
        need_reboot "login shell changed to zsh"
        success "Default shell changed to zsh (re-login to apply)"
    else
        info "Keeping the current login shell (--keep-shell). zsh is installed — run 'zsh' anytime to use it"
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

# Vietnamese web fonts. Facebook (and most sites) fall back to whatever face the
# system offers for Vietnamese diacritics; without full-coverage fonts the
# combining marks render misplaced/overlapping or as tofu boxes. Noto gives
# correctly-composed Vietnamese coverage, its emoji face fixes broken emoji, and
# Liberation covers the Arial/Helvetica CSS stacks sites commonly request.
install_vn_web_fonts() {
    local pkgs=(fonts-noto-core fonts-noto-cjk fonts-noto-color-emoji fonts-liberation)
    local missing=() p
    for p in "${pkgs[@]}"; do
        dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q 'install ok installed' \
            || missing+=("$p")
    done
    if [[ ${#missing[@]} -eq 0 ]]; then
        success "Vietnamese web fonts already present (Noto + Liberation)"
        return
    fi
    info "Installing Vietnamese web fonts: ${missing[*]}"
    if apt-get install -y "${missing[@]}" >/dev/null 2>&1 || apt-get install -y "${missing[@]}"; then
        fc-cache -f >/dev/null 2>&1 || true
        success "Vietnamese web fonts installed — Facebook/browser diacritics fixed"
    else
        warn "Some Vietnamese web fonts failed to install (${missing[*]})"
    fi
}

# Microsoft fonts, from two separate sources:
#   * ttf-mscorefonts-installer (multiverse) — Arial, Times New Roman, Courier
#     New, Georgia, Verdana, Trebuchet MS, Comic Sans, Impact, Andale, Webdings.
#     The EULA must be pre-accepted via debconf so the install is non-interactive.
#   * Calibri, Cambria, Consolas, Candara, Constantia, Corbel — the ClearType
#     ("Vista") faces MS never shipped stand-alone. They live inside PowerPoint
#     Viewer 2007; we download it and pull the .ttf/.ttc out with cabextract
#     (the long-standing community method).
# Each part guards its own already-installed state, so this is safe to re-run.
do_msfonts() {
    # fontconfig provides fc-list / fc-cache — required for the accurate checks.
    apt-get install -y fontconfig >/dev/null 2>&1 || apt-get install -y fontconfig

    # --- Core fonts: Arial, Times New Roman, … (ttf-mscorefonts-installer) ---
    if has_font 'Times New Roman'; then
        success "MS core fonts already installed (Arial / Times New Roman / …)"
    else
        info "Installing MS core fonts (Arial, Times New Roman, Courier New, Georgia, Verdana…)..."
        # The package lives in the `multiverse` component — enable it if missing.
        if ! apt-cache policy ttf-mscorefonts-installer 2>/dev/null | grep -q 'Candidate: [0-9]'; then
            add-apt-repository -y multiverse >/dev/null 2>&1 || true
            apt-get update >/dev/null 2>&1 || true
        fi
        # Pre-accept the EULA so apt doesn't stop for the interactive prompt.
        echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true \
            | debconf-set-selections 2>/dev/null || true
        local reinstall=()
        if pkg_installed ttf-mscorefonts-installer; then
            # The package downloads the fonts in its postinst; a failed fetch leaves it installed with no fonts.
            info "ttf-mscorefonts-installer is installed but its fonts are missing — reinstalling..."
            reinstall=(--reinstall)
        fi
        if apt-get install -y "${reinstall[@]}" ttf-mscorefonts-installer >/dev/null 2>&1 \
           || apt-get install -y "${reinstall[@]}" ttf-mscorefonts-installer; then
            fc-cache -f >/dev/null 2>&1 || true
            success "MS core fonts installed (Arial, Times New Roman, Courier New, Georgia, Verdana, …)"
        else
            warn "MS core fonts (ttf-mscorefonts-installer) failed — check network / multiverse repo"
        fi
    fi

    # --- Calibri + ClearType faces, extracted from PowerPoint Viewer 2007 ---
    if has_font 'Calibri'; then
        success "Calibri & ClearType fonts already installed"
        return
    fi
    info "Installing Calibri + ClearType fonts (Cambria, Consolas, Candara, Constantia, Corbel)..."
    apt-get install -y cabextract wget >/dev/null 2>&1 || apt-get install -y cabextract wget
    local vista_dir="/usr/local/share/fonts/vista"
    step_tmpdir
    local tmp="$STEP_TMP"
    local ppv="$tmp/PowerPointViewer.exe"
    # SourceForge mirror of the original MS installer (Microsoft pulled its own).
    if wget -q -O "$ppv" "https://master.dl.sourceforge.net/project/mscorefonts2/cabs/PowerPointViewer.exe?viasf=1"; then
        mkdir -p "$vista_dir"
        # The .exe is a self-extractor; ppviewer.cab inside it holds the fonts.
        if cabextract -L -F ppviewer.cab -d "$tmp" "$ppv" >/dev/null 2>&1 \
           && cabextract -L -F '*.tt?' -d "$vista_dir" "$tmp/ppviewer.cab" >/dev/null 2>&1; then
            chmod 644 "$vista_dir"/*.tt? 2>/dev/null || true
            fc-cache -f >/dev/null 2>&1 || true
            if has_font 'Calibri'; then
                success "Calibri & ClearType fonts installed (Cambria, Consolas, Candara, Constantia, Corbel)"
            else
                success "Calibri fonts extracted to $vista_dir; fontconfig cache refreshes on next login"
            fi
        else
            warn "Could not extract Calibri fonts from PowerPoint Viewer (cabextract failed)"
        fi
    else
        warn "Could not download PowerPoint Viewer for Calibri fonts (check network)"
    fi
}

do_font() {
    info "Installing fonts (Nerd Font + Vietnamese web fonts)..."

    # fontconfig provides fc-list / fc-cache — required for an accurate check.
    apt-get install -y fontconfig wget >/dev/null 2>&1 || apt-get install -y fontconfig wget

    # Web fonts run regardless of Nerd Font state (Nerd Font has an early return).
    install_vn_web_fonts

    local font_dir="/usr/local/share/fonts/MesloLGS-NF" font missing=()
    local faces_all=("MesloLGS NF Regular.ttf" "MesloLGS NF Bold.ttf" "MesloLGS NF Italic.ttf" "MesloLGS NF Bold Italic.ttf")
    for font in "${faces_all[@]}"; do
        [[ -s "$font_dir/$font" ]] || missing+=("$font")
    done
    if [[ ${#missing[@]} -eq 0 ]]; then
        success "MesloLGS Nerd Font already installed, skipping (${#faces_all[@]} faces)"
        apply_terminal_font
        return
    fi

    mkdir -p "$font_dir"
    step_tmpdir
    local base_url="https://github.com/romkatv/powerlevel10k-media/raw/master"
    for font in "${missing[@]}"; do
        if wget -q -O "$STEP_TMP/face.ttf" "$base_url/${font// /%20}" && [[ -s "$STEP_TMP/face.ttf" ]]; then
            install -m 644 "$STEP_TMP/face.ttf" "$font_dir/$font"
        else
            fail "Failed to download: $font"
            return 1
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
        faces=$(fc-list 2>/dev/null | grep -ci 'MesloLGS NF' || true)
        [[ $faces -gt 0 ]] && break
        fc-cache -f >/dev/null 2>&1 || true
    done

    if [[ $faces -gt 0 ]]; then
        success "MesloLGS Nerd Font installed & verified ($faces faces)"
    else
        success "MesloLGS Nerd Font installed (${#faces_all[@]} files); fontconfig cache will refresh on next login"
    fi
    apply_terminal_font
}

do_eza() {
    info "Installing eza..."

    if command -v eza &>/dev/null; then
        success "eza already installed, skipping"
    else
        apt-get install -y eza
        success "eza installed via apt"
    fi

    local rc rcs=()
    mapfile -t rcs < <(target_shell_rcs)
    for rc in "${rcs[@]}"; do
        [[ -e "$rc" ]] || touch "$rc"
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
    done

    success "eza installed (ls/ll/la/lt aliases added to ${rcs[*]##*/})"
}

do_fastfetch() {
    if command -v fastfetch &>/dev/null; then
        success "Fastfetch already installed, skipping"
        return
    fi

    info "Installing Fastfetch..."
    apt-get install -y fastfetch
    success "Fastfetch installed via apt"
}

# nvm is not `set -e` safe, so su blocks source it first and switch -e on afterwards.
NVM_LOAD='export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"'

# Skip key is the current LTS major, so a patch release doesn't trigger a reinstall but the next LTS line does.
nvm_lts_installed() {
    su - "$REAL_USER" -c "$NVM_LOAD"'
        command -v nvm >/dev/null 2>&1 || exit 1
        lts=$(nvm version-remote --lts 2>/dev/null) || exit 1
        major=${lts#v}; major=${major%%.*}
        [ -n "$major" ] && [ "$(nvm version "$major")" != N/A ]
    ' &>/dev/null
}

# nvm's installer appends unmarked loader lines; the marked Tool-integrations block is the only wiring kept.
strip_nvm_installer_lines() {
    local rc
    for rc in "$REAL_HOME/.bashrc" "$REAL_HOME/.zshrc"; do
        [[ -f "$rc" ]] && grep -q '# This loads nvm' "$rc" || continue
        filter_rc "$rc" '
            $0 == s { inblock = 1 }
            $0 == e { inblock = 0 }
            !inblock && ($0 ~ /^export NVM_DIR=/ || $0 ~ /# This loads nvm/) { next }
            { print }' -v "s=# --- Tool integrations ---" -v "e=# --- end Tool integrations ---"
        grep -qxF '# --- Tool integrations ---' "$rc" || write_tool_integrations "$rc"
        success "Removed nvm installer lines from $(basename "$rc") (the Tool-integrations block loads nvm)"
    done
}

do_nvm() {
    strip_nvm_installer_lines
    if nvm_lts_installed; then
        success "Node.js LTS already installed via nvm, skipping"
        return
    fi

    info "Installing NVM + Node.js LTS for user '$REAL_USER'..."
    command -v curl &>/dev/null || apt-get install -y curl

    if [[ ! -s "$REAL_HOME/.nvm/nvm.sh" ]]; then
        local nvm_tag
        nvm_tag=$(curl -fsSL --connect-timeout 10 --max-time 20 https://api.github.com/repos/nvm-sh/nvm/releases/latest 2>/dev/null \
            | grep -oP '"tag_name":\s*"\Kv[0-9.]+' | head -1 || true)
        nvm_tag="${nvm_tag:-v0.40.8}"
        info "Using nvm $nvm_tag"
        run_remote_script "$REAL_USER" "env PROFILE=/dev/null bash" "https://raw.githubusercontent.com/nvm-sh/nvm/$nvm_tag/install.sh" \
            || { fail "nvm installer failed"; return 1; }
    fi

    su - "$REAL_USER" -c "$NVM_LOAD"'
        from=""
        case "$(nvm current)" in none|system) ;; *) from="--reinstall-packages-from=current" ;; esac
        nvm install --lts $from && nvm alias default "lts/*"
    ' || { fail "nvm install --lts failed"; return 1; }

    success "NVM + Node.js LTS installed for '$REAL_USER' (default: lts/*)"
}

do_bun() {
    if [[ -x "$REAL_HOME/.bun/bin/bun" ]]; then
        success "Bun already installed, skipping"
        return
    fi

    info "Installing Bun for user '$REAL_USER'..."
    # The installer downloads a zip and needs unzip; curl to fetch install.sh.
    apt-get install -y curl unzip

    # Official per-user installer (into ~/.bun). PATH is wired up by the
    # Bun block in the Tool-integrations section of .zshrc (added by do_terminal).
    run_remote_script "$REAL_USER" bash https://bun.sh/install

    if [[ -x "$REAL_HOME/.bun/bin/bun" ]]; then
        success "Bun $("$REAL_HOME/.bun/bin/bun" --version 2>/dev/null || echo 'ready') installed for '$REAL_USER'"
    else
        fail "Bun install did not produce ~/.bun/bin/bun"
        return 1
    fi
}

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

do_pnpm() {
    local ver
    if ver=$(corepack_pm_version pnpm); then
        success "pnpm $ver already installed via corepack, skipping"
        return
    fi
    corepack_install_pm pnpm pnpm@latest
}

do_yarn() {
    local ver
    if ver=$(corepack_pm_version yarn) && [[ "$ver" =~ ^([0-9]+)\. ]] && (( BASH_REMATCH[1] >= 4 )); then
        success "Yarn $ver already installed via corepack, skipping"
        return
    fi
    corepack_install_pm "Yarn 4" yarn@stable
}

DOTNET_ENV='export PATH="$PATH:$HOME/.dotnet/tools"; [ -x /usr/bin/dotnet ] && export DOTNET_ROOT="$(dirname "$(readlink -f /usr/bin/dotnet)")"'

do_abp() {
    if ! su - "$REAL_USER" -c "$DOTNET_ENV"'; command -v dotnet >/dev/null 2>&1'; then
        warn "ABP CLI needs the .NET SDK — select .NET SDK too, then re-run"
        return 1
    fi

    # `abp` is provided by the Volo.Abp.Studio.Cli dotnet global tool (into
    # ~/.dotnet/tools, already on PATH via the Tool-integrations block).
    if su - "$REAL_USER" -c "$DOTNET_ENV"'; command -v abp' &>/dev/null; then
        success "ABP CLI already installed, skipping"
        return
    fi

    info "Installing ABP CLI (Volo.Abp.Studio.Cli) for user '$REAL_USER'..."
    if su - "$REAL_USER" -c "$DOTNET_ENV"'
        set -e
        dotnet tool install -g Volo.Abp.Studio.Cli
    '; then
        success "ABP CLI installed for '$REAL_USER' (open a new shell, then run: abp)"
    else
        fail "ABP CLI install failed"
        return 1
    fi
}

DOTNET_PPA=ppa:dotnet/backports
DOTNET_PPA_MARKER="$STATE_DIR/dotnet-backports.added"

do_dotnet() {
    local ver missing=() installed=() failed=() need_ppa=0
    for ver in "${DOTNET_VERSIONS[@]}"; do
        if pkg_installed "dotnet-sdk-${ver}.0"; then installed+=("$ver"); else missing+=("$ver"); fi
    done
    if [[ ${#missing[@]} -eq 0 ]]; then
        success ".NET SDK ${installed[*]} already installed, skipping"
        return
    fi

    info "Installing .NET SDK (versions: ${missing[*]})..."
    # .NET 10 ships in the 26.04 archive; 8 and 9 only in the backports PPA. The old Microsoft repo list is dropped.
    rm -f /etc/apt/sources.list.d/dotnet.list
    for ver in "${missing[@]}"; do
        [[ "$ver" == 10 ]] || need_ppa=1
    done
    if [[ $need_ppa -eq 1 ]] && ! grep -rqs 'dotnet/backports' /etc/apt/sources.list.d/; then
        add_ppa "$DOTNET_PPA" || return 1
        mkdir -p "$STATE_DIR"
        touch "$DOTNET_PPA_MARKER"
    else
        apt-get update
    fi

    for ver in "${missing[@]}"; do
        if apt-get install -y "dotnet-sdk-${ver}.0"; then installed+=("$ver"); else failed+=("$ver"); fi
    done

    if [[ -d /usr/share/dotnet ]]; then
        warn "/usr/share/dotnet is left over from an older dotnet-install.sh run — .NET now lives in /usr/lib/dotnet"
    fi
    if [[ ${#installed[@]} -gt 0 ]]; then
        success ".NET SDK installed: ${installed[*]}"
    fi
    if [[ ${#failed[@]} -gt 0 ]]; then
        fail ".NET SDK failed: ${failed[*]}"
        return 1
    fi
}

do_chrome() {
    if command -v google-chrome-stable &>/dev/null; then
        success "Google Chrome already installed, skipping"
        return
    fi

    info "Installing Google Chrome..."
    step_tmpdir
    download_deb "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" "$STEP_TMP/chrome.deb" || return 1
    apt-get install -y "$STEP_TMP/chrome.deb"
    success "Google Chrome installed"
}

do_edge() {
    if command -v microsoft-edge-stable &>/dev/null; then
        success "Microsoft Edge already installed, skipping"
        return
    fi

    info "Installing Microsoft Edge..."
    ensure_microsoft_gpg || return 1
    add_apt_source /etc/apt/sources.list.d/microsoft-edge.list \
        "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/edge stable main" || return 1
    apt-get install -y microsoft-edge-stable
    success "Microsoft Edge installed"
}

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

# A user-level code.desktop (hand-made IME override) no longer shadows the
# package's launcher since it was renamed to com.microsoft.VSCode.desktop, so
# the menu shows two VS Code icons. The dpkg hook now covers the flags.
remove_stale_vscode_launcher() {
    local stale="$REAL_HOME/.local/share/applications/code.desktop"
    [[ -f /usr/share/applications/com.microsoft.VSCode.desktop && -f "$stale" ]] || return 0
    grep -q '^Exec=/usr/share/code/.*--enable-wayland-ime' "$stale" || return 0
    rm -f "$stale"
    success "Removed duplicate VS Code launcher (~/.local/share/applications/code.desktop)"
}

do_vscode() {
    remove_stale_vscode_launcher
    if command -v code &>/dev/null; then
        success "VS Code already installed, skipping"
        return
    fi

    info "Installing Visual Studio Code..."
    ensure_microsoft_gpg || return 1
    add_apt_source /etc/apt/sources.list.d/vscode.list \
        "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" || return 1
    apt-get install -y code
    success "VS Code installed"
}

TRAE_URL_FILE="$STATE_DIR/trae.url"

# The version fields of the API, the URL and the package disagree, so the download URL is the update key.
trae_latest_url() {
    curl -fsSL --retry 3 --connect-timeout 15 --max-time 30 https://api.trae.ai/icube/api/v1/native/version/trae/latest \
        | jq -r '.data.manifest.linux.download | (map(select(.region == "va")) + map(select(.region != "cn")))[0]["x64.deb"] // empty'
}

do_trae() {
    command -v jq &>/dev/null || apt-get install -y jq
    local url
    url=$(trae_latest_url || true)
    if [[ -z "$url" ]]; then
        fail "Could not resolve the Trae download URL from api.trae.ai"
        return 1
    fi
    if pkg_installed trae && [[ "$(cat "$TRAE_URL_FILE" 2>/dev/null)" == "$url" ]]; then
        success "Trae IDE already at the latest release, skipping"
        return
    fi

    info "Installing Trae IDE ($url)..."
    step_tmpdir
    download_deb "$url" "$STEP_TMP/trae.deb" || return 1
    apt-get install -y --allow-downgrades "$STEP_TMP/trae.deb"
    mkdir -p "$STATE_DIR"
    echo "$url" > "$TRAE_URL_FILE"
    success "Trae IDE installed"
}

do_terraform() {
    if command -v terraform &>/dev/null; then
        success "Terraform already installed, skipping"
        return
    fi

    info "Installing Terraform..."
    apt-get install -y gnupg curl

    local codename
    codename=$(get_ubuntu_codename)
    add_apt_repo /etc/apt/sources.list.d/hashicorp.list https://apt.releases.hashicorp.com/gpg /usr/share/keyrings/hashicorp.gpg 1 \
        "deb [arch=amd64 signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $codename main" || return 1
    apt-get install -y terraform

    success "Terraform $(terraform --version | head -1) installed"
}

azcli_codename() {
    local codename
    codename=$(get_ubuntu_codename)
    # Azure CLI has no repo for other codenames (apt update 404s and aborts the run), so fall back to noble.
    case "$codename" in
        jammy | noble | resolute) echo "$codename" ;;
        *) echo noble ;;
    esac
}

write_azcli_repo() {
    ensure_microsoft_gpg || return 1
    add_apt_source /etc/apt/sources.list.d/azure-cli.list \
        "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $1 main" || return 1
    apt-get install -y azure-cli
}

do_azcli() {
    local list=/etc/apt/sources.list.d/azure-cli.list codename
    codename=$(azcli_codename)

    if command -v az &>/dev/null; then
        # Older runs pinned the jammy repo on newer Ubuntu; move to the native build.
        if [[ -f "$list" ]] && ! grep -q "/azure-cli/ $codename main" "$list"; then
            info "Switching Azure CLI repo to '$codename'..."
            write_azcli_repo "$codename" || { fail "Azure CLI repo switch failed"; return 1; }
            success "Azure CLI moved to the '$codename' repo"
            return
        fi
        success "Azure CLI already installed, skipping"
        return
    fi

    info "Installing Azure CLI..."
    apt-get install -y ca-certificates curl lsb-release gnupg
    local host_codename
    host_codename=$(get_ubuntu_codename)
    [[ "$codename" == "$host_codename" ]] \
        || warn "Azure CLI repo does not support '$host_codename', using the 'noble' repo instead"
    write_azcli_repo "$codename" || return 1

    success "Azure CLI $(az version --output tsv 2>/dev/null | head -1) installed"
}

do_azcopy() {
    if command -v azcopy &>/dev/null; then
        success "AzCopy already installed, skipping"
        return
    fi

    info "Installing AzCopy..."
    apt-get install -y wget tar

    step_tmpdir
    # aka.ms link always redirects to the latest v10 linux tarball
    if ! wget -q -O "$STEP_TMP/azcopy.tar.gz" "https://aka.ms/downloadazcopy-v10-linux" || [[ ! -s "$STEP_TMP/azcopy.tar.gz" ]]; then
        fail "Could not download AzCopy"
        return 1
    fi
    # tarball nests the binary in azcopy_linux_amd64_x.y.z/ — flatten with --strip-components
    tar -xzf "$STEP_TMP/azcopy.tar.gz" -C "$STEP_TMP" --strip-components=1
    install -m 755 "$STEP_TMP/azcopy" /usr/local/bin/azcopy

    success "AzCopy $(azcopy --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1 || echo 'ready') installed"
}

do_docker() {
    if pkg_installed docker-ce; then
        success "Docker already installed, skipping"
        return
    fi

    info "Installing Docker + Docker Compose..."
    # Docker's install docs: distro packages with these names conflict with docker-ce.
    apt_purge docker.io docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc

    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings

    local codename
    codename=$(get_ubuntu_codename)

    # Remove any conflicting deb822-style source / armored key left by a prior
    # install. apt refuses to read sources when the same repo is declared twice
    # with different Signed-By values (docker.gpg vs docker.asc).
    rm -f /etc/apt/sources.list.d/docker.sources /etc/apt/keyrings/docker.asc

    add_apt_repo /etc/apt/sources.list.d/docker.list https://download.docker.com/linux/ubuntu/gpg /etc/apt/keyrings/docker.gpg 1 \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $codename stable" \
        || return 1
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    if ! id -nG "$REAL_USER" | grep -qw docker; then
        usermod -aG docker "$REAL_USER"
        need_reboot "'$REAL_USER' added to the docker group"
    fi
    systemctl enable --now docker

    success "Docker + Compose installed (user '$REAL_USER' is in the docker group)"
}

do_browserstack() {
    if [[ -x /usr/local/bin/BrowserStackLocal ]]; then
        success "BrowserStack Local already installed, skipping"
        return
    fi

    info "Installing BrowserStack Local..."
    apt-get install -y wget unzip

    step_tmpdir
    local zip="$STEP_TMP/bstack.zip"
    if ! wget -q -O "$zip" "https://local-downloads.browserstack.com/BrowserStackLocal-linux-x64.zip" || [[ ! -s "$zip" ]]; then
        fail "Could not download BrowserStack Local"
        return 1
    fi
    # -o overwrite, -j junk paths (the zip holds a single bare binary).
    unzip -o -j "$zip" BrowserStackLocal -d /usr/local/bin
    chmod +x /usr/local/bin/BrowserStackLocal

    success "BrowserStack Local installed (run 'BrowserStackLocal --key <ACCESS_KEY>')"
}

do_mysqlclient() {
    if pkg_installed mysql-client; then
        success "MySQL Client already installed, skipping"
        return
    fi
    info "Installing MySQL Client..."
    apt-get install -y mysql-client
    success "MySQL Client installed (mysqldump $(mysqldump --version 2>/dev/null | grep -oP 'Distrib \K[^,]+' || echo 'ready'))"
}

do_pgclient() {
    if pkg_installed postgresql-client; then
        success "PostgreSQL Client already installed, skipping"
        return
    fi
    info "Installing PostgreSQL Client..."
    apt-get install -y postgresql-client
    success "PostgreSQL Client installed (pg_dump $(pg_dump --version 2>/dev/null | grep -oP '\d+\.\d+' || echo 'ready'))"
}

DBEAVER_LIST=/etc/apt/sources.list.d/dbeaver.list
DBEAVER_KEY=/usr/share/keyrings/dbeaver.gpg.key

do_dbeaver() {
    if [[ -f "$DBEAVER_LIST" ]] && pkg_up_to_date dbeaver-ce; then
        success "DBeaver already installed (updates via apt), skipping"
        return
    fi

    if [[ ! -f "$DBEAVER_LIST" || ! -s "$DBEAVER_KEY" ]]; then
        add_apt_repo "$DBEAVER_LIST" https://dbeaver.io/debs/dbeaver.gpg.key "$DBEAVER_KEY" 1 \
            "deb [signed-by=$DBEAVER_KEY] https://dbeaver.io/debs/dbeaver-ce /" || return 1
    fi
    if pkg_installed dbeaver-ce; then
        info "Moving DBeaver Community onto its apt repo..."
    else
        info "Installing DBeaver Community..."
    fi
    apt-get install -y dbeaver-ce
    success "DBeaver Community installed (updates via apt)"
}

remove_navicat_user_entries() {
    rm -f "$REAL_HOME"/.local/share/applications/Navicat.Premium.*.desktop \
        "$REAL_HOME"/.local/share/icons/hicolor/256x256/apps/"Navicat Premium Lite "*.png
}

do_navicat() {
    local version=18
    local install_dir="/opt/navicat-premium-lite"
    local appimage="$install_dir/navicat.AppImage"

    # SQL Server needs the unversioned libodbc.so, shipped only by unixodbc-dev
    if ! dpkg -s unixodbc-dev >/dev/null 2>&1; then
        info "Installing unixODBC for Navicat SQL Server connections..."
        apt-get install -y unixodbc-dev >/dev/null 2>&1 || apt-get install -y unixodbc-dev
    fi

    if [[ "$(cat "$install_dir/VERSION" 2>/dev/null)" == "$version" ]]; then
        success "Navicat Premium Lite $version already installed, skipping"
        return
    fi

    if pgrep -f '\.mount_navica|navicat-premium-lite/navicat\.AppImage' >/dev/null; then
        warn "Navicat is running — close it and re-run to install Navicat Premium Lite $version"
        return
    fi

    info "Installing Navicat Premium Lite $version..."
    step_tmpdir
    local tmp_dir="$STEP_TMP"

    local download="$tmp_dir/navicat.AppImage"
    if ! wget -q -O "$download" "https://download.navicat.com/download/navicat${version}-premium-lite-en-x86_64.AppImage" \
        || [[ ! -s "$download" ]]; then
        fail "Could not download Navicat Premium Lite $version"
        return 1
    fi
    chmod +x "$download"

    if [[ -f "$appimage" ]]; then
        local config_dir="$REAL_HOME/.config/navicat"
        if [[ -d "$config_dir" ]]; then
            local backup
            backup="$config_dir.bak-$(date +%Y%m%d-%H%M%S)"
            cp -a "$config_dir" "$backup"
            chown -R "$REAL_USER": "$backup"
            info "Backed up Navicat settings to $backup"
        fi
        remove_navicat_user_entries
    fi

    mkdir -p "$install_dir"
    mv "$download" "$appimage"
    (cd "$tmp_dir" && "$appimage" --appimage-extract icon.png >/dev/null 2>&1 \
        && install -Dm 644 squashfs-root/icon.png /usr/share/icons/hicolor/256x256/apps/navicat-premium-lite.png) \
        || warn "Could not extract the Navicat icon"
    gtk-update-icon-cache -q /usr/share/icons/hicolor 2>/dev/null || true

    # Same basename as Navicat's self-registered entry so it shadows ours, not duplicates
    rm -f /usr/share/applications/navicat-premium-lite.desktop /usr/share/applications/Navicat.Premium.*.desktop
    # WM_CLASS is AppRun (Qt uses argv[0]), so StartupWMClass must match it
    cat > "/usr/share/applications/Navicat.Premium.$version.desktop" <<DEOF
[Desktop Entry]
Name=Navicat Premium Lite $version
Exec=$appimage
Type=Application
Icon=navicat-premium-lite
Categories=Development;Database;
Comment=Database Management Tool
StartupWMClass=AppRun
DEOF

    ln -sf "$appimage" /usr/local/bin/navicat
    echo "$version" > "$install_dir/VERSION"

    success "Navicat Premium Lite $version installed (run 'navicat' or from app menu)"
}

do_fcitx5() {
    # Per-engine package, plus the IM addon name written into the fcitx5 profile.
    local im_name="$IME_ENGINE" engine_pkg
    case "$IME_ENGINE" in
        bamboo|lotus) engine_pkg="fcitx5-$IME_ENGINE" ;;
        *)            im_name="unikey"; engine_pkg="fcitx5-unikey" ;;
    esac

    if pkg_installed fcitx5 && pkg_installed "$engine_pkg" \
        && grep -qx 'GTK_IM_MODULE=fcitx' /etc/environment \
        && grep -qx "Name=${im_name}" "$REAL_HOME/.config/fcitx5/profile" 2>/dev/null; then
        success "Fcitx5 + ${im_name} already installed & configured, skipping"
        return
    fi

    info "Installing Fcitx5 with Vietnamese input (engine: ${im_name})..."

    # Base fcitx5 runtime + GTK/Qt frontends — shared across every engine.
    apt-get install -y fcitx5 fcitx5-config-qt \
        fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 fcitx5-frontend-qt5

    if [[ "$im_name" == lotus ]]; then
        # Lotus is a third-party fcitx5 addon distributed via its own signed
        # apt repo (not in Ubuntu's archive), keyed per release codename.
        local lotus_list=/etc/apt/sources.list.d/fcitx5-lotus.list lotus_key=/etc/apt/keyrings/fcitx5-lotus.gpg lotus_codename
        lotus_codename=$(get_ubuntu_codename)
        if [[ ! -f "$lotus_list" || ! -s "$lotus_key" ]]; then
            add_apt_repo "$lotus_list" https://fcitx5-lotus.pages.dev/pubkey.gpg "$lotus_key" 1 \
                "deb [arch=amd64 signed-by=$lotus_key] https://fcitx5-lotus.pages.dev/apt/${lotus_codename} ${lotus_codename} main" \
                || return 1
        fi
    fi
    apt-get install -y "$engine_pkg"

    # ── IM environment variables ──────────────────────────────────────────
    # Ubuntu 24.04 dropped PAM's reading of ~/.pam_environment, and on Wayland
    # (GNOME default) ~/.xprofile is never sourced. /etc/environment is read by
    # pam_env for every login session — X11 *and* Wayland — so it's the one
    # reliable place for IM vars.
    local env_file="/etc/environment" env_before
    env_before=$(cksum < "$env_file")
    sed -i -E '/^(GTK_IM_MODULE|QT_IM_MODULE|XMODIFIERS|SDL_IM_MODULE|GLFW_IM_MODULE)=/d' "$env_file"
    cat >> "$env_file" <<'ENVEOF'
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
GLFW_IM_MODULE=ibus
ENVEOF
    [[ "$(cksum < "$env_file")" == "$env_before" ]] || need_reboot "/etc/environment changed (fcitx5 input-method variables)"

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
        # Older runs kept the tarball's owner (uid 1001, no such user here).
        if [[ -n "$(find /opt/Postman ! -user root -print -quit)" ]]; then
            chown -R root:root /opt/Postman
            success "Fixed /opt/Postman ownership (root:root)"
        fi
        success "Postman already installed, skipping"
        return
    fi

    info "Installing Postman..."
    apt-get install -y wget

    step_tmpdir
    local tarball="$STEP_TMP/postman.tar.gz"
    if ! wget -q -O "$tarball" "https://dl.pstmn.io/download/latest/linux_64" || [[ ! -s "$tarball" ]]; then
        fail "Could not download Postman"
        return 1
    fi
    rm -rf /opt/Postman
    tar --no-same-owner -xzf "$tarball" -C /opt          # unpacks into /opt/Postman
    chown -R root:root /opt/Postman
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

    success "Postman installed (/opt/Postman)"
}

do_waydroid() {
    if command -v waydroid &>/dev/null; then
        success "Waydroid already installed, skipping"
        return
    fi

    info "Installing Waydroid..."
    apt-get install -y curl ca-certificates

    local codename
    codename=$(get_ubuntu_codename)
    add_apt_repo /etc/apt/sources.list.d/waydroid.list https://repo.waydro.id/waydroid.gpg /usr/share/keyrings/waydroid.gpg 0 \
        "deb [signed-by=/usr/share/keyrings/waydroid.gpg] https://repo.waydro.id/ $codename main" || return 1

    apt-get install -y waydroid

    warn "Waydroid needs a Wayland session and the kernel 'binder' module. Run 'waydroid init' once, then launch it from your app menu."
    success "Waydroid installed"
}

do_vlc() {
    if pkg_installed vlc; then
        success "VLC already installed, skipping"
        return
    fi
    info "Installing VLC..."
    apt-get install -y vlc
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
    add_ppa ppa:obsproject/obs-studio || return 1
    apt-get install -y obs-studio
    success "OBS Studio installed"
}

do_anydesk() {
    if command -v anydesk &>/dev/null; then
        success "AnyDesk already installed, skipping"
        return
    fi

    info "Installing AnyDesk..."
    apt-get install -y gpg ca-certificates

    # Official AnyDesk apt repo. The repo is single-arch (amd64) and uses the
    # legacy `all main` suite regardless of Ubuntu codename.
    add_apt_repo /etc/apt/sources.list.d/anydesk.list https://keys.anydesk.com/repos/DEB-GPG-KEY /usr/share/keyrings/anydesk.gpg 1 \
        "deb [arch=amd64 signed-by=/usr/share/keyrings/anydesk.gpg] https://deb.anydesk.com/ all main" || return 1
    apt-get install -y anydesk
    success "AnyDesk installed"
}

do_teamviewer() {
    if command -v teamviewer &>/dev/null; then
        success "TeamViewer already installed, skipping"
        return
    fi

    info "Installing TeamViewer..."
    apt-get install -y wget

    step_tmpdir
    download_deb "https://download.teamviewer.com/download/linux/teamviewer_amd64.deb" "$STEP_TMP/teamviewer.deb" || return 1
    apt-get install -y "$STEP_TMP/teamviewer.deb"
    success "TeamViewer installed"
}

do_claude() {
    if [[ -x "$REAL_HOME/.local/bin/claude" ]]; then
        success "Claude Code already installed, skipping"
        return
    fi

    info "Installing Claude Code..."
    run_remote_script "$REAL_USER" bash https://claude.ai/install.sh || { fail "Claude Code installer failed"; return 1; }
    if [[ ! -x "$REAL_HOME/.local/bin/claude" ]]; then
        fail "Claude Code installer did not produce ~/.local/bin/claude"
        return 1
    fi
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
        apt-get update || true
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
    remove_swapfile /swapfile || return 1
    [[ -f /etc/sysctl.conf ]] && sed -i '/^vm.swappiness/d' /etc/sysctl.conf
    rm -f "$SWAPPINESS_CONF"
    sysctl -q -w vm.swappiness=60 || true
    if [[ "$(resolve_swapfile)" == /swap.img ]]; then
        success "Swappiness reset to default (60); kept the installer's /swap.img"
    else
        success "Swap removed, swappiness reset to default (60)"
    fi
}

undo_terminal() {
    info "Removing terminal tools..."

    # Revert the login shell to bash before removing zsh.
    local cur_shell
    cur_shell=$(getent passwd "$REAL_USER" | cut -d: -f7)
    if [[ "$cur_shell" == *zsh ]]; then
        chsh -s "$(command -v bash)" "$REAL_USER" 2>/dev/null || true
        need_reboot "login shell reverted to bash"
        success "Default shell reverted to bash (re-login to apply)"
    fi

    # git/curl are intentionally kept — too many other things depend on them.
    apt_purge zsh tmux htop jq ripgrep fzf bat
    rm -f /usr/local/bin/yq /usr/local/bin/bat

    su - "$REAL_USER" -c 'rm -rf "$HOME/.oh-my-zsh"' 2>/dev/null || true
    strip_rc_block "Tool integrations" "$REAL_HOME/.zshrc"
    if runtimes_present; then
        write_tool_integrations "$REAL_HOME/.bashrc"
        info "Tool-integrations block kept in .bashrc — other runtimes still use it"
    else
        strip_rc_block "Tool integrations" "$REAL_HOME/.bashrc"
    fi
    if [[ -f "$REAL_HOME/.zshrc.pre-oh-my-zsh" ]]; then
        mv -f "$REAL_HOME/.zshrc.pre-oh-my-zsh" "$REAL_HOME/.zshrc"
        success "Restored ~/.zshrc from .zshrc.pre-oh-my-zsh"
    fi
    warn "Shell rc files left in place (Tool-integrations block removed from .zshrc)"
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
    # Vietnamese web fonts (Noto/Liberation) are intentionally left in place:
    # the desktop and browsers depend on them, so purging risks breaking
    # system-wide text rendering. Remove manually if you really need to.
    info "Vietnamese web fonts (Noto/Liberation) left installed — shared with the desktop"
}

undo_msfonts() {
    # Purge the core-fonts package and delete the extracted Calibri/ClearType
    # faces. apt_purge never aborts the run on failure.
    info "Removing Microsoft fonts (Arial/Times New Roman/Calibri/…)..."
    apt_purge ttf-mscorefonts-installer
    rm -rf /usr/local/share/fonts/vista
    fc-cache -f >/dev/null 2>&1 || true
    success "Microsoft fonts removed (core fonts + Calibri/ClearType)"
}

undo_eza() {
    info "Removing eza..."
    apt_purge eza
    rm -f /etc/apt/sources.list.d/gierens.list /etc/apt/keyrings/gierens.gpg
    strip_rc_block "eza aliases"
    success "eza removed (repo, key & aliases cleaned)"
}

undo_fastfetch() {
    info "Removing Fastfetch..."
    apt_purge fastfetch
    success "Fastfetch removed"
}

undo_nvm() {
    info "Removing NVM + Node.js..."
    su - "$REAL_USER" -c 'rm -rf "$HOME/.nvm"' 2>/dev/null || true
    success "NVM removed (PATH cleared on next login; .zshrc NVM lines live in the Tool-integrations block)"
}

undo_bun() {
    info "Removing Bun..."
    su - "$REAL_USER" -c 'rm -rf "$HOME/.bun"' 2>/dev/null || true
    # Strip exactly the lines the Bun installer appends; our own Bun line lives in the Tool-integrations block.
    local rc
    for rc in "$REAL_HOME/.bashrc" "$REAL_HOME/.zshrc"; do
        filter_rc "$rc" '
            $0 == ts { intool = 1 }
            $0 == te { intool = 0 }
            intool { print; next }
            $0 == "# bun" { inbun = 1; next }
            inbun && ($0 ~ /^export BUN_INSTALL=/ || $0 == "export PATH=\"$BUN_INSTALL/bin:$PATH\"") { next }
            { inbun = 0 }
            $0 == "# bun completions" { incomp = 1; next }
            incomp && /\.bun\/_bun/ { incomp = 0; next }
            { incomp = 0; print }' -v "ts=# --- Tool integrations ---" -v "te=# --- end Tool integrations ---"
    done
    success "Bun removed (.bun dir & installer rc block cleaned)"
}

undo_pnpm() {
    info "Removing pnpm..."
    su - "$REAL_USER" -c "$NVM_LOAD"'
        command -v corepack >/dev/null 2>&1 && corepack disable pnpm
    ' 2>/dev/null || true
    su - "$REAL_USER" -c 'rm -rf "$HOME/.local/share/pnpm" "$HOME/.config/pnpm"' 2>/dev/null || true
    # Older runs used get.pnpm.io, which appends a `# pnpm` … `# pnpm end` block (our block has a `# pnpm` line too).
    local rc
    for rc in "$REAL_HOME/.bashrc" "$REAL_HOME/.zshrc"; do
        filter_rc "$rc" '
            $0 == ts { intool = 1 }
            $0 == te { intool = 0 }
            !intool && !open && $0 == "# pnpm" { open = 1; buf = $0 ORS; next }
            open { buf = buf $0 ORS; if ($0 == "# pnpm end") { open = 0; buf = "" }; next }
            { print }
            END { if (open) printf "%s", buf }' -v "ts=# --- Tool integrations ---" -v "te=# --- end Tool integrations ---"
    done
    success "pnpm removed (corepack shim disabled, pnpm dirs & get.pnpm.io rc block cleaned)"
}

undo_yarn() {
    info "Removing Yarn..."
    su - "$REAL_USER" -c "$NVM_LOAD"'
        command -v corepack >/dev/null 2>&1 && corepack disable yarn
        command -v npm >/dev/null 2>&1 && npm uninstall -g yarn
    ' 2>/dev/null || true
    su - "$REAL_USER" -c 'rm -rf "$HOME/.yarn" "$HOME/.cache/yarn"' 2>/dev/null || true
    success "Yarn removed (corepack shim disabled, yarn dirs cleaned)"
}

undo_abp() {
    info "Removing ABP CLI..."
    su - "$REAL_USER" -c "$DOTNET_ENV"'
        command -v dotnet >/dev/null 2>&1 && dotnet tool uninstall -g Volo.Abp.Studio.Cli
    ' 2>/dev/null || true
    success "ABP CLI removed"
}

undo_dotnet() {
    info "Removing .NET SDK..."
    local pkgs
    pkgs=$(dpkg-query -W -f='${Package}\n' 'dotnet-sdk-*' 'dotnet-runtime-*' 'dotnet-host*' 'dotnet-apphost-pack-*' \
        'dotnet-targeting-pack-*' 'dotnet-templates-*' 'aspnetcore-runtime-*' 'aspnetcore-targeting-pack-*' \
        'netstandard-targeting-pack-*' 2>/dev/null || true)
    if [[ -n "$pkgs" ]]; then
        # shellcheck disable=SC2086
        apt_purge $pkgs
    fi
    rm -f /etc/apt/sources.list.d/dotnet.list
    if [[ -f "$DOTNET_PPA_MARKER" ]]; then
        add-apt-repository -y --remove "$DOTNET_PPA" >/dev/null 2>&1 || true
        rm -f "$DOTNET_PPA_MARKER"
        success "Removed $DOTNET_PPA"
    fi
    rm -rf /usr/share/dotnet
    if [[ -L /usr/bin/dotnet && ! -e /usr/bin/dotnet ]]; then
        rm -f /usr/bin/dotnet
    fi
    success ".NET SDK removed (packages, PPA & leftovers)"
}

undo_chrome() {
    info "Removing Google Chrome..."
    apt_purge google-chrome-stable
    # The package's cron job rewrites its repo as deb822 .sources with its own keyring.
    rm -f /etc/apt/sources.list.d/google-chrome.{list,sources} /usr/share/keyrings/google-chrome.gpg
    success "Google Chrome removed"
}

undo_edge() {
    info "Removing Microsoft Edge..."
    apt_purge microsoft-edge-stable
    rm -f /etc/apt/sources.list.d/microsoft-edge.{list,sources} /usr/share/keyrings/microsoft-edge.gpg
    success "Microsoft Edge removed"
}

undo_teams() {
    info "Removing Teams for Linux..."
    apt_purge teams-for-linux
    rm -f "$TEAMS_REPO" "$TEAMS_KEY"
    success "Teams for Linux removed"
}

undo_vscode() {
    info "Removing VS Code..."
    apt_purge code
    rm -f /etc/apt/sources.list.d/vscode.{list,sources}
    success "VS Code removed"
}

undo_trae() {
    info "Removing Trae IDE..."
    apt_purge trae
    rm -f "$TRAE_URL_FILE"
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
    warn "/var/lib/docker, /var/lib/containerd and /etc/docker (images, volumes, config) left intact — remove manually if desired"
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
    rm -f "$DBEAVER_LIST" "$DBEAVER_KEY"
    success "DBeaver removed (package, repo & key)"
}

undo_navicat() {
    info "Removing Navicat Premium Lite..."
    rm -rf /opt/navicat-premium-lite
    rm -f /usr/share/applications/navicat-premium-lite.desktop /usr/share/applications/Navicat.Premium.*.desktop
    rm -f /usr/local/bin/navicat /usr/share/icons/hicolor/256x256/apps/navicat-premium-lite.png
    gtk-update-icon-cache -q /usr/share/icons/hicolor 2>/dev/null || true
    remove_navicat_user_entries
    info "unixodbc-dev stays installed — other ODBC tools may use it (apt purge unixodbc-dev to drop it)"
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
    grep -qE '^(GTK_IM_MODULE|QT_IM_MODULE|XMODIFIERS)=' /etc/environment && need_reboot "/etc/environment changed (fcitx5 variables removed)"
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
          /usr/share/keyrings/teamviewer-keyring.gpg
    su - "$REAL_USER" -c 'rm -rf "$HOME/.config/teamviewer"' 2>/dev/null || true
    success "TeamViewer removed"
}

undo_claude() {
    info "Removing Claude Code..."
    rm -f "$REAL_HOME/.local/bin/claude"
    rm -rf "$REAL_HOME/.local/share/claude"
    warn "$REAL_HOME/.claude config directory left intact — remove manually if desired"
    success "Claude Code removed (~/.local/bin/claude & ~/.local/share/claude)"
}

# --- Main --------------------------------------------------------------------

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
        IFS='|' read -r key label _ <<< "$entry"
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

# Only run main when executed directly — allows sourcing for tests.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
