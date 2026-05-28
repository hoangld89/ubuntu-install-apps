<p align="center">
  <img src="https://img.shields.io/badge/Ubuntu-22.04%20|%2024.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" />
  <img src="https://img.shields.io/badge/Linux%20Mint-21%20|%2022-87CF3E?style=for-the-badge&logo=linuxmint&logoColor=white" />
  <img src="https://img.shields.io/badge/Shell-Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white" />
</p>

<h1 align="center">Ubuntu / Linux Mint &mdash; Post-install Setup Script</h1>

<p align="center">
  Interactive post-install script for fresh Ubuntu / Linux Mint machines.<br/>
  Pick what you need from a TUI menu &mdash; everything else is automatic.
</p>

<p align="center">
  <b>20 apps</b> &nbsp;·&nbsp; <b>Idempotent</b> (safe to re-run) &nbsp;·&nbsp; <b>Mint-compatible</b> (auto-detects Ubuntu codename)
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

---

## Interactive Menu

```
  ╭─────────────────────────────────────────────────────╮
  │                                                     │
  │     Ubuntu / Linux Mint                             │
  │     Post-install Setup                              │
  │                                                     │
  ╰─────────────────────────────────────────────────────╯

 ▶▶ ▸ ⚙ System                              ● 2/2
     ▸ ⌨ Shell & Terminal                    ● 1/1
     ▸ ◆ Languages & Runtime                 ● 2/2
     ▾ ◎ Browser                             ◐ 1/2
        ▶▶ ● Google Chrome
            ○ Microsoft Edge
     ▸ ✉ Communication                       ● 1/1
     ▸ ✎ IDE & Editor                        ● 2/2
     ▸ ▲ DevOps & Infrastructure             ● 3/3
     ▸ ⬡ Database Tools                      ● 4/4
     ▸ ★ Productivity                        ● 2/2
     ▸ ◈ AI Tools                            ● 1/1

  ─────────────────────────────────────────────────────
  19/20 selected

  ↑↓ Move  Space Toggle  Enter Expand/Collapse  d .NET ver
  a All  n None  q Quit  i → Install
```

| Key | Action |
|:---:|--------|
| `↑` `↓` | Navigate groups / items |
| `Space` | Toggle group (all items) or single item |
| `Enter` | Expand / collapse group |
| `a` / `n` | Select all / Deselect all |
| `d` | Configure .NET versions (e.g. `8 9 10`) |
| `i` | Start installation |
| `q` | Quit |

---

## What Gets Installed

### System

| Component | Details |
|-----------|---------|
| **System Update** | `apt update && upgrade && autoremove` |
| **Swap 8GB** | Creates `/swapfile` (8GB), `swappiness=10`, persists in `/etc/fstab` + `/etc/sysctl.conf` |

### Shell & Terminal

ZSH is installed **before** languages/runtimes so that NVM, .NET, etc. automatically write their config into `.zshrc`.

| Component | Details |
|-----------|---------|
| **zsh + Oh My Zsh** | New default shell with 14 plugins (see below) |
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

---

## Install Order

The install order is deliberate:

```
1. System Update      ─── apt cache fresh
2. Swap               ─── memory ready
3. Terminal + ZSH     ─── .zshrc exists BEFORE anything writes to it
4. NVM + Node.js      ─── config goes into .zshrc (not just .bashrc)
5. .NET SDK           ─── DOTNET_ROOT picked up by .zshrc
6-7. Chrome, Edge     ─── browsers
8. Teams              ─── communication
9-10. VS Code, Trae   ─── editors
11-13. TF, AZ, Docker ─── infra tools
14-17. DB tools       ─── database clients
18-19. Fcitx5, VLC    ─── productivity
20. Claude Code       ─── AI tools (no longer needs Node.js)
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
