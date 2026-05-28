#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Ubuntu / Linux Mint — Post-install Setup Script
# Interactive app selector with swap configuration
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

# --- App registry -----------------------------------------------------------
# Format: "key|label|default_on"
APPS=(
    # ── System ──
    "update|System Update & Upgrade|1"
    "swap|Swap 8GB + swappiness 10|1"

    # ── Shell & Terminal ──
    "terminal|Terminal tools (zsh, oh-my-zsh, tmux, htop, jq, yq, rg, fzf, bat)|1"

    # ── Languages & Runtime ──
    "nvm|NVM + Node.js 24|1"
    "dotnet|.NET SDK (chọn version)|1"

    # ── Browser ──
    "chrome|Google Chrome|1"
    "edge|Microsoft Edge|1"

    # ── Communication ──
    "teams|Teams for Linux|1"

    # ── IDE & Editor ──
    "vscode|Visual Studio Code|1"
    "trae|Trae IDE|1"

    # ── DevOps & Infrastructure ──
    "terraform|Terraform|1"
    "azcli|Azure CLI|1"
    "docker|Docker + Docker Compose|1"

    # ── Database Tools ──
    "mysqlclient|MySQL Client (mysqldump)|1"
    "pgclient|PostgreSQL Client (pg_dump)|1"
    "dbeaver|DBeaver Community|1"
    "navicat|Navicat Premium Lite|1"

    # ── Productivity ──
    "fcitx5|Fcitx5 (Vietnamese input)|1"
    "vlc|VLC Media Player|1"

    # ── AI Tools ──
    "claude|Claude Code|1"
)

declare -A SELECTED
DOTNET_VERSIONS=(10)
CURSOR=0

APP_GROUPS=(
    "system|System|⚙|update,swap"
    "terminal|Shell & Terminal|⌨|terminal"
    "languages|Languages & Runtime|◆|nvm,dotnet"
    "browser|Browser|◎|chrome,edge"
    "communication|Communication|✉|teams"
    "ide|IDE & Editor|✎|vscode,trae"
    "devops|DevOps & Infrastructure|▲|terraform,azcli,docker"
    "database|Database Tools|⬡|mysqlclient,pgclient,dbeaver,navicat"
    "productivity|Productivity|★|fcitx5,vlc"
    "ai|AI Tools|◈|claude"
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
    for entry in "${APPS[@]}"; do
        IFS='|' read -r key label default <<< "$entry"
        SELECTED[$key]=$default
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

print_menu() {
    build_visible
    clear
    local total=${#APPS[@]}
    local sel
    sel=$(count_selected)

    echo ""
    echo -e "  ${DIM}╭─────────────────────────────────────────────────────╮${NC}"
    echo -e "  ${DIM}│${NC}                                                     ${DIM}│${NC}"
    echo -e "  ${DIM}│${NC}   ${BOLD}${CYAN}  Ubuntu / Linux Mint${NC}                              ${DIM}│${NC}"
    echo -e "  ${DIM}│${NC}   ${DIM}  Post-install Setup${NC}                               ${DIM}│${NC}"
    echo -e "  ${DIM}│${NC}                                                     ${DIM}│${NC}"
    echo -e "  ${DIM}╰─────────────────────────────────────────────────────╯${NC}"
    echo ""

    local i=0
    for (( i=0; i<${#VIS_TYPES[@]}; i++ )); do
        local vtype="${VIS_TYPES[$i]}"
        local vkey="${VIS_KEYS[$i]}"

        if [[ "$vtype" == "group" ]]; then
            local glabel="" gicon="" gapps=""
            for g in "${APP_GROUPS[@]}"; do
                IFS='|' read -r gk gl gi ga <<< "$g"
                if [[ "$gk" == "$vkey" ]]; then
                    glabel="$gl"; gicon="$gi"; gapps="$ga"
                    break
                fi
            done

            local gsel gtotal
            gsel=$(group_sel_count "$gapps")
            gtotal=$(group_app_count "$gapps")

            local expanded="${GROUP_EXPANDED[$vkey]}"
            local arrow="▸"
            if [[ "$expanded" == "1" ]]; then
                arrow="▾"
            fi

            local status_color="${GREEN}"
            local status_dot="●"
            if [[ "$gsel" -eq 0 ]]; then
                status_color="${DIM}"
                status_dot="○"
            elif [[ "$gsel" -lt "$gtotal" ]]; then
                status_color="${YELLOW}"
                status_dot="◐"
            fi

            if [[ $i -eq $CURSOR ]]; then
                printf " ${BOLD}${CYAN}▶▶${NC} ${DIM}${arrow}${NC} ${MAGENTA}${gicon}${NC} ${BOLD}${WHITE}%-32s${NC} %b%s %s/%s${NC}\n" \
                    "$glabel" "$status_color" "$status_dot" "$gsel" "$gtotal"
            else
                printf "     ${DIM}${arrow}${NC} ${MAGENTA}${gicon}${NC} ${BOLD}${WHITE}%-32s${NC} %b%s %s/%s${NC}\n" \
                    "$glabel" "$status_color" "$status_dot" "$gsel" "$gtotal"
            fi

        else
            local label="${APP_LABELS[$vkey]}"
            local extra=""
            if [[ "$vkey" == "dotnet" ]]; then
                extra=" ${DIM}[${DOTNET_VERSIONS[*]}]${NC}"
            fi

            if [[ "${SELECTED[$vkey]}" == "1" ]]; then
                if [[ $i -eq $CURSOR ]]; then
                    printf "   ${BOLD}${CYAN}▶▶${NC} ${GREEN}●${NC} ${BOLD}%s${NC}%b\n" "$label" "$extra"
                else
                    printf "       ${GREEN}●${NC} %s%b\n" "$label" "$extra"
                fi
            else
                if [[ $i -eq $CURSOR ]]; then
                    printf "   ${BOLD}${CYAN}▶▶${NC} ${DIM}○${NC} ${DIM}%s${NC}%b\n" "$label" "$extra"
                else
                    printf "       ${DIM}○ %s${NC}%b\n" "$label" "$extra"
                fi
            fi
        fi
    done

    echo ""
    echo -e "  ${DIM}─────────────────────────────────────────────────────${NC}"
    printf "  ${CYAN}%s${NC}${DIM}/${NC}${WHITE}%s${NC} selected\n" "$sel" "$total"
    echo ""
    echo -e "  ${DIM}↑↓${NC} Move  ${DIM}Space${NC} Toggle  ${DIM}Enter${NC} Expand/Collapse  ${DIM}d${NC} .NET ver"
    echo -e "  ${DIM}a${NC} All   ${DIM}n${NC} None   ${DIM}q${NC} Quit   ${BOLD}${CYAN}i${NC} ${DIM}→${NC} Install"
    echo ""
}

configure_dotnet() {
    echo ""
    echo -e "  ${DIM}Available:${NC} 6  7  8  9  10"
    echo -e "  ${DIM}Current: ${NC} ${BOLD}${DOTNET_VERSIONS[*]}${NC}"
    echo ""
    read -rp "  Versions (e.g. '8 9 10'): " input
    if [[ -n "$input" ]]; then
        DOTNET_VERSIONS=($input)
        SELECTED[dotnet]=1
    fi
}

read_key() {
    local key
    IFS= read -rsn1 key
    if [[ "$key" == $'\x1b' ]]; then
        read -rsn2 -t 0.1 key
        case "$key" in
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

interactive_menu() {
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
                fi
                ;;
            a) select_all ;;
            n) deselect_all ;;
            d) configure_dotnet ;;
            i) return ;;
            q) echo "Cancelled."; exit 0 ;;
        esac
    done
}

# --- Helpers -----------------------------------------------------------------

STEP_CURRENT=0
STEP_TOTAL=0

info()    { echo -e "\n  ${CYAN}▸${NC} $*"; }
success() { echo -e "  ${GREEN}✓${NC} $*"; }
warn()    { echo -e "  ${YELLOW}!${NC} $*"; }
fail()    { echo -e "  ${RED}✗${NC} $*"; }

print_step_header() {
    local label="$1"
    STEP_CURRENT=$((STEP_CURRENT + 1))
    echo ""
    echo -e "  ${DIM}[${STEP_CURRENT}/${STEP_TOTAL}]${NC} ${BOLD}${WHITE}${label}${NC}"
    echo -e "  ${DIM}$(printf '%.0s─' {1..50})${NC}"
}

need_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}Requesting sudo privileges...${NC}"
        exec sudo bash "$0" "$@"
    fi
}

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~$REAL_USER")

get_ubuntu_codename() {
    . /etc/os-release
    echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}"
}

get_ubuntu_version() {
    if [[ -f /etc/upstream-release/lsb-release ]]; then
        grep '^DISTRIB_RELEASE=' /etc/upstream-release/lsb-release | cut -d= -f2
    else
        lsb_release -rs
    fi
}

ensure_microsoft_gpg() {
    if [[ ! -f /usr/share/keyrings/microsoft.gpg ]]; then
        apt install -y wget gpg apt-transport-https >/dev/null 2>&1
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
            | gpg --dearmor -o /usr/share/keyrings/microsoft.gpg
    fi
}

# --- Install functions -------------------------------------------------------

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
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" 2>/dev/null || true
git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" 2>/dev/null || true
git clone https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions" 2>/dev/null || true
git clone https://github.com/zsh-users/zsh-history-substring-search "$ZSH_CUSTOM/plugins/zsh-history-substring-search" 2>/dev/null || true

if ! grep -q 'zsh-completions/src' "$HOME/.zshrc" 2>/dev/null; then
    sed -i '/^source \$ZSH\/oh-my-zsh.sh/i fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src' "$HOME/.zshrc"
fi

sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search z fzf sudo aliases docker docker-compose kubectl terraform)/' "$HOME/.zshrc"

if ! grep -q '# --- Tool integrations ---' "$HOME/.zshrc" 2>/dev/null; then
    cat >> "$HOME/.zshrc" << 'TOOLEOF'

# --- Tool integrations ---
# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# .NET
if [ -d "/usr/share/dotnet" ]; then
    export DOTNET_ROOT="/usr/share/dotnet"
    export PATH="$PATH:$DOTNET_ROOT"
fi
[ -d "$HOME/.dotnet/tools" ] && export PATH="$PATH:$HOME/.dotnet/tools"

# Azure CLI completions
if [ -f /etc/bash_completion.d/azure-cli ]; then
    autoload -U +X bashcompinit && bashcompinit
    source /etc/bash_completion.d/azure-cli
fi

# Claude Code
[ -d "$HOME/.claude/bin" ] && export PATH="$PATH:$HOME/.claude/bin"

# Cargo / Rust
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
TOOLEOF
fi
SETUP_EOF
    chmod +x "$setup_script"
    su - "$REAL_USER" -c "bash $setup_script"
    rm -f "$setup_script"

    chsh -s "$(which zsh)" "$REAL_USER"

    success "Terminal tools installed: zsh + oh-my-zsh (14 plugins), tmux, htop, jq, yq, rg, fzf, bat"
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

do_dotnet() {
    info "Installing .NET SDK (versions: ${DOTNET_VERSIONS[*]})..."
    ensure_microsoft_gpg

    local codename
    codename=$(get_ubuntu_codename)
    local ubuntu_ver
    ubuntu_ver=$(get_ubuntu_version)

    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/ubuntu/$ubuntu_ver/prod $codename main" \
        > /etc/apt/sources.list.d/dotnet.list
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
    wget -q -O "$tmp" "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
    apt install -y "$tmp"
    rm -f "$tmp"
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
        fail "Could not find Teams for Linux download URL"
        return 1
    fi

    local tmp
    tmp=$(mktemp /tmp/teams-for-linux-XXXXXX.deb)
    wget -q -O "$tmp" "$download_url"
    apt install -y "$tmp"
    rm -f "$tmp"
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
    wget -q -O "$tmp" "https://lf-cdn.trae.ai/obj/trae-ai-us/pkg/Trae_latest_linux_x64.deb"
    apt install -y "$tmp"
    rm -f "$tmp"
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

do_docker() {
    if command -v docker &>/dev/null; then
        success "Docker already installed, skipping"
        return
    fi

    info "Installing Docker + Docker Compose..."

    apt install -y ca-certificates curl gnupg

    install -m 0755 -d /etc/apt/keyrings
    local distro
    distro=$(. /etc/os-release && echo "$ID")

    if [[ "$distro" == "linuxmint" ]]; then
        distro="ubuntu"
    fi

    local codename
    codename=$(get_ubuntu_codename)

    curl -fsSL "https://download.docker.com/linux/$distro/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$distro $codename stable" \
        > /etc/apt/sources.list.d/docker.list

    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    usermod -aG docker "$REAL_USER"

    systemctl enable docker
    systemctl start docker

    success "Docker + Compose installed (user '$REAL_USER' added to docker group — re-login to apply)"
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
    wget -q -O "$tmp" "https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb"
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
    info "Installing Fcitx5 with Vietnamese support..."
    apt install -y fcitx5 fcitx5-unikey fcitx5-config-qt fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 fcitx5-frontend-qt5

    local env_file="$REAL_HOME/.pam_environment"
    local xprofile="$REAL_HOME/.xprofile"

    cat > "$env_file" <<'ENVEOF'
GTK_IM_MODULE DEFAULT=fcitx
QT_IM_MODULE  DEFAULT=fcitx
XMODIFIERS    DEFAULT=@im=fcitx
ENVEOF
    chown "$REAL_USER:$REAL_USER" "$env_file"

    if ! grep -q 'fcitx5' "$xprofile" 2>/dev/null; then
        cat >> "$xprofile" <<'XEOF'
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
fcitx5 &
XEOF
        chown "$REAL_USER:$REAL_USER" "$xprofile"
    fi

    local fcitx_conf_dir="$REAL_HOME/.config/fcitx5"
    local profile_file="$fcitx_conf_dir/profile"
    mkdir -p "$fcitx_conf_dir"
    cat > "$profile_file" <<'PROFEOF'
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=unikey

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=unikey
Layout=

[GroupOrder]
0=Default
PROFEOF
    chown -R "$REAL_USER:$REAL_USER" "$fcitx_conf_dir"

    success "Fcitx5 + Unikey installed & configured (re-login to activate)"
}

do_vlc() {
    info "Installing VLC..."
    apt install -y vlc
    success "VLC installed"
}

do_claude() {
    if su - "$REAL_USER" -c 'command -v claude' &>/dev/null; then
        success "Claude Code already installed, skipping"
        return
    fi

    info "Installing Claude Code..."
    su - "$REAL_USER" -c 'curl -fsSL https://claude.ai/install.sh | sh'
    success "Claude Code installed (run 'claude' to start)"
}

# --- Main --------------------------------------------------------------------

main() {
    need_root
    init_defaults

    if [[ "${1:-}" == "--all" ]]; then
        select_all
    else
        interactive_menu
    fi

    STEP_TOTAL=$(count_selected)

    echo ""
    echo -e "  ${DIM}╭─────────────────────────────────────────────────────╮${NC}"
    echo -e "  ${DIM}│${NC}  ${BOLD}${CYAN}Installing ${STEP_TOTAL} packages...${NC}$(printf '%*s' $((34 - ${#STEP_TOTAL})) '')${DIM}│${NC}"
    echo -e "  ${DIM}╰─────────────────────────────────────────────────────╯${NC}"

    local failed=()
    local succeeded=0
    local start_time=$SECONDS

    for entry in "${APPS[@]}"; do
        IFS='|' read -r key label _ <<< "$entry"
        if [[ "${SELECTED[$key]}" == "1" ]]; then
            print_step_header "$label"
            if "do_$key"; then
                succeeded=$((succeeded + 1))
            else
                fail "$label — installation failed"
                failed+=("$label")
            fi
        fi
    done

    local elapsed=$(( SECONDS - start_time ))
    local mins=$(( elapsed / 60 ))
    local secs=$(( elapsed % 60 ))

    echo ""
    echo ""
    echo -e "  ${DIM}╭─────────────────────────────────────────────────────╮${NC}"
    echo -e "  ${DIM}│${NC}                                                     ${DIM}│${NC}"
    if [[ ${#failed[@]} -eq 0 ]]; then
        echo -e "  ${DIM}│${NC}   ${GREEN}✓${NC}  ${BOLD}All done!${NC}                                      ${DIM}│${NC}"
    else
        echo -e "  ${DIM}│${NC}   ${YELLOW}!${NC}  ${BOLD}Completed with errors${NC}                           ${DIM}│${NC}"
    fi
    echo -e "  ${DIM}│${NC}                                                     ${DIM}│${NC}"
    local stats="${succeeded} installed"
    [[ ${#failed[@]} -gt 0 ]] && stats="${stats}  ${#failed[@]} failed"
    local time_str="${mins}m ${secs}s"
    printf "  ${DIM}│${NC}   ${GREEN}●${NC} %-44s${DIM}│${NC}\n" "$stats"
    printf "  ${DIM}│${NC}   ${DIM}⏱  %-44s${NC}${DIM}│${NC}\n" "$time_str"
    echo -e "  ${DIM}│${NC}                                                     ${DIM}│${NC}"
    echo -e "  ${DIM}╰─────────────────────────────────────────────────────╯${NC}"

    if [[ ${#failed[@]} -gt 0 ]]; then
        echo ""
        echo -e "  ${RED}Failed:${NC}"
        for f in "${failed[@]}"; do
            echo -e "    ${RED}✗${NC} ${DIM}$f${NC}"
        done
    fi

    echo ""
    echo -e "  ${YELLOW}⟳${NC}  ${DIM}Reboot or re-login to apply all changes${NC}"
    echo ""
}

main "$@"
