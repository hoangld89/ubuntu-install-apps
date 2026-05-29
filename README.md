<p align="center">
  <img src="https://img.shields.io/badge/Ubuntu-22.04%20|%2024.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" />
  <img src="https://img.shields.io/badge/Linux%20Mint-21%20|%2022-87CF3E?style=for-the-badge&logo=linuxmint&logoColor=white" />
  <img src="https://img.shields.io/badge/Shell-Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white" />
</p>

<h1 align="center">MINT &mdash; Post-install Setup</h1>

<p align="center">
  MINT is an interactive post-install setup for fresh Ubuntu / Linux Mint machines.<br/>
  Pick what you need from a TUI menu &mdash; everything else is automatic.
</p>

<p align="center">
  <b>22 apps</b> &nbsp;·&nbsp; <b>Idempotent</b> (safe to re-run) &nbsp;·&nbsp; <b>Mint-compatible</b> (auto-detects Ubuntu codename)
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
```

> The script needs **bash** (it uses bash arrays). Run it with `./install-app.sh`
> or `bash install-app.sh` — **not** `sh install-app.sh`. If you do launch it with
> `sh`/dash, it now auto re-execs under bash, so the old
> `sh: Syntax error: "(" unexpected` no longer happens.

---

## Interactive Menu

A flicker-free, Linux Mint-themed TUI (leaf-green accents + gradient rule)
rendered on the alternate screen. 22 apps live under **5 collapsible groups**;
the cursor row is marked with a green bar `▌`. A 3D MINT wordmark in
leaf-green gradient greets you on launch.

```
   ███╗   ███╗ ██╗ ███╗   ██╗ ████████╗
   ████╗ ████║ ██║ ████╗  ██║ ╚══██╔══╝
   ██╔████╔██║ ██║ ██╔██╗ ██║    ██║
   ██║╚██╔╝██║ ██║ ██║╚██╗██║    ██║
   ██║ ╚═╝ ██║ ██║ ██║ ╚████║    ██║
   ╚═╝     ╚═╝ ╚═╝ ╚═╝  ╚═══╝    ╚═╝

      mint setup · post-install toolkit
      fresh machine · fresh start

  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    ▾ ⚙ System & Shell                 ● 4/4
          ● APT mirror → Vietnam (faster downloads) [vn.archive.ubuntu.com]
          ● System Update & Upgrade
          ● Swap 8GB + swappiness 10
          ● Terminal tools (zsh, tmux, fzf…)
    ▾ ◆ Dev & IDE                      ◐ 4/5
          ● NVM + Node.js 24
  ▌       ○ .NET SDK (chọn version) [10]
          ● Visual Studio Code
          ● Trae IDE
          ● Claude Code
    ▸ ▲ DevOps & Cloud                 ● 4/4
    ▸ ⬡ Database                       ● 4/4
    ▸ ◎ Desktop & Apps                 ● 5/5

  ───────────────────────────────────────────────────────
  21/22 selected   ████████████████░░

  ┌─ Navigate ─────┬─ Select ───────┬─ Actions ─────────┐
  │  ↑ ↓  Move     │  Space  Toggle │  d  .NET version  │
  │  ↵    Expand   │  a      All    │  m  APT mirror    │
  │                │  n      None   │  i  Install    ▸  │
  │                │                │  q  Quit          │
  └────────────────┴────────────────┴───────────────────┘
```

### Groups

| # | Group | Apps |
|:-:|-------|------|
| 1 | **System & Shell** | APT mirror (Vietnam) · System update · Swap 8GB · Terminal tools (zsh, tmux, fzf…) |
| 2 | **Dev & IDE** | NVM/Node · .NET SDK · VS Code · Trae · Claude Code |
| 3 | **DevOps & Cloud** | Terraform · Azure CLI · AzCopy · Docker |
| 4 | **Database** | MySQL client · PostgreSQL client · DBeaver · Navicat |
| 5 | **Desktop & Apps** | Chrome · Edge · Teams · Fcitx5 · VLC |

| Navigate | Select | Actions |
|----------|--------|---------|
| `↑` `↓` Move cursor | `Space` Toggle selection | `d` Configure .NET versions |
| `↵` Expand / collapse group | `a` Select all | `m` Change APT mirror |
| | `n` Deselect all | **`i` Start install** |
| | | `q` Quit |

---

## What Gets Installed

### System

| Component | Details |
|-----------|---------|
| **APT mirror (Vietnam)** | Switches the Ubuntu archive mirror to a nearby Vietnam host (default `vn.archive.ubuntu.com`; press `m` to pick BizFly Cloud / ClearSky). Works from **any** previous mirror, not just the default. Leaves `security.ubuntu.com` untouched and backs up each sources file (`*.bak`). Works on Ubuntu (`sources.list`, deb822 `ubuntu.sources`) **and Linux Mint** (`official-package-repositories.list`). Runs first so later steps download from the fast mirror |
| **System Update** | `apt update && upgrade && autoremove` |
| **Swap 8GB** | Creates `/swapfile` (8GB), `swappiness=10`, persists in `/etc/fstab` + `/etc/sysctl.conf` |

### Shell & Terminal

ZSH is installed **before** languages/runtimes so that NVM, .NET, etc. automatically write their config into `.zshrc`.

| Component | Details |
|-----------|---------|
| **zsh + Oh My Zsh** | Oh My Zsh with 14 plugins (see below). The script **asks** whether to make zsh your default shell — answer `n` to keep bash and just run `zsh` when you want it |
| **tmux** | Terminal multiplexer |
| **htop** | Interactive process monitor |
| **jq** / **yq** | JSON / YAML processors |
| **ripgrep** (`rg`) | Fast file search |
| **fzf** | Fuzzy finder |
| **bat** | `cat` with syntax highlighting |

<details>
<summary><b>ZSH Plugins (14)</b></summary>

| Plugin | Type | Description |
|--------|------|-------------|
| git | built-in | Git aliases & status in prompt |
| zsh-autosuggestions | external | Fish-like command suggestions |
| zsh-syntax-highlighting | external | Real-time syntax coloring |
| zsh-completions | external | Extra completion definitions |
| zsh-history-substring-search | external | Type partial command + `↑` to search history |
| z | built-in | Jump to frequently used directories |
| fzf | built-in | Fuzzy search integration |
| sudo | built-in | Press `Esc` twice to prepend `sudo` |
| aliases | built-in | Alias management utilities |
| docker | built-in | Docker completions & aliases |
| docker-compose | built-in | Docker Compose completions |
| kubectl | built-in | Kubernetes completions & aliases |
| terraform | built-in | Terraform completions |

</details>

<details>
<summary><b>ZSH Tool Integrations</b></summary>

`.zshrc` includes conditional blocks for tools that may write config to `.bashrc` on install. These are auto-loaded if the tool is present, and silently skipped if not:

- **NVM** &mdash; `$NVM_DIR/nvm.sh`
- **.NET** &mdash; `DOTNET_ROOT` + `$HOME/.dotnet/tools` PATH
- **Azure CLI** &mdash; bash completions via `bashcompinit`
- **Claude Code** &mdash; `$HOME/.claude/bin` PATH
- **Cargo / Rust** &mdash; `$HOME/.cargo/env`

This ensures switching from bash to zsh doesn't break any previously installed tools.

</details>

### Languages & Runtime

| Component | Details |
|-----------|---------|
| **NVM + Node.js 24** | NVM v0.40.3 for current user, Node 24 as default |
| **.NET SDK** | Default: v10. Press `d` to select multiple (e.g. `8 9 10`). Falls back to Microsoft install script if unavailable in apt |

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

### Database Tools

| Component | Source | Details |
|-----------|--------|---------|
| **MySQL Client** | apt | `mysqldump`, `mysql` CLI |
| **PostgreSQL Client** | apt | `pg_dump`, `pg_restore`, `psql` |
| **DBeaver Community** | `.deb` latest | Universal database GUI |
| **Navicat Premium Lite** | AppImage | Installed to `/opt`, available as `navicat` command |

### Productivity & AI

| Component | Source | Details |
|-----------|--------|---------|
| **Fcitx5 + Unikey** | apt | Vietnamese input. Auto-configures env vars & autostart |
| **VLC** | apt | Media player |
| **Claude Code** | Official installer (`claude.ai/install.sh`) | AI coding assistant. No Node.js dependency |

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
| `.zshrc` config blocks | Checks for marker before appending |
| Swap | Checks existing size matches 8GB |

---

## Linux Mint Compatibility

Linux Mint codenames (`wilma`, `victoria`, etc.) don't match Ubuntu repo codenames. The script auto-detects the underlying Ubuntu codename:

```
Mint 22 (Wilma) → Ubuntu 24.04 (noble)
Mint 21 (Victoria) → Ubuntu 22.04 (jammy)
```

This fix applies to: .NET SDK, Azure CLI, Terraform, Docker, VS Code, and Edge repos.

The **APT mirror** step is also Mint-aware: it rewrites the `archive.ubuntu.com`
host inside Mint's `/etc/apt/sources.list.d/official-package-repositories.list`
(as well as Ubuntu's `sources.list` / deb822 `ubuntu.sources`), while leaving the
Mint repos (`packages.linuxmint.com`) and `security.ubuntu.com` untouched.

---

## Install Order

The install order is deliberate:

```
1. APT mirror         ─── switch to a nearby Vietnam mirror FIRST
2. System Update      ─── apt cache fresh (now from the fast mirror)
3. Swap               ─── memory ready
4. Terminal + ZSH     ─── .zshrc exists BEFORE anything writes to it
5. NVM + Node.js      ─── config goes into .zshrc (not just .bashrc)
6. .NET SDK           ─── DOTNET_ROOT picked up by .zshrc
7-8. Chrome, Edge     ─── browsers
9. Teams              ─── communication
10-11. VS Code, Trae  ─── editors
12-15. TF, AZ, AzCopy, Docker ─── infra tools
16-19. DB tools       ─── database clients
20-21. Fcitx5, VLC    ─── productivity
22. Claude Code       ─── AI tools (no longer needs Node.js)
```

---

## Post-install

Some changes require a **re-login** or **reboot**:

| Component | Requires |
|-----------|----------|
| Zsh (default shell) | Re-login |
| Docker group | Re-login |
| Fcitx5 | Re-login |
| Swap | Active immediately |

Quick verification:

```bash
echo $SHELL                     # → /usr/bin/zsh
node -v                         # → v24.x.x
dotnet --list-sdks              # → 10.0.xxx
terraform -v                    # → Terraform vX.X.X
az version                      # → X.X.X
docker run hello-world          # → Hello from Docker!
claude --version                # → claude X.X.X
```

---

## Customization

### Adding a new app

1. Add to `APPS` array:
   ```bash
   "myapp|My Application|1"    # 1 = on by default
   ```

2. Add matching function + skip check:
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

3. Add `myapp` to the `case` block in `print_menu()` for group assignment.

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
| **OS** | Ubuntu 22.04+ / Linux Mint 21+ |
| **Arch** | amd64 (x86_64) |
| **Privileges** | Root (`sudo`) |
| **Network** | Internet connection required |

---

## License

MIT
