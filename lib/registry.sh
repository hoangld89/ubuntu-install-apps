# shellcheck shell=bash

# Format: "key|group|Name::tagline|default_on" — install order is array order.
# The `::` splits the display name (highlighted) from a dim one-line tagline.
APPS=(
    # ── System ──
    "mirror|system|APT Mirror::route apt through Vietnam's fastest mirrors|1"
    "update|system|System Update::refresh sources & upgrade every package|1"
    "swap|system|Swap File::8 GB swap · swappiness dialed to 10|1"

    # ── Shell & Terminal ──
    "terminal|system|Terminal Kit::zsh · oh-my-zsh · tmux · fzf · rg · bat · jq|1"
    "font|system|Fonts::Nerd Font glyphs + Vietnamese web fonts (Facebook/Chrome)|1"
    "msfonts|system|MS Fonts::Arial, Times New Roman, Calibri & ClearType fonts|1"
    "eza|system|eza::a modern ls with icons & git awareness|1"
    "fastfetch|system|Fastfetch::system info at a glance, neofetch reborn|1"

    # ── Languages & Runtime ──
    "nvm|dev|Node.js LTS::managed by nvm, swap versions on the fly|1"
    "bun|dev|Bun::all-in-one JS runtime & toolkit, blazing fast|1"
    "pnpm|dev|pnpm::fast, disk-efficient package manager via corepack|1"
    "yarn|dev|Yarn 4::the Berry JS package manager via corepack|1"
    "dotnet|dev|.NET SDK::build & run cross-platform .NET|1"
    "abp|dev|ABP CLI::ABP Studio CLI for building ABP apps|1"

    # ── Browser ──
    "chrome|desktop|Google Chrome::the web's default browser|1"
    "edge|desktop|Microsoft Edge::Chromium with a Microsoft accent|1"

    # ── Communication ──
    "teams|desktop|Microsoft Teams::a native client built for Linux|1"

    # ── IDE & Editor ──
    "vscode|dev|VS Code::the editor that does it all|1"
    "trae|dev|Trae IDE::AI-native coding by ByteDance|1"

    # ── DevOps & Infrastructure ──
    "terraform|devops|Terraform::infrastructure as code, done right|1"
    "azcli|devops|Azure CLI::command the Azure cloud from your shell|1"
    "azcopy|devops|AzCopy::blazing-fast Azure Storage transfers|1"
    "docker|devops|Docker::container engine + Compose plugin|1"
    "browserstack|devops|BrowserStack Local::secure tunnel for local cross-browser testing|1"

    # ── Database Tools ──
    "mysqlclient|database|MySQL Client::CLI shell + mysqldump backups|1"
    "pgclient|database|PostgreSQL Client::psql shell + pg_dump backups|1"
    "dbeaver|database|DBeaver CE::one GUI for every database|1"
    "navicat|database|Navicat Lite 18::a sleek database workbench|1"

    # ── Productivity ──
    "fcitx5|desktop|Fcitx5::Vietnamese typing — Unikey / Bamboo / Lotus|1"
    "postman|desktop|Postman::the API platform for building & testing|1"
    "waydroid|desktop|Waydroid::run Android apps in a container (Wayland)|1"
    "vlc|desktop|VLC::plays every media format on earth|1"

    # ── Media & Capture ──
    "obs|desktop|OBS Studio::record & stream your screen, pro-grade|1"

    # ── Remote Desktop ──
    "anydesk|desktop|AnyDesk::fast remote desktop & support|1"
    "teamviewer|desktop|TeamViewer::remote control & support, cross-platform|1"

    # ── AI Tools ──
    "claude|dev|Claude Code::Anthropic's agentic dev CLI|1"
)
DOTNET_VERSIONS=(10)

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

# Format: "groupkey|Title|icon|ascii-icon" — menu order is array order.
APP_GROUPS=(
    "system|System & Shell|⚙|#"
    "dev|Languages & IDEs|◆|>"
    "devops|DevOps & Cloud|▲|^"
    "database|Databases|⬡|="
    "desktop|Apps & Desktop|◎|@"
)
declare -A APP_LABELS GROUP_APPS
for _entry in "${APPS[@]}"; do
    IFS='|' read -r _k _g _l _ <<< "$_entry"
    APP_LABELS[$_k]="$_l"
    GROUP_APPS[$_g]+="${GROUP_APPS[$_g]:+,}$_k"
done

# Every app needs a known group, its apps/<key>.sh and both do_/undo_ functions, or the menu/dispatch breaks mid-run.
validate_registry() {
    local entry g key group file
    local -A groups=() in_apps=()
    for g in "${APP_GROUPS[@]}"; do
        IFS='|' read -r key _ <<< "$g"
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
