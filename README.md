<p align="center">
  <img src="https://img.shields.io/badge/Ubuntu-26.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" />
  <img src="https://img.shields.io/badge/Shell-Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white" />
</p>

<h1 align="center">SETUP &mdash; Ubuntu 26.04 Post-install Toolkit</h1>

<p align="center">Pick apps from a TUI menu on a fresh Ubuntu 26.04 (resolute) machine; the script installs them. Re-runs are safe and every app can be uninstalled.</p>

## Quick start

```bash
git clone https://github.com/hoangld89/ubuntu-install-apps.git
cd ubuntu-install-apps
git checkout "$(git describe --tags --abbrev=0)"   # optional: pin the latest release

./install-app.sh                  # interactive menu
./install-app.sh --all            # install everything
./install-app.sh --keep-shell     # keep your login shell (default: Terminal Kit switches to zsh)
./install-app.sh --uninstall      # same menu, removes what you pick
./install-app.sh --uninstall --all
./install-app.sh --ascii          # plain glyphs for fonts without box-drawing symbols
```

Launching with `sh` re-execs under bash. Other Ubuntu releases get a warning and the run continues.

## Menu

```
  █▀▀ █▀▀ ▀█▀ █ █ █▀█   ubuntu setup · post-install toolkit
  ▄▄█ ██▄  █  █▄█ █▀▀   v1.1.0 · Ubuntu 26.04 · hoangle · zsh · 36 apps

  ╭─ Groups ─────────────────╮ ╭─ Languages & IDEs ─────────────────────────────── 6/9 ─╮
  │   ⚙ System         8/8   │ │ ● Node.js LTS         managed by nvm, swap versions o… │
  │   ◆ Languages      6/9   │ │▌○ Bun                 all-in-one JS runtime & toolkit… │
  │   ▲ DevOps         5/5   │ │ ● pnpm                fast, disk-efficient package ma… │
  │   ⬡ Databases      4/4   │ │ ● Yarn 4              the Berry JS package manager vi… │
  │   ◎ Desktop      10/10   │ │ ● .NET SDK            build & run cross-platf… .NET 10 │
  ├──────────────────────────┤ │ ○ ABP CLI             ABP Studio CLI for building ABP… │
  │  m  mirror BizFly Cloud  │ │ ● VS Code             the editor that does it all      │
  │  g  IME    Unikey        │ │ ○ Trae IDE            AI-native coding by ByteDance    │
  │  d  .NET   10            │ │ ● Claude Code         Anthropic's agentic dev CLI      │
  │  s  login  zsh           │ │                                                        │
  ╰──────────────────────────╯ ╰────────────────────────────────────────────────────────╯
   ↑↓  move   ←→  panel   space  toggle   a  all   n  none      q  quit    i  install 33
```

Two panes need 80 columns; narrower terminals get a single list with collapsible groups (`Enter`).

| Key | Action |
|-----|--------|
| `↑` `↓` / `k` `j` | Move within the focused pane |
| `←` `→` / `h` `l`, `Tab`, `Enter` | Switch between groups and apps |
| `Space`, `a`, `n` | Toggle app or whole group, select all, select none |
| `d` / `m` / `g` | .NET versions (8, 9, 10) / APT mirror / Vietnamese input engine (install only) |
| `s` | zsh as login shell yes/no (install only) |
| `i` / `q` | Start / quit |

Truecolor (Catppuccin Mocha) when `COLORTERM` is `truecolor`/`24bit`, 256 colours otherwise. Boxes instead of icons mean the font lacks the glyphs: use **MesloLGS NF** (installed by *Fonts*) or `--ascii`.

## What gets installed

| Group | App | How |
|-------|-----|-----|
| System & Shell | APT mirror | Points the Ubuntu archive at a Vietnam mirror (`m` to pick), backs up the sources files; runs first |
| | System update | `apt-get update`, `upgrade --with-new-pkgs`, `autoremove`, keeping existing config files |
| | Swap | Grows `/swap.img` (or creates `/swapfile`) to 8 GB, `swappiness=10` |
| | Terminal Kit | zsh + Oh My Zsh (git, zsh-autosuggestions, zsh-syntax-highlighting), tmux, htop, jq, yq, ripgrep, fzf, bat |
| | Fonts | MesloLGS NF (set in gnome-terminal), Noto + Liberation for Vietnamese diacritics in browsers |
| | MS Fonts | `ttf-mscorefonts-installer` plus Calibri/ClearType faces from PowerPoint Viewer |
| | eza, Fastfetch | Ubuntu archive; eza adds `ls`/`ll`/`la`/`lt` aliases |
| Languages & IDEs | Node.js LTS | nvm, `nvm install --lts`; a re-run moves to the next LTS line |
| | Bun | `bun.sh/install`, per user |
| | pnpm, Yarn 4 | corepack npm package (needs Node.js) |
| | .NET SDK | 10 from the archive, 8/9 from `ppa:dotnet/backports` (end of support 2026-11-10) |
| | ABP CLI | `Volo.Abp.Studio.Cli` dotnet tool (needs .NET) |
| | VS Code | Microsoft apt repo |
| | Trae IDE | `.deb` from Trae's release API; reinstalled when a new build appears |
| | Claude Code | `claude.ai/install.sh` |
| DevOps & Cloud | Terraform | HashiCorp apt repo |
| | Azure CLI | Microsoft apt repo |
| | AzCopy | v10 tarball → `/usr/local/bin/azcopy` |
| | Docker | Docker apt repo (CE, Compose, buildx); removes conflicting distro packages, adds you to `docker` |
| | BrowserStack Local | Official zip → `/usr/local/bin/BrowserStackLocal` |
| Databases | MySQL / PostgreSQL clients | apt |
| | DBeaver CE | `dbeaver.io` apt repo |
| | Navicat Premium Lite 18 | AppImage in `/opt`, `navicat` command; backs up `~/.config/navicat` on upgrade |
| Apps & Desktop | Chrome | `.deb` |
| | Edge | Microsoft apt repo |
| | Teams for Linux | `repo.teamsforlinux.de` (unofficial Electron client) |
| | Fcitx5 | Unikey or Bamboo (archive) or Lotus (third-party repo); sets IM env vars, autostart, profile |
| | Postman | Tarball → `/opt/Postman` |
| | Waydroid | Official repo; needs Wayland + `binder`, run `waydroid init` once |
| | VLC | apt |
| | OBS Studio | `ppa:obsproject/obs-studio` |
| | AnyDesk, TeamViewer | Official repos |

Runtime PATH/env (nvm, Bun, pnpm, .NET, Azure completion, Claude Code) is one `# --- Tool integrations ---` block written to `.bashrc`, and to `.zshrc` when zsh is installed, so tools work in either shell.

Chromium/Electron launchers (Chrome, Edge, VS Code, Teams, Trae, Postman) get Wayland IME flags so fcitx5 can type into them; an apt hook re-applies the flags after package upgrades.

## Running

- **Re-runs** skip anything already installed and move old installs onto the current method (DBeaver/Teams `.deb` → apt repo, Node → current LTS).
- **Output:** one line per step with a spinner, then `✓` / `!` (warnings listed under it) / `✗` with the failing command and the step's last 15 log lines. A failure ends that step only.
- **Log:** full output in `/var/log/install-app/<YYYYmmdd-HHMMSS>.log`; `tail -f` it to watch a step.
- **Ctrl-C** prints a partial summary. apt waits up to 10 minutes for a busy dpkg lock.
- **Reboot/re-login** is suggested only when needed (docker group, login shell, `/etc/environment`, `/var/run/reboot-required`), with the reasons.

```
  ◆ Installing 28 apps · log /var/log/install-app/20261001-101500.log

  ✓ APT Mirror           mirror.bizflycloud.vn                              2s
  ✗ Docker                                                                 9s
      "apt-get install -y docker-ce docker-ce-cli …" exited 100 (do_docker, line N)
      │ E: Unable to locate package docker-ce
  ⠹ Swap File            Configuring 8GB swap with swappiness 10...        4s
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━──────────────  3/28 · 1m23s
```

## Uninstall

Every app starts unselected and `i` asks for confirmation. Each `undo_<key>` purges its packages, apt repo and key, downloaded binaries and the rc blocks it added; the mirror is restored from its backups.

Kept on purpose: `git`, `curl`, Docker data (`/var/lib/docker`, `/var/lib/containerd`, `/etc/docker`), `unixodbc-dev`, `~/.claude`, and a completed system upgrade.

## Troubleshooting

Garbled glyphs in the VS Code / Trae terminal: in `~/.config/Code/User/settings.json` (or `Trae/User`) set

```json
"terminal.integrated.gpuAcceleration": "off",
"terminal.integrated.fontFamily": "'DejaVu Sans Mono', 'Noto Sans Mono', monospace"
```

## Contributing

```
install-app.sh     entrypoint
lib/               core, registry (APPS, APP_GROUPS), apt, shell-rc, shared, ui-menu, ui-run, runner
apps/<key>.sh      do_<key> (install) + undo_<key> (uninstall), one file per app
```

To add an app, add `"key|group|Name::tagline|default_on"` to `APPS` in `lib/registry.sh` (array order is install order) and create `apps/<key>.sh`:

```bash
do_myapp() {
    if command -v myapp &>/dev/null; then
        success "My App already installed, skipping"
        return
    fi
    info "Installing My App..."
    apt-get install -y myapp
}

undo_myapp() {
    apt_purge myapp
}
```

Steps run with `set -e`; guard expected failures with `|| true` and add apt repos with `add_apt_repo`. Conventions, PR and release rules are in [CLAUDE.md](CLAUDE.md).

## Releases

Versions follow SemVer and are tagged `vX.Y.Z` on `main` with GitHub Release notes. `./install-app.sh --help` shows the running version.

## Requirements

Ubuntu 26.04 amd64, `sudo`, internet access.

## License

MIT
