# shellcheck shell=bash

# "key|group|Name::tagline|default_on"; array order is install order.
APPS=(
    "mirror|system|APT Mirror::route apt through Vietnam's fastest mirrors|1"
    "update|system|System Update::refresh sources & upgrade every package|1"
    "swap|system|Swap File::8 GB swap · swappiness dialed to 10|1"
    "terminal|system|Terminal Kit::zsh · oh-my-zsh · tmux · fzf · rg · bat · jq|1"
    "font|system|Fonts::Nerd Font glyphs + Vietnamese web fonts (Facebook/Chrome)|1"
    "msfonts|system|MS Fonts::Arial, Times New Roman, Calibri & ClearType fonts|1"
    "eza|system|eza::a modern ls with icons & git awareness|1"
    "fastfetch|system|Fastfetch::system info at a glance, neofetch reborn|1"
    "btop|system|btop::CPU, memory, disk & network monitor in the terminal|1"
    "zoxide|system|zoxide::a smarter cd that remembers your folders|1"
    "lazygit|system|lazygit::git in a fast terminal UI|1"
    "nvm|dev|Node.js LTS::managed by nvm, swap versions on the fly|1"
    "bun|dev|Bun::all-in-one JS runtime & toolkit, blazing fast|1"
    "pnpm|dev|pnpm::fast, disk-efficient package manager via corepack|1"
    "yarn|dev|Yarn 4::the Berry JS package manager via corepack|1"
    "uv|dev|uv::fast Python installs, venvs & tools|1"
    "go|dev|Go::the official Go toolchain from go.dev|1"
    "dotnet|dev|.NET SDK::build & run cross-platform .NET|1"
    "abp|dev|ABP CLI::ABP Studio CLI for building ABP apps|1"
    "chrome|desktop|Google Chrome::the web's default browser|1"
    "edge|desktop|Microsoft Edge::Chromium with a Microsoft accent|1"
    "teams|desktop|Microsoft Teams::a native client built for Linux|1"
    "zalo|desktop|Zalo::chat & calls on Linux, unofficial port with bundled Wine|0"
    "vscode|dev|VS Code::the editor that does it all|1"
    "trae|dev|Trae IDE::AI-native coding by ByteDance|1"
    "android|dev|Android Emulator::Google's emulator, latest Android + Play Store|0"
    "gh|devops|GitHub CLI::PRs, issues & releases from the shell|1"
    "terraform|devops|Terraform::infrastructure as code, done right|1"
    "azcli|devops|Azure CLI::command the Azure cloud from your shell|1"
    "azcopy|devops|AzCopy::blazing-fast Azure Storage transfers|1"
    "docker|devops|Docker::container engine + Compose plugin|1"
    "kubectl|devops|kubectl::drive any Kubernetes cluster from the shell|1"
    "lazydocker|devops|lazydocker::containers, logs & images in a terminal UI|1"
    "k3d|devops|k3d::throwaway k3s clusters running in Docker|1"
    "browserstack|devops|BrowserStack Local::secure tunnel for local cross-browser testing|1"
    "mysqlclient|database|MySQL Client::CLI shell + mysqldump backups|1"
    "pgclient|database|PostgreSQL Client::psql shell + pg_dump backups|1"
    "sqlcmd|database|sqlcmd::query SQL Server & Azure SQL|1"
    "dbeaver|database|DBeaver CE::one GUI for every database|1"
    "navicat|database|Navicat Lite 18::a sleek database workbench|1"
    "fcitx5|desktop|Fcitx5::Vietnamese typing — Unikey / Lotus / Ngó Sen|1"
    "flameshot|desktop|Flameshot::screenshots with arrows, blur & text|1"
    "keepassxc|desktop|KeePassXC::offline password manager, KeePass format|1"
    "localsend|desktop|LocalSend::share files with nearby phones & PCs, no cloud|1"
    "extmgr|desktop|Extension Manager::browse & install GNOME Shell extensions|1"
    "postman|desktop|Postman::the API platform for building & testing|1"
    "onlyoffice|desktop|ONLYOFFICE::office suite that keeps Word, Excel & PowerPoint layouts|0"
    "vlc|desktop|VLC::plays every media format on earth|1"
    "obs|desktop|OBS Studio::record & stream your screen, pro-grade|1"
    "anydesk|desktop|AnyDesk::fast remote desktop & support|1"
    "teamviewer|desktop|TeamViewer::remote control & support, cross-platform|1"
    "claude|dev|Claude Code::Anthropic's agentic dev CLI|1"
)
DOTNET_VERSIONS=(10)

# `lotus` and `ngosen` are third-party addons with their own apt repos; unikey ships in Ubuntu's archive.
IME_ENGINE="unikey"
INPUT_ENGINES=(
    "unikey|Unikey"
    "lotus|Lotus"
    "ngosen|Ngó Sen"
)

MIRROR_HOST="mirror.bizflycloud.vn"
MIRRORS=(
    "mirror.bizflycloud.vn|BizFly Cloud — VCCorp (1 Gbps)"
    "vn.archive.ubuntu.com|Ubuntu VN Official — XTDV CDN"
    "mirror.viettelcloud.vn|Viettel Cloud (1 Gbps, HTTP only)"
    "mirrors.gofiber.vn|GoFiber (1 Gbps)"
    "mirrors.tino.org|Tino Group — HCM"
    "mirror.clearsky.vn|ClearSky"
)

# Format: "groupkey|Title|Short|icon|ascii-icon" — menu order is array order; Short fits the two-pane group list.
APP_GROUPS=(
    "system|System & Shell|System|≡|#"
    "dev|Languages & IDEs|Languages|◆|>"
    "devops|DevOps & Cloud|DevOps|▲|^"
    "database|Databases|Databases|⬡|="
    "desktop|Apps & Desktop|Desktop|◎|@"
)
declare -A APP_LABELS GROUP_APPS GROUP_LABEL GROUP_SHORT GROUP_ICON GROUP_ICON_ASCII
GROUP_KEYS=()
for _entry in "${APP_GROUPS[@]}"; do
    IFS='|' read -r _g _l _s _i _a <<< "$_entry"
    GROUP_KEYS+=("$_g")
    GROUP_LABEL[$_g]=$_l; GROUP_SHORT[$_g]=$_s; GROUP_ICON[$_g]=$_i; GROUP_ICON_ASCII[$_g]=$_a
done
for _entry in "${APPS[@]}"; do
    IFS='|' read -r _k _g _l _ <<< "$_entry"
    APP_LABELS[$_k]="$_l"
    GROUP_APPS[$_g]+="${GROUP_APPS[$_g]:+,}$_k"
done
MAX_GROUP_SIZE=0
for _g in "${GROUP_KEYS[@]}"; do
    IFS=',' read -ra _a <<< "${GROUP_APPS[$_g]:-}"
    if (( ${#_a[@]} > MAX_GROUP_SIZE )); then MAX_GROUP_SIZE=${#_a[@]}; fi
done

# Every app needs a known group, its apps/<key>.sh and both do_/undo_ functions, or the menu/dispatch breaks mid-run.
validate_registry() {
    local LC_ALL=C.UTF-8 entry g key group file
    local -A groups=() in_apps=()
    for g in "${APP_GROUPS[@]}"; do
        IFS='|' read -r key _ short _ <<< "$g"
        (( ${#short} >= 1 && ${#short} <= 11 )) || { echo "Registry error: group '$key' needs a short label of 1-11 characters" >&2; exit 1; }
        [[ -n "${GROUP_APPS[$key]:-}" ]] || { echo "Registry error: group '$key' has no apps" >&2; exit 1; }
        groups[$key]=1
    done
    for entry in "${APPS[@]}"; do
        IFS='|' read -r key group _ <<< "$entry"
        in_apps[$key]=1
        [[ -n "${groups[$group]:-}" ]] || { echo "Registry error: app '$key' has unknown group '$group'" >&2; exit 1; }
        [[ -f "$SCRIPT_DIR/apps/$key.sh" ]] || { echo "Registry error: app '$key' has no apps/$key.sh" >&2; exit 1; }
        declare -F "do_$key" >/dev/null && declare -F "undo_$key" >/dev/null \
            || { echo "Registry error: app '$key' needs both do_$key and undo_$key" >&2; exit 1; }
    done
    for file in "$SCRIPT_DIR"/apps/*.sh; do
        key=$(basename "$file" .sh)
        [[ -n "${in_apps[$key]:-}" ]] || { echo "Registry error: apps/$key.sh has no APPS entry" >&2; exit 1; }
    done
}
