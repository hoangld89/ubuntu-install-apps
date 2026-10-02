# shellcheck shell=bash

TOOLKIT_VERSION="1.1.0"

# Catppuccin Mocha; each colour carries its nearest xterm-256 index for terminals without truecolor.
TRUECOLOR=0
case "${COLORTERM:-}" in truecolor|24bit) TRUECOLOR=1 ;; esac

rgb_esc() {  # $1 38=fg|48=bg, $2 hex, $3 xterm-256 index
    local hex=$2
    if (( TRUECOLOR )); then
        printf '\033[%s;2;%d;%d;%dm' "$1" "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
    else
        printf '\033[%s;5;%sm' "$1" "$3"
    fi
}

C_MAUVE=$(rgb_esc 38 cba6f7 183)
C_LAVENDER=$(rgb_esc 38 b4befe 147)
C_BLUE=$(rgb_esc 38 89b4fa 111)
C_SAPPHIRE=$(rgb_esc 38 74c7ec 117)
C_GREEN=$(rgb_esc 38 a6e3a1 151)
C_YELLOW=$(rgb_esc 38 f9e2af 223)
C_RED=$(rgb_esc 38 f38ba8 211)
C_TEXT=$(rgb_esc 38 cdd6f4 189)
C_SUBTEXT=$(rgb_esc 38 a6adc8 146)
C_OVERLAY=$(rgb_esc 38 6c7086 60)
C_SURFACE2=$(rgb_esc 38 585b70 240)
C_BASE=$(rgb_esc 38 1e1e2e 234)
BG_SURFACE=$(rgb_esc 48 313244 236)
BG_MAUVE=$(rgb_esc 48 cba6f7 183)
BG_RED=$(rgb_esc 48 f38ba8 211)
BOLD=$'\033[1m'
NOBOLD=$'\033[22m'
FG0=$'\033[39m'
BG0=$'\033[49m'
NC=$'\033[0m'

# Step output only reaches the log, so steps drop every escape sequence.
ui_plain() {
    C_MAUVE=""; C_LAVENDER=""; C_BLUE=""; C_SAPPHIRE=""; C_GREEN=""; C_YELLOW=""
    C_RED=""; C_TEXT=""; C_SUBTEXT=""; C_OVERLAY=""; C_SURFACE2=""; C_BASE=""
    BG_SURFACE=""; BG_MAUVE=""; BG_RED=""; BOLD=""; NOBOLD=""; FG0=""; BG0=""; NC=""
}

# Fonts without these glyphs render tofu boxes; setup_glyphs swaps them for 7-bit ones in ASCII mode.
UI_ASCII=0

G_ON="●"; G_OFF="○"
G_EXPAND="▸"; G_COLLAPSE="▾"; G_BAR="▌"

G_PROG_F="━"; G_PROG_E="─"; G_DOT="·"; G_ELLIPSIS="…"
G_MINI_F="█"; G_MINI_E="░"; G_UP="↑"; G_DOWN="↓"

G_INFO="▸"; G_OK="✓"; G_WARN="!"; G_ERR="✗"
G_DIAMOND="◆"; G_REFRESH="⟳"; G_PIPE="│"
G_SPIN=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)

RB_TL="╭"; RB_BL="╰"; RB_H="─"; RB_V="│"
RB_TR="╮"; RB_BR="╯"; RB_LT="├"; RB_RT="┤"

setup_glyphs() {
    # A blank locale (sudo may strip it) counts as UTF-8; only an explicit non-UTF-8 one forces ASCII.
    local loc="${LC_ALL:-}${LC_CTYPE:-}${LANG:-}"
    [[ -n "$loc" && "$loc" != *[Uu][Tt][Ff]* ]] && UI_ASCII=1
    [[ "${MINT_ASCII:-0}" == "1" ]] && UI_ASCII=1
    (( UI_ASCII == 0 )) && return 0

    G_ON="*"; G_OFF="-"
    G_EXPAND=">"; G_COLLAPSE="v"; G_BAR="|"
    G_PROG_F="="; G_PROG_E="-"; G_DOT="-"; G_ELLIPSIS="~"
    G_MINI_F="#"; G_MINI_E="."; G_UP="^"; G_DOWN="v"
    G_INFO=">"; G_OK="+"; G_WARN="!"; G_ERR="x"
    G_DIAMOND="*"; G_REFRESH="~"; G_PIPE="|"
    G_SPIN=('|' '/' '-' "\\")
    RB_TL="+"; RB_BL="+"; RB_H="-"; RB_V="|"
    RB_TR="+"; RB_BR="+"; RB_LT="+"; RB_RT="+"
}

# String helpers return through REPLY so redraw loops never fork; C.UTF-8 counts multibyte glyphs as one column when sudo blanks the locale.
ui_trunc() {  # $1 text, $2 max columns → REPLY: text cut to fit, ending in an ellipsis
    local LC_ALL=C.UTF-8 max=$2
    REPLY=$1
    (( max <= 0 )) && { REPLY=""; return 0; }
    (( ${#REPLY} > max )) && REPLY="${REPLY:0:max-1}${G_ELLIPSIS}"
    return 0
}

ui_pad() {  # $1 text, $2 columns → REPLY: text cut or space-padded to exactly that width
    local LC_ALL=C.UTF-8 t
    ui_trunc "$1" "$2"; t=$REPLY
    ui_rep $(( $2 - ${#t} )) ' '
    REPLY="${t}${REPLY}"
}

ui_rep() {  # $1 count, $2 char → REPLY: char repeated
    REPLY=""
    (( $1 > 0 )) || return 0
    printf -v REPLY '%*s' "$1" ''
    REPLY=${REPLY// /$2}
}

RUN_DIR=/run/install-app            # per-run scratch: reboot reasons, step errors
STATE_DIR=/var/lib/install-app      # markers that must survive a reboot
LOG_DIR=/var/log/install-app
LOG_FILE=""
APT_RUN_CONF=/etc/apt/apt.conf.d/99install-app-run
export DEBIAN_FRONTEND=noninteractive

# Inside a step (STEP_ACTIVE=1) info also feeds the spinner's sub-status and warn the warnings shown under the result line.
STEP_ACTIVE=0
info() {
    echo -e "\n  ${C_BLUE}${G_INFO}${NC} $*"
    if (( STEP_ACTIVE )); then
        { printf '%s\n' "$*" > "$RUN_DIR/status.tmp" && mv -f "$RUN_DIR/status.tmp" "$RUN_DIR/status"; } 2>/dev/null || true
    fi
}
success() { echo -e "  ${C_GREEN}${G_OK}${NC} $*"; }
warn() {
    echo -e "  ${C_YELLOW}${G_WARN}${NC} $*"
    if (( STEP_ACTIVE )); then printf '%s\n' "$*" >> "$RUN_DIR/step-warnings" 2>/dev/null || true; fi
}
fail()    { echo -e "  ${C_RED}${G_ERR}${NC} $*"; }

need_root() {
    if [[ $EUID -ne 0 ]]; then
        warn "Requesting sudo privileges..."
        # sudo drops COLORTERM, which decides truecolor.
        exec sudo env "MINT_ASCII=${MINT_ASCII:-0}" "COLORTERM=${COLORTERM:-}" bash "$SCRIPT_DIR/install-app.sh" "$@"
    fi
}

REAL_USER="${SUDO_USER:-${USER:-$(id -un)}}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6 || true)

user_login_shell() { getent passwd "$REAL_USER" | cut -d: -f7; }

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
