<p align="center">
  <img src="https://img.shields.io/badge/Ubuntu-22.04%20|%2024.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" />
  <img src="https://img.shields.io/badge/Linux%20Mint-21%20|%2022-87CF3E?style=for-the-badge&logo=linuxmint&logoColor=white" />
  <img src="https://img.shields.io/badge/Shell-Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white" />
</p>

# Ubuntu / Linux Mint &mdash; Post-install Setup Script

An interactive post-install script that sets up a fresh Ubuntu or Linux Mint machine with developer tools, system tuning, and productivity apps. Pick what you need from a TUI menu before anything gets installed.

---

## Quick Start

```bash
git clone https://github.com/hoangld89/ubuntu-install-apps.git
cd ubuntu-install-apps

# Interactive mode — pick and choose
sudo bash install.sh

# Or install everything at once
sudo bash install.sh --all
```

---

## Interactive Menu

Running `sudo bash install.sh` displays a grouped, toggleable menu:

```
╔══════════════════════════════════════════════════╗
║   Ubuntu / Linux Mint — App Installer            ║
╚══════════════════════════════════════════════════╝

       ── System ──
 ▸ [x] System Update & Upgrade
   [x] Swap 8GB + swappiness 10

       ── Browser & Communication ──
   [x] Google Chrome
   [x] Microsoft Teams

       ── IDE & Editor ──
   [x] Visual Studio Code
   [x] Trae IDE

       ── Languages & Runtime ──
   [x] NVM + Node.js 24
   [x] .NET SDK (chọn version)          [versions: 10]

       ── Terminal Utilities ──
   [x] Terminal tools (zsh, tmux, htop, jq, yq, rg, fzf, bat)

       ── DevOps & Infrastructure ──
   [x] Terraform
   [x] Azure CLI
   [x] Docker + Docker Compose

       ── Database Tools ──
   [x] MySQL Client (mysqldump)
   [x] PostgreSQL Client (pg_dump)
   [x] DBeaver Community
   [x] Navicat Premium Lite

       ── Productivity ──
   [x] Fcitx5 (Vietnamese input)
   [x] VLC Media Player
   [x] Claude CLI

  ↑↓ Di chuyển  Space Chọn/bỏ  a Tất cả  n Bỏ tất cả
  d  .NET ver   Enter Cài đặt  q Thoát
```

### Controls

| Key | Action |
|-----|--------|
| `↑` `↓` | Navigate up/down between items |
| `Space` | Toggle selected item on/off |
| `a` | Select all |
| `n` | Deselect all |
| `d` | Configure .NET SDK versions (e.g. type `8 9 10`) |
| `Enter` | Start installation |
| `q` | Quit without installing |

---

## What Gets Installed

### System

| # | Component | Details |
|---|-----------|---------|
| 1 | **System Update** | `apt update && upgrade && autoremove` |
| 2 | **Swap 8GB** | Creates `/swapfile` (8GB), sets `swappiness=10`, persists via `/etc/fstab` and `/etc/sysctl.conf` |

### Browser & Communication

| # | Component | Source | Details |
|---|-----------|--------|---------|
| 3 | **Google Chrome** | `.deb` direct download | Stable channel |
| 4 | **Microsoft Teams** | Microsoft apt repo | Falls back to `.deb` if repo unavailable |

### IDE & Editor

| # | Component | Source |
|---|-----------|--------|
| 5 | **Visual Studio Code** | Microsoft apt repo |
| 6 | **Trae IDE** | `.deb` from CDN |

### Languages & Runtime

| # | Component | Details |
|---|-----------|---------|
| 7 | **NVM + Node.js 24** | Installs NVM v0.40.3 for the current user, sets Node 24 as default |
| 8 | **.NET SDK** | Default: version 10. Press `d` in menu to select multiple versions (e.g. `8 9 10`). Auto-falls back to Microsoft install script if version is unavailable in apt |

### Terminal Utilities

| # | Component |
|---|-----------|
| 9 | **Terminal tools** |

<details>
<summary><b>Included tools (click to expand)</b></summary>

| Tool | Description |
|------|-------------|
| **zsh** | New default shell (replaces bash) |
| **Oh My Zsh** | Zsh configuration framework with plugins |
| **zsh-autosuggestions** | Fish-like command suggestions |
| **zsh-syntax-highlighting** | Real-time syntax coloring |
| **tmux** | Terminal multiplexer, persists sessions over SSH |
| **htop** | Interactive process/resource monitor |
| **jq** | JSON processor for the command line |
| **yq** | YAML processor (similar to jq) |
| **ripgrep (`rg`)** | Blazing fast file content search |
| **fzf** | Fuzzy finder for files, history, and pipes |
| **bat** | `cat` with syntax highlighting and line numbers |

</details>

### DevOps & Infrastructure

| # | Component | Source | Details |
|---|-----------|--------|---------|
| 10 | **Terraform** | HashiCorp apt repo | Infrastructure as Code |
| 11 | **Azure CLI** | Microsoft apt repo | Manage Azure resources |
| 12 | **Docker + Compose** | Docker apt repo | Docker CE, Compose plugin, buildx. Adds current user to `docker` group |

### Database Tools

| # | Component | Source | Details |
|---|-----------|--------|---------|
| 13 | **MySQL Client** | apt | `mysql-client` package — includes `mysqldump`, `mysql` CLI |
| 14 | **PostgreSQL Client** | apt | `postgresql-client` package — includes `pg_dump`, `pg_restore`, `psql` CLI |
| 15 | **DBeaver Community** | `.deb` latest | Universal database GUI client |
| 16 | **Navicat Premium Lite** | AppImage | Installed to `/opt`, available as `navicat` command and in app menu |

### Productivity

| # | Component | Source | Details |
|---|-----------|--------|---------|
| 17 | **Fcitx5 + Unikey** | apt | Vietnamese input method. Auto-configures environment variables and autostart |
| 18 | **VLC** | apt | Media player |
| 19 | **Claude CLI** | npm (global) | AI assistant in terminal. Requires NVM/Node (#7) to be installed first |

---

## Dependencies

The script installs items in menu order. One dependency to note:

```
NVM + Node.js (#7)  ──>  Claude CLI (#19)
```

> If Claude CLI is selected without NVM, the script will warn and skip it.

---

## Post-install

Some changes require a **re-login** or **reboot** to take effect:

| Component | Requires |
|-----------|----------|
| Docker group | Re-login |
| Fcitx5 | Re-login |
| Zsh (default shell) | Re-login |
| Swap | Active immediately |

Quick verification after re-login:

```bash
docker run hello-world          # Docker working?
node -v                         # Node version?
dotnet --list-sdks              # .NET SDKs?
terraform -v                    # Terraform?
az version                      # Azure CLI?
mysqldump --version             # MySQL client?
pg_dump --version               # PostgreSQL client?
echo $SHELL                     # Switched to zsh?
```

---

## System Requirements

- **OS**: Ubuntu 22.04+ or Linux Mint 21+
- **Arch**: amd64 (x86_64)
- **Privileges**: Root (`sudo`)
- **Network**: Internet connection required

---

## Customization

### Adding a new app

1. Add an entry to the `APPS` array in `install.sh`:
   ```bash
   APPS=(
       ...
       "myapp|My Application|1"    # 1 = selected by default, 0 = off
   )
   ```

2. Add a matching `do_myapp()` function:
   ```bash
   do_myapp() {
       info "Installing My Application..."
       # install commands here
       success "My Application installed"
   }
   ```

### Changing swap size

Edit the `fallocate` line in `do_swap()`:
```bash
fallocate -l 16G /swapfile    # change from 8G to 16G
```

---

## License

MIT
