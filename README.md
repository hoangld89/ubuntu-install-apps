<p align="center">
  <img src="https://img.shields.io/badge/Ubuntu-24.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" />
  <img src="https://img.shields.io/badge/Shell-Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white" />
</p>

<h1 align="center">SETUP &mdash; Ubuntu 24.04 Post-install Toolkit</h1>

<p align="center">
  An interactive post-install setup for a fresh Ubuntu 24.04 (noble) machine.<br/>
  Pick what you need from a TUI menu &mdash; everything else is automatic.
</p>

<p align="center">
  <b>35 apps</b> &nbsp;·&nbsp; <b>Idempotent</b> (safe to re-run) &nbsp;·&nbsp; <b>Uninstall mode</b> &nbsp;·&nbsp; <b>Wayland-ready</b> input method
</p>

---

## Quick Start

```bash
git clone https://github.com/hoangld89/ubuntu-install-apps.git
cd ubuntu-install-apps

# Interactive — pick and choose
./install-app.sh

# Or install everything at once
./install-app.sh --all

# Uninstall — same TUI, removes the apps you pick
./install-app.sh --uninstall
./install-app.sh --uninstall --all
```

> The script needs **bash** (it uses bash arrays). Run it with `./install-app.sh`
> or `bash install-app.sh` — **not** `sh install-app.sh`. If you do launch it with
> `sh`/dash, it auto re-execs under bash, so the old
> `sh: Syntax error: "(" unexpected` never happens.

> **Targets Ubuntu 24.04.** On a different release the script prints a warning
> and continues — most steps still work, but nothing is guaranteed.

---

## Interactive Menu

A flicker-free, leaf-green TUI rendered on the alternate screen. 35 apps live
under **5 collapsible groups**; the cursor row is marked with a green bar `▌`.
A 3D SETUP wordmark in leaf-green gradient greets you on launch.

```
   ███████╗ ███████╗ ████████╗ ██╗   ██╗ ██████╗
   ██╔════╝ ██╔════╝ ╚══██╔══╝ ██║   ██║ ██╔══██╗
   ███████╗ █████╗      ██║    ██║   ██║ ██████╔╝
   ╚════██║ ██╔══╝      ██║    ██║   ██║ ██╔═══╝
   ███████║ ███████╗    ██║    ╚██████╔╝ ██║
   ╚══════╝ ╚══════╝    ╚═╝     ╚═════╝  ╚═╝

      ubuntu setup · post-install toolkit
      from bare install to battle-ready

  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    ▾ ⚙ System & Shell                 ● 7/7
          ● APT Mirror            route apt through Vietnam's fastest mirrors [mirror.bizflycloud.vn]
          ● System Update         refresh sources & upgrade every package
          ● Swap File             8 GB swap · swappiness dialed to 10
          ● Terminal Kit          zsh · oh-my-zsh · tmux · fzf · rg · bat · jq
          ● Nerd Font             MesloLGS glyphs for prompts & icons
          ● eza                   a modern ls with icons & git awareness
          ● Fastfetch             system info at a glance, neofetch reborn
    ▾ ◆ Languages & IDEs               ◐ 8/9
          ● Node.js 24            managed by nvm, swap versions on the fly
          ● Bun                   all-in-one JS runtime & toolkit, blazing fast
          ● pnpm                  fast, disk-efficient package manager via corepack
          ● Yarn                  the classic JS package manager via corepack
  ▌       ○ .NET SDK              build & run cross-platform .NET [10]
          ● ABP CLI               ABP Studio CLI for building ABP apps
          ● VS Code               the editor that does it all
          ● Trae IDE              AI-native coding by ByteDance
          ● Claude Code           Anthropic's agentic dev CLI
    ▸ ▲ DevOps & Cloud                 ● 5/5
    ▸ ⬡ Databases                      ● 4/4
    ▸ ◎ Apps & Desktop                 ● 7/7

  ───────────────────────────────────────────────────────
  34/35 selected   █████████████████░

  ┌─ Navigate ─────┬─ Select ───────┬─ Actions ─────────┐
  │  ↑ ↓  Move     │  Space  Toggle │  d  .NET version  │
  │  ↵    Expand   │  a      All    │  m  APT mirror    │
  │                │  n      None   │  g  Input engine  │
  │                │                │  i  Install    ▸  │
  │                │                │  q  Quit          │
  └────────────────┴────────────────┴───────────────────┘
```

> **Seeing boxes (▯) instead of icons?** Your terminal font lacks the glyphs.
> Set the terminal font to a Nerd Font — **MesloLGS NF** is installed by the
> *Nerd Font* step. In the **VS Code** integrated terminal, set
> `"terminal.integrated.fontFamily": "MesloLGS NF"`. Or run with `--ascii`
> (or `MINT_ASCII=1`) for a plain-text menu that renders on any font.

### Groups

| # | Group | Apps |
|:-:|-------|------|
| 1 | **System & Shell** | APT mirror (Vietnam) · System update · Swap 8GB · Terminal tools (zsh, tmux, fzf…) · Nerd Font · eza · Fastfetch |
| 2 | **Languages & IDEs** | NVM/Node · Bun · pnpm · Yarn · .NET SDK · ABP CLI · VS Code · Trae · Claude Code |
| 3 | **DevOps & Cloud** | Terraform · Azure CLI · AzCopy · Docker · BrowserStack Local |
| 4 | **Databases** | MySQL client · PostgreSQL client · DBeaver · Navicat |
| 5 | **Apps & Desktop** | Chrome · Edge · Teams · Fcitx5 · Postman · Waydroid · VLC |

| Navigate | Select | Actions |
|----------|--------|---------|
| `↑` `↓` Move cursor | `Space` Toggle selection | `d` Configure .NET versions |
| `↵` Expand / collapse group | `a` Select all | `m` Change APT mirror |
| | `n` Deselect all | `g` Change input engine |
| | | **`i` Start install** · `q` Quit |

---

## What Gets Installed

### System

| Component | Details |
|-----------|---------|
| **APT mirror (Vietnam)** | Switches the Ubuntu archive mirror to a nearby Vietnam host (default `mirror.bizflycloud.vn`; press `m` to pick another). Works from **any** previous mirror, not just the default. Rewrites `sources.list` and the deb822 `ubuntu.sources`, leaves `security.ubuntu.com` untouched, and backs up each sources file (`*.bak`). Runs first so later steps download from the fast mirror |
| **System Update** | `apt update && upgrade && autoremove` |
| **Swap 8GB** | Creates `/swapfile` (8GB), `swappiness=10`, persists in `/etc/fstab` + `/etc/sysctl.conf` |

### Shell & Terminal

The **Terminal Kit** (zsh) runs **before** languages/runtimes so their config
lands in `.zshrc`. If you **skip** the Terminal Kit, that same config is written
to `.bashrc` instead — the default shell keeps working with every tool on PATH.

| Component | Details |
|-----------|---------|
| **zsh + Oh My Zsh** | Oh My Zsh with a minimal set of 3 plugins (see below). The script **asks** whether to make zsh your default shell — answer `n` to keep bash and just run `zsh` when you want it |
| **tmux** | Terminal multiplexer |
| **htop** | Interactive process monitor |
| **jq** / **yq** | JSON / YAML processors |
| **ripgrep** (`rg`) | Fast file search |
| **fzf** | Fuzzy finder |
| **bat** | `cat` with syntax highlighting |
| **eza** | Modern `ls` with icons & colors (`ls`/`ll`/`la`/`lt` aliases, written to the active shell rc) |
| **Fastfetch** | System info at a glance (neofetch successor). Tries apt, falls back to the official GitHub release `.deb` since it's not in the noble archive |
| **Nerd Font** | Installs **MesloLGS NF** to `/usr/local/share/fonts` and verifies it with `fc-list` so eza/terminal icons render. Set your terminal font to *MesloLGS NF* afterwards |

<details>
<summary><b>ZSH Plugins (3)</b></summary>

A deliberately minimal set — just the essentials. `zsh-syntax-highlighting` is loaded last (required by the plugin).

| Plugin | Type | Description |
|--------|------|-------------|
| git | built-in | Git aliases & status in prompt |
| zsh-autosuggestions | external | Fish-like command suggestions |
| zsh-syntax-highlighting | external | Real-time syntax coloring |

</details>

<details>
<summary><b>Shell Tool Integrations</b></summary>

A single `# --- Tool integrations ---` block is written to the active shell rc
(`.zshrc` when zsh is chosen, else `.bashrc`). Each entry is guarded so it is
auto-loaded when the tool is present and silently skipped otherwise:

- **NVM** &mdash; `$NVM_DIR/nvm.sh`
- **Bun** &mdash; `$HOME/.bun/bin` PATH
- **pnpm** &mdash; `$PNPM_HOME` (`$HOME/.local/share/pnpm`) PATH
- **.NET** &mdash; `DOTNET_ROOT` + `$HOME/.dotnet/tools` PATH
- **Azure CLI** &mdash; completions (`bashcompinit` under zsh only)
- **Claude Code** &mdash; `$HOME/.claude/bin` PATH
- **Cargo / Rust** &mdash; `$HOME/.cargo/env`

The block is shell-agnostic, so switching between bash and zsh keeps every
previously installed tool working.

</details>

### Languages & Runtime

| Component | Details |
|-----------|---------|
| **NVM + Node.js 24** | NVM v0.40.3 for current user, Node 24 as default |
| **Bun** | Official `bun.sh/install` script, per-user (`~/.bun`); `bun`/`bunx` on PATH via the Tool-integrations block |
| **pnpm** | Enabled via **corepack** (bundled with Node); falls back to the standalone `get.pnpm.io` installer when Node isn't present |
| **Yarn** | Enabled via **corepack** (`yarn@stable`); falls back to `npm install -g yarn` when corepack isn't present |
| **.NET SDK** | Default: v10. Press `d` to select multiple (e.g. `8 9 10`). Falls back to the Microsoft install script if unavailable in apt |
| **ABP CLI** | `Volo.Abp.Studio.Cli` dotnet global tool (`~/.dotnet/tools`); requires the .NET SDK. Provides the `abp` command |

### Browser

| Component | Source |
|-----------|--------|
| **Google Chrome** | `.deb` direct download |
| **Microsoft Edge** | Microsoft apt repo |

### Communication

| Component | Source | Details |
|-----------|--------|---------|
| **Teams for Linux** | [GitHub releases](https://github.com/IsmaelMartinez/teams-for-linux) | Unofficial Electron wrapper (Microsoft discontinued native Teams for Linux in 2022) |

### IDE & Editor

| Component | Source |
|-----------|--------|
| **Visual Studio Code** | Microsoft apt repo |
| **Trae IDE** | `.deb` from CDN |

### DevOps & Infrastructure

| Component | Source | Details |
|-----------|--------|---------|
| **Terraform** | HashiCorp apt repo | Infrastructure as Code |
| **Azure CLI** | Microsoft apt repo | Azure resource management |
| **AzCopy** | `aka.ms` v10 tarball | Azure Storage / Blob transfer CLI. Binary installed to `/usr/local/bin/azcopy` |
| **Docker + Compose** | Docker apt repo | Docker CE, Compose plugin, buildx. Adds user to `docker` group |
| **BrowserStack Local** | Official zip | Secure tunnel binary for local cross-browser testing. Installed to `/usr/local/bin/BrowserStackLocal`; run with `--key <ACCESS_KEY>` |

### Database Tools

| Component | Source | Details |
|-----------|--------|---------|
| **MySQL Client** | apt | `mysqldump`, `mysql` CLI |
| **PostgreSQL Client** | apt | `pg_dump`, `pg_restore`, `psql` |
| **DBeaver Community** | `.deb` latest | Universal database GUI |
| **Navicat Premium Lite** | AppImage | Installed to `/opt`, available as `navicat` command |

### Apps & Desktop

| Component | Source | Details |
|-----------|--------|---------|
| **Fcitx5 (Vietnamese)** | apt / third-party repo | Vietnamese input. Press `g` to pick the engine: **Unikey** (default) or **Bamboo** (both from Ubuntu's archive), or **Lotus** (third-party fcitx5 apt repo). Auto-configures IM env vars, autostart & profile |
| **Postman** | Official tarball | API client. Unpacked to `/opt/Postman`, `postman` command + `.desktop` launcher |
| **Waydroid** | Official apt repo | Run Android apps in a container. Needs a Wayland session + kernel `binder`; run `waydroid init` once after install |
| **VLC** | apt | Media player |

### AI

| Component | Source | Details |
|-----------|--------|---------|
| **Claude Code** | Official installer (`claude.ai/install.sh`) | AI coding assistant. No Node.js dependency |

---

## Wayland Input Method

Ubuntu 24.04 defaults to a **Wayland** GNOME session. Chromium/Electron apps
need extra flags before fcitx5 can type into them, so their `.desktop` launchers
are patched with:

```
--enable-features=UseOzonePlatform --ozone-platform-hint=auto --enable-wayland-ime --wayland-text-input-version=3
```

`--ozone-platform-hint=auto` picks Wayland when available and falls back to X11,
so the flags are safe on either session. This is applied to **Chrome, Edge,
VS Code, Teams, Trae, and Postman**, and `ELECTRON_OZONE_PLATFORM_HINT=auto` is
added to `/etc/environment` for other Electron apps.

---

## Idempotent &mdash; Safe to Re-run

The script detects already-installed tools and skips them:

```
[OK] Google Chrome already installed, skipping
[OK] Docker already installed, skipping
[OK] NVM already installed, skipping
[INFO] Installing Terraform...          ← only installs what's missing
```

| Install method | Skip behavior |
|----------------|---------------|
| `.deb` / AppImage / curl downloads | Checks binary or install path before downloading |
| apt packages | `apt install` is natively idempotent |
| Oh My Zsh + plugins | Checks `~/.oh-my-zsh` directory |
| shell rc config blocks | Checks for marker before appending |
| Swap | Checks existing size matches 8GB |

---

## Uninstall

```bash
./install-app.sh --uninstall          # same TUI — pick what to remove
./install-app.sh --uninstall --all    # remove everything
```

Uninstall opens the **same menu** as install, but every app starts **unselected**
and the action becomes **Remove**. After you press `i`, a single confirmation
gate (`y/N`) protects against accidental removal. Each app has a dedicated
`undo_<app>` routine that reverses what its installer did:

- **apt packages** are purged (`apt-get purge`), then `apt autoremove` sweeps orphans
- **APT repos & GPG keys** added under `sources.list.d` / `keyrings` are deleted
- **Downloaded binaries** (`azcopy`, `BrowserStackLocal`, Postman, Navicat, etc.) are removed
- **shell rc blocks** are stripped from both `.zshrc` and `.bashrc` by their `# --- … ---` markers
- **Mirror** is restored from the `*.bak` backups created during install

What it deliberately **leaves alone** (to avoid data loss), warning you instead:

- `git` & `curl` (too many other things depend on them)
- `/var/lib/docker` (your images, volumes, containers)
- `~/.claude` config and a completed system `update`/`upgrade` (cannot be rolled back)

---

## Install Order

The install order is deliberate:

```
1. APT mirror         ─── switch to a nearby Vietnam mirror FIRST
2. System Update      ─── apt cache fresh (now from the fast mirror)
3. Swap               ─── memory ready
4. Terminal + ZSH     ─── shell rc exists BEFORE anything writes to it
5-8. Node/Bun/pnpm/Yarn ── JS runtimes; config goes into the active shell rc
9. .NET SDK + ABP CLI ─── DOTNET_ROOT picked up by the rc; abp tool after SDK
...  Browsers, editors, infra, databases
...  Fcitx5, Postman, Waydroid, VLC ─── apps & desktop
last. Claude Code     ─── AI tools (no Node.js dependency)
```

---

## Post-install

Some changes require a **re-login** or **reboot**:

| Component | Requires |
|-----------|----------|
| Zsh (default shell) | Re-login |
| Docker group | Re-login |
| Fcitx5 / Wayland IME | Re-login |
| Waydroid | `waydroid init` + Wayland session |
| Swap | Active immediately |

Quick verification:

```bash
echo $SHELL                     # → /usr/bin/zsh (if you set it)
node -v                         # → v24.x.x
pnpm -v                         # → x.x.x
yarn -v                         # → x.x.x
dotnet --list-sdks              # → 10.0.xxx
abp --version                   # → x.x.x
terraform -v                    # → Terraform vX.X.X
az version                      # → X.X.X
docker run hello-world          # → Hello from Docker!
claude --version                # → claude X.X.X
```

---

## Customization

### Adding a new app

1. Add to the `APPS` array (format `"key|Name::tagline|default_on"`):
   ```bash
   "myapp|My Application::a one-line tagline|1"    # 1 = on by default
   ```

2. Add a `do_myapp()` with an idempotent skip check:
   ```bash
   do_myapp() {
       if command -v myapp &>/dev/null; then
           success "My Application already installed, skipping"
           return
       fi
       info "Installing My Application..."
       # install commands
       success "My Application installed"
   }
   ```

3. Add a matching `undo_myapp()` so it can be uninstalled too:
   ```bash
   undo_myapp() {
       info "Removing My Application..."
       apt_purge myapp            # or rm the binary / repo it installed
       success "My Application removed"
   }
   ```

4. Add the `myapp` key to the relevant group's comma list in the `APP_GROUPS`
   array so it shows up under that group in the menu.

### Changing swap size

Edit the size and check in `do_swap()`:
```bash
fallocate -l 16G /swapfile
# Also update the size check: $((16 * 1024 * 1024 * 1024))
```

---

## System Requirements

| | |
|---|---|
| **OS** | Ubuntu 24.04 (noble) |
| **Arch** | amd64 (x86_64) |
| **Privileges** | Root (`sudo`) |
| **Network** | Internet connection required |

---

## License

MIT
