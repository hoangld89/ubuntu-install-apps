# shellcheck shell=bash

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
}

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
        exec sudo env "MINT_ASCII=${MINT_ASCII:-0}" bash "$SCRIPT_DIR/install-app.sh" "$@"
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
