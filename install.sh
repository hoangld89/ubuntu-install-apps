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
BOLD='\033[1m'
NC='\033[0m'

# --- App registry -----------------------------------------------------------
# Format: "key|label|default_on"
APPS=(
    # ── System ──
    "update|System Update & Upgrade|1"
    "swap|Swap 8GB + swappiness 10|1"

    # ── Browser & Communication ──
    "chrome|Google Chrome|1"
    "teams|Microsoft Teams|1"

    # ── IDE & Editor ──
    "vscode|Visual Studio Code|1"
    "trae|Trae IDE|1"

    # ── Languages & Runtime ──
    "nvm|NVM + Node.js 24|1"
    "dotnet|.NET SDK (chọn version)|1"

    # ── Terminal Utilities ──
    "terminal|Terminal tools (zsh, tmux, htop, jq, yq, rg, fzf, bat)|1"

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
    "claude|Claude CLI|1"
)

declare -A SELECTED
DOTNET_VERSIONS=(10)
CURSOR=0

init_defaults() {
    for entry in "${APPS[@]}"; do
        IFS='|' read -r key label default <<< "$entry"
        SELECTED[$key]=$default
    done
}

print_menu() {
    clear
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║   Ubuntu / Linux Mint — App Installer            ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    local i=0
    local last_group=""
    for entry in "${APPS[@]}"; do
        IFS='|' read -r key label _ <<< "$entry"

        local group=""
        case "$key" in
            update|swap)        group="System" ;;
            chrome|teams)       group="Browser & Communication" ;;
            vscode|trae)        group="IDE & Editor" ;;
            nvm|dotnet)         group="Languages & Runtime" ;;
            terminal)           group="Terminal Utilities" ;;
            terraform|azcli|docker) group="DevOps & Infrastructure" ;;
            mysqlclient|pgclient|dbeaver|navicat) group="Database Tools" ;;
            fcitx5|vlc|claude)  group="Productivity" ;;
        esac
        if [[ "$group" != "$last_group" ]]; then
            echo -e "\n       ${BOLD}── $group ──${NC}"
            last_group="$group"
        fi

        local extra=""
        if [[ "$key" == "dotnet" ]]; then
            extra=" ${CYAN}[versions: ${DOTNET_VERSIONS[*]}]${NC}"
        fi

        local pointer="  "
        if [[ $i -eq $CURSOR ]]; then
            pointer="${BOLD}${CYAN}▸ ${NC}"
        fi

        if [[ "${SELECTED[$key]}" == "1" ]]; then
            printf " %b${GREEN}[x]${NC} %s%b\n" "$pointer" "$label" "$extra"
        else
            printf " %b${RED}[ ]${NC} %s%b\n" "$pointer" "$label" "$extra"
        fi
        i=$((i + 1))
    done
    echo ""
    echo -e "  ${YELLOW}↑↓${NC} Di chuyển  ${YELLOW}Space${NC} Chọn/bỏ  ${YELLOW}a${NC} Tất cả  ${YELLOW}n${NC} Bỏ tất cả"
    echo -e "  ${YELLOW}d${NC}  .NET ver   ${YELLOW}Enter${NC} Cài đặt  ${YELLOW}q${NC} Thoát"
    echo ""
}

toggle() {
    local idx=$1
    IFS='|' read -r key _ _ <<< "${APPS[$idx]}"
    if [[ "${SELECTED[$key]}" == "1" ]]; then
        SELECTED[$key]=0
    else
        SELECTED[$key]=1
    fi
}

select_all()   { for entry in "${APPS[@]}"; do IFS='|' read -r key _ _ <<< "$entry"; SELECTED[$key]=1; done; }
deselect_all() { for entry in "${APPS[@]}"; do IFS='|' read -r key _ _ <<< "$entry"; SELECTED[$key]=0; done; }

configure_dotnet() {
    echo ""
    echo -e "${CYAN}Available .NET SDK versions: 6, 7, 8, 9, 10${NC}"
    echo -e "Current selection: ${BOLD}${DOTNET_VERSIONS[*]}${NC}"
    echo ""
    read -rp "  Enter versions (space-separated, e.g. '8 9 10'): " input
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
    local total=${#APPS[@]}
    while true; do
        print_menu
        local key
        key=$(read_key)
        case "$key" in
            UP)
                [[ $CURSOR -gt 0 ]] && CURSOR=$((CURSOR - 1))
                ;;
            DOWN)
                [[ $CURSOR -lt $((total - 1)) ]] && CURSOR=$((CURSOR + 1))
                ;;
            SPACE)
                toggle "$CURSOR"
                ;;
            a) select_all ;;
            n) deselect_all ;;
            d) configure_dotnet ;;
            ENTER) break ;;
            q) echo "Cancelled."; exit 0 ;;
        esac
    done
}

# --- Helpers -----------------------------------------------------------------

info()    { echo -e "\n${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail()    { echo -e "${RED}[FAIL]${NC} $*"; }

need_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Please run with sudo:${NC} sudo bash $0"
        exit 1
    fi
}

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~$REAL_USER")

# --- Install functions -------------------------------------------------------

do_update() {
    info "Updating system packages..."
    apt update && apt upgrade -y && apt autoremove -y
    success "System updated"
}

do_swap() {
    info "Configuring 8GB swap with swappiness 10..."

    if swapon --show | grep -q '/swapfile'; then
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

do_chrome() {
    info "Installing Google Chrome..."
    local tmp
    tmp=$(mktemp /tmp/chrome-XXXXXX.deb)
    wget -q -O "$tmp" "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
    apt install -y "$tmp"
    rm -f "$tmp"
    success "Google Chrome installed"
}

do_vscode() {
    info "Installing Visual Studio Code..."
    apt install -y wget gpg apt-transport-https
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
        > /etc/apt/sources.list.d/vscode.list
    apt update
    apt install -y code
    success "VS Code installed"
}

do_trae() {
    info "Installing Trae IDE..."
    local tmp
    tmp=$(mktemp /tmp/trae-XXXXXX.deb)
    wget -q -O "$tmp" "https://lf-cdn.trae.ai/obj/trae-ai-us/pkg/Trae_latest_linux_x64.deb"
    apt install -y "$tmp"
    rm -f "$tmp"
    success "Trae IDE installed"
}

do_teams() {
    info "Installing Microsoft Teams..."

    apt install -y wget gpg apt-transport-https
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/teams.microsoft.gpg 2>/dev/null
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/teams.microsoft.gpg] https://packages.microsoft.com/repos/ms-teams stable main" \
        > /etc/apt/sources.list.d/teams.list
    apt update

    if apt-cache show teams &>/dev/null; then
        apt install -y teams
    else
        warn "teams package not found in repo, downloading .deb directly..."
        local tmp
        tmp=$(mktemp /tmp/teams-XXXXXX.deb)
        wget -q -O "$tmp" "https://go.microsoft.com/fwlink/?linkid=2196106"
        apt install -y "$tmp"
        rm -f "$tmp"
    fi
    success "Microsoft Teams installed"
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

    success "Fcitx5 + Unikey installed (re-login to activate)"
}

do_vlc() {
    info "Installing VLC..."
    apt install -y vlc
    success "VLC installed"
}

do_nvm() {
    info "Installing NVM + Node.js 24 for user '$REAL_USER'..."
    apt install -y curl

    local NVM_DIR="$REAL_HOME/.nvm"

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
    apt install -y wget apt-transport-https

    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/dotnet.microsoft.gpg 2>/dev/null
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/dotnet.microsoft.gpg] https://packages.microsoft.com/ubuntu/$(lsb_release -rs)/prod $(lsb_release -cs) main" \
        > /etc/apt/sources.list.d/dotnet.list
    apt update

    local installed=()
    local failed_ver=()

    for ver in "${DOTNET_VERSIONS[@]}"; do
        local pkg="dotnet-sdk-${ver}.0"
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

do_terminal() {
    info "Installing terminal utilities..."

    apt install -y zsh tmux htop jq ripgrep fzf git curl

    if ! command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
        apt install -y bat 2>/dev/null || apt install -y batcat 2>/dev/null || true
    fi
    if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
        ln -sf "$(which batcat)" /usr/local/bin/bat
    fi

    info "Installing yq..."
    local yq_url="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"
    wget -q -O /usr/local/bin/yq "$yq_url"
    chmod +x /usr/local/bin/yq

    info "Installing Oh My Zsh for '$REAL_USER'..."
    su - "$REAL_USER" -c '
        export RUNZSH=no CHSH=no
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

        ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
        git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" 2>/dev/null || true
        git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" 2>/dev/null || true

        sed -i "s/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting fzf)/" "$HOME/.zshrc"
    '

    chsh -s "$(which zsh)" "$REAL_USER"

    success "Terminal tools installed: zsh + oh-my-zsh, tmux, htop, jq, yq, ripgrep, fzf, bat"
}

do_terraform() {
    info "Installing Terraform..."
    apt install -y gnupg software-properties-common curl

    curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
        > /etc/apt/sources.list.d/hashicorp.list
    apt update
    apt install -y terraform

    success "Terraform $(terraform --version | head -1) installed"
}

do_azcli() {
    info "Installing Azure CLI..."
    apt install -y ca-certificates curl apt-transport-https lsb-release gnupg

    curl -sLS https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" \
        > /etc/apt/sources.list.d/azure-cli.list
    apt update
    apt install -y azure-cli

    success "Azure CLI $(az version --output tsv 2>/dev/null | head -1) installed"
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
    info "Installing DBeaver Community..."
    local tmp
    tmp=$(mktemp /tmp/dbeaver-XXXXXX.deb)
    wget -q -O "$tmp" "https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb"
    apt install -y "$tmp"
    rm -f "$tmp"
    success "DBeaver Community installed"
}

do_navicat() {
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

_load_nvm() {
    local NVM_DIR="$REAL_HOME/.nvm"
    if [[ -s "$NVM_DIR/nvm.sh" ]]; then
        export NVM_DIR
        . "$NVM_DIR/nvm.sh"
    fi
}

do_claude() {
    info "Installing Claude CLI..."

    _load_nvm

    if command -v npm &>/dev/null; then
        npm install -g @anthropic-ai/claude-code
    else
        warn "npm not found — install NVM + Node.js first (option NVM in menu), then re-run Claude CLI install"
        return 1
    fi
    success "Claude CLI installed (run 'claude' to start)"
}

do_docker() {
    info "Installing Docker + Docker Compose..."

    apt install -y ca-certificates curl gnupg

    install -m 0755 -d /etc/apt/keyrings
    local distro
    distro=$(. /etc/os-release && echo "$ID")

    if [[ "$distro" == "linuxmint" ]]; then
        distro="ubuntu"
    fi

    local codename
    codename=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")

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

# --- Main --------------------------------------------------------------------

main() {
    need_root
    init_defaults

    if [[ "${1:-}" == "--all" ]]; then
        select_all
    else
        interactive_menu
    fi

    echo ""
    echo -e "${BOLD}${CYAN}Starting installation...${NC}"
    echo "========================================"

    local failed=()

    for entry in "${APPS[@]}"; do
        IFS='|' read -r key label _ <<< "$entry"
        if [[ "${SELECTED[$key]}" == "1" ]]; then
            if ! "do_$key"; then
                fail "$label — installation failed"
                failed+=("$label")
            fi
        fi
    done

    echo ""
    echo "========================================"
    echo -e "${BOLD}${GREEN}Installation complete!${NC}"

    if [[ ${#failed[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Failed items:${NC}"
        for f in "${failed[@]}"; do
            echo -e "  ${RED}•${NC} $f"
        done
    fi

    echo ""
    echo -e "${YELLOW}Recommended: reboot or re-login to apply all changes.${NC}"
}

main "$@"
