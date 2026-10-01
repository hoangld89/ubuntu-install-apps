<p align="center">
  <img src="https://img.shields.io/badge/Ubuntu-26.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" />
  <img src="https://img.shields.io/badge/Shell-Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white" />
</p>

<h1 align="center">SETUP &mdash; Ubuntu 26.04 Post-install Toolkit</h1>

<p align="center">
  An interactive post-install setup for a fresh Ubuntu 26.04 (resolute) machine.<br/>
  Pick what you need from a TUI menu &mdash; everything else is automatic.
</p>

<p align="center">
  <b>36 apps</b> &nbsp;·&nbsp; <b>Idempotent</b> (safe to re-run) &nbsp;·&nbsp; <b>Uninstall mode</b> &nbsp;·&nbsp; <b>Wayland-ready</b> input method
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

# Keep bash as the login shell (Terminal Kit otherwise switches to zsh)
./install-app.sh --all --keep-shell

# Uninstall — same TUI, removes the apps you pick
./install-app.sh --uninstall
./install-app.sh --uninstall --all
```

> The script needs **bash** (it uses bash arrays). Run it with `./install-app.sh`
> or `bash install-app.sh` — **not** `sh install-app.sh`. If you do launch it with
> `sh`/dash, it auto re-execs under bash, so the old
> `sh: Syntax error: "(" unexpected` never happens.

> **Targets Ubuntu 26.04.** On a different release the script prints a warning
> and continues — most steps still work, but nothing is guaranteed.

---

## Interactive Menu

A flicker-free, leaf-green TUI rendered on the alternate screen. 36 apps live
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

    ▾ ⚙ System & Shell                 ● 8/8
          ● APT Mirror            route apt through Vietnam's fastest mirrors [mirror.bizflycloud.vn]
          ● System Update         refresh sources & upgrade every package
          ● Swap File             8 GB swap · swappiness dialed to 10
          ● Terminal Kit          zsh · oh-my-zsh · tmux · fzf · rg · bat · jq
          ● Fonts                 Nerd Font glyphs + Vietnamese web fonts (Facebook/Chrome)
          ● MS Fonts              Arial, Times New Roman, Calibri & ClearType fonts
          ● eza                   a modern ls with icons & git awareness
          ● Fastfetch             system info at a glance, neofetch reborn
    ▾ ◆ Languages & IDEs               ◐ 8/9
          ● Node.js LTS           managed by nvm, swap versions on the fly
          ● Bun                   all-in-one JS runtime & toolkit, blazing fast
          ● pnpm                  fast, disk-efficient package manager via corepack
          ● Yarn 4                the Berry JS package manager via corepack
  ▌       ○ .NET SDK              build & run cross-platform .NET [10]
          ● ABP CLI               ABP Studio CLI for building ABP apps
          ● VS Code               the editor that does it all
          ● Trae IDE              AI-native coding by ByteDance
          ● Claude Code           Anthropic's agentic dev CLI
    ▸ ▲ DevOps & Cloud                 ● 5/5
    ▸ ⬡ Databases                      ● 4/4
    ▸ ◎ Apps & Desktop                 ● 10/10

  ───────────────────────────────────────────────────────
  35/36 selected   █████████████████░

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
> *Fonts* step. In the **VS Code** integrated terminal, set
> `"terminal.integrated.fontFamily": "MesloLGS NF"`. Or run with `--ascii`
> (or `MINT_ASCII=1`) for a plain-text menu that renders on any font.

### Groups

| # | Group | Apps |
|:-:|-------|------|
| 1 | **System & Shell** (8) | APT mirror (Vietnam) · System update · Swap 8GB · Terminal Kit (zsh, tmux, fzf…) · Fonts (Nerd Font + Vietnamese web fonts) · MS Fonts · eza · Fastfetch |
| 2 | **Languages & IDEs** (9) | Node.js LTS (nvm) · Bun · pnpm · Yarn 4 · .NET SDK · ABP CLI · VS Code · Trae · Claude Code |
| 3 | **DevOps & Cloud** (5) | Terraform · Azure CLI · AzCopy · Docker · BrowserStack Local |
| 4 | **Databases** (4) | MySQL client · PostgreSQL client · DBeaver · Navicat |
| 5 | **Apps & Desktop** (10) | Chrome · Edge · Teams · Fcitx5 · Postman · Waydroid · VLC · OBS Studio · AnyDesk · TeamViewer |

| Navigate | Select | Actions |
|----------|--------|---------|
| `↑` `↓` / `k` `j` Move cursor | `Space` Toggle selection | `d` Configure .NET versions (8, 9, 10) |
| `↵` Expand / collapse group | `a` Select all | `m` Change APT mirror |
| | `n` Deselect all | `g` Change input engine |
| | | **`i` Start install** · `q` Quit |

---

## What Gets Installed

### System

| Component | Details |
|-----------|---------|
| **APT mirror (Vietnam)** | Switches the Ubuntu archive mirror to a nearby Vietnam host (default `mirror.bizflycloud.vn`; press `m` to pick another). Works from **any** previous mirror, not just the default. Rewrites `sources.list` and the deb822 `ubuntu.sources`, leaves `security.ubuntu.com` untouched, and backs up each sources file (`*.bak`). Runs first so later steps download from the fast mirror |
| **System Update** | `apt-get update && upgrade --with-new-pkgs && autoremove`, keeping your existing config files on conffile prompts. If the new mirror's `apt-get update` fails, the mirror step restores the previous sources |
| **Swap 8GB** | Grows the installer's `/swap.img` to 8GB (or creates `/swapfile` if none), `swappiness=10`, persists in `/etc/fstab` + `/etc/sysctl.d/99-swappiness.conf` |

### Shell & Terminal

Runtime config (PATH, nvm, aliases) is written to `.bashrc`, and also to
`.zshrc` when zsh is installed, so every tool works in whichever shell you open.
The **Terminal Kit** (zsh) runs **before** languages/runtimes so `.zshrc`
exists by the time they write to it.

| Component | Details |
|-----------|---------|
| **zsh + Oh My Zsh** | Oh My Zsh with a minimal set of 3 plugins (see below). zsh becomes your login shell; pass `--keep-shell` to keep bash and just run `zsh` when you want it |
| **tmux** | Terminal multiplexer |
| **htop** | Interactive process monitor |
| **jq** / **yq** | JSON / YAML processors |
| **ripgrep** (`rg`) | Fast file search |
| **fzf** | Fuzzy finder |
| **bat** | `cat` with syntax highlighting |
| **eza** | Modern `ls` with icons & colors (`ls`/`ll`/`la`/`lt` aliases, written to the active shell rc) |
| **eza** / **Fastfetch** | Both come from the Ubuntu 26.04 archive |
| **Fonts** | Installs the 4 **MesloLGS NF** faces to `/usr/local/share/fonts` (each download lands in a temp file first) and points gnome-terminal at it, plus Noto/Liberation fonts for correct Vietnamese diacritics in browsers |
| **MS Fonts** | `ttf-mscorefonts-installer` (Arial, Times New Roman, …; reinstalled when the package is present but its fonts are missing) plus Calibri/ClearType faces extracted from PowerPoint Viewer |

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

A single `# --- Tool integrations ---` block is written to `.bashrc`, and to
`.zshrc` when zsh is installed. Each entry is guarded so it is
auto-loaded when the tool is present and silently skipped otherwise:

- **NVM** &mdash; `$NVM_DIR/nvm.sh`
- **Bun** &mdash; `$HOME/.bun/bin` PATH
- **pnpm** &mdash; `$PNPM_HOME` (`$HOME/.local/share/pnpm`) PATH
- **.NET** &mdash; `DOTNET_ROOT` (resolved from `/usr/bin/dotnet`) + `$HOME/.dotnet/tools` PATH
- **Azure CLI** &mdash; completions (`bashcompinit` under zsh only)
- **Claude Code** &mdash; `$HOME/.local/bin` PATH

The block is shell-agnostic, so switching between bash and zsh keeps every
previously installed tool working. Every run rewrites the block in place, so a
newer script version updates machines that ran an older one. It is the only rc
wiring: the nvm installer runs with `PROFILE=/dev/null`, and the unmarked loader
lines an older nvm install appended are removed.

</details>

### Languages & Runtime

| Component | Details |
|-----------|---------|
| **NVM + Node.js LTS** | Latest nvm release for the current user, `nvm install --lts`, default alias `lts/*`. Skipped while the current LTS line is installed; once a newer Node line becomes LTS, a re-run installs it (global packages carried over) |
| **Bun** | Official `bun.sh/install` script, per-user (`~/.bun`); `bun`/`bunx` on PATH via the Tool-integrations block |
| **pnpm** | `corepack install -g pnpm@latest` through the standalone **corepack npm package** (`npm i -g corepack`; Node ≥ 25 no longer bundles corepack). Needs Node.js (select it too) |
| **Yarn 4** | `corepack install -g yarn@stable` (Yarn Berry) through the same corepack npm package |
| **.NET SDK** | Default: v10. Press `d` to pick from `8 9 10`. .NET 10 comes from the Ubuntu archive; 8 and 9 from `ppa:dotnet/backports` (both reach end of support on **2026-11-10**). Everything lives in `/usr/lib/dotnet`. A version that fails to install fails the step |
| **ABP CLI** | `Volo.Abp.Studio.Cli` dotnet global tool (`~/.dotnet/tools`); requires the .NET SDK. Provides the `abp` command |

### Browser

| Component | Source |
|-----------|--------|
| **Google Chrome** | `.deb` direct download |
| **Microsoft Edge** | Microsoft apt repo |

### Communication

| Component | Source | Details |
|-----------|--------|---------|
| **Teams for Linux** | Official apt repo ([repo.teamsforlinux.de](https://github.com/IsmaelMartinez/teams-for-linux)) | Unofficial Electron wrapper (Microsoft discontinued native Teams for Linux in 2022) |

### IDE & Editor

| Component | Source |
|-----------|--------|
| **Visual Studio Code** | Microsoft apt repo |
| **Trae IDE** | `.deb` resolved from Trae's release API; a re-run reinstalls when the API points at a new build |

### DevOps & Infrastructure

| Component | Source | Details |
|-----------|--------|---------|
| **Terraform** | HashiCorp apt repo | Infrastructure as Code |
| **Azure CLI** | Microsoft apt repo | Azure resource management |
| **AzCopy** | `aka.ms` v10 tarball | Azure Storage / Blob transfer CLI. Binary installed to `/usr/local/bin/azcopy` |
| **Docker + Compose** | Docker apt repo | Docker CE, Compose plugin, buildx. First purges the conflicting distro packages (`docker.io`, `podman-docker`, `containerd`, `runc`, …). Adds user to `docker` group |
| **BrowserStack Local** | Official zip | Secure tunnel binary for local cross-browser testing. Installed to `/usr/local/bin/BrowserStackLocal`; run with `--key <ACCESS_KEY>` |

### Database Tools

| Component | Source | Details |
|-----------|--------|---------|
| **MySQL Client** | apt | `mysqldump`, `mysql` CLI |
| **PostgreSQL Client** | apt | `pg_dump`, `pg_restore`, `psql` |
| **DBeaver Community** | Official apt repo (`dbeaver.io/debs`) | Universal database GUI. A re-run moves an older `.deb` install onto the repo |
| **Navicat Premium Lite 18** | AppImage | Installed to `/opt`, available as `navicat` command; upgrading an older version backs up `~/.config/navicat` to `~/.config/navicat.bak-<timestamp>` first |

### Apps & Desktop

| Component | Source | Details |
|-----------|--------|---------|
| **Fcitx5 (Vietnamese)** | apt / third-party repo | Vietnamese input. Press `g` to pick the engine: **Unikey** (default) or **Bamboo** (both from Ubuntu's archive), or **Lotus** (third-party fcitx5 apt repo). Auto-configures IM env vars, autostart & profile |
| **Postman** | Official tarball | API client. Unpacked to `/opt/Postman` (owned by root), `postman` command + `.desktop` launcher |
| **Waydroid** | Official apt repo | Run Android apps in a container. Needs a Wayland session + kernel `binder`; run `waydroid init` once after install |
| **VLC** | apt | Media player |
| **OBS Studio** | `ppa:obsproject/obs-studio` | Screen recording & streaming with PipeWire capture |
| **AnyDesk** | Official apt repo | Remote desktop |
| **TeamViewer** | `.deb` (adds its own apt repo) | Remote control & support |

### AI

| Component | Source | Details |
|-----------|--------|---------|
| **Claude Code** | Official installer (`claude.ai/install.sh`) | AI coding assistant. No Node.js dependency |

---

## Wayland Input Method

Ubuntu 26.04 defaults to a **Wayland** GNOME session. Chromium/Electron apps
need extra flags before fcitx5 can type into them, so their `.desktop` launchers
are patched with:

```
--enable-features=UseOzonePlatform --ozone-platform-hint=auto --enable-wayland-ime --wayland-text-input-version=3
```

`--ozone-platform-hint=auto` picks Wayland when available and falls back to X11,
so the flags are safe on either session. This is applied to **Chrome, Edge,
VS Code, Teams, Trae, and Postman**, and `ELECTRON_OZONE_PLATFORM_HINT=auto` is
added to `/etc/environment` for other Electron apps.

Package upgrades overwrite these launchers, so the script installs an apt hook
(`/etc/apt/apt.conf.d/99wayland-ime-launchers` →
`/usr/local/sbin/wayland-ime-launchers`) that re-applies the flags after every
apt run. It is removed in uninstall mode once none of those apps remain.

---

## Idempotent &mdash; Safe to Re-run

The script detects already-installed tools and skips them. A second run with the
same selection skips every step:

```
[OK] Google Chrome already installed, skipping
[OK] Docker already installed, skipping
[OK] Node.js LTS already installed via nvm, skipping
[INFO] Installing Terraform...          ← only installs what's missing
```

| Install method | Skip behavior |
|----------------|---------------|
| `.deb` / AppImage / curl downloads | Checks binary or install path before downloading |
| apt packages | Checked with `dpkg` before installing |
| Oh My Zsh + plugins | Checks `~/.oh-my-zsh` directory |
| shell rc config blocks | Checks for marker before appending |
| Swap | Checks existing size matches 8GB |

Re-runs also move older installs onto the current upstream method: DBeaver and
Teams `.deb` installs onto their apt repos, pnpm/Yarn onto the corepack npm
package, Node onto the current LTS line, and Postman's file ownership is fixed.

---

## Errors & Logs

Each step runs in its own subshell with `set -e`, so any command that fails
ends **that step only** and the run continues with the next one. The failing
command and its line number are printed and repeated in the summary:

```
  Failed:
    ✗ Docker — "apt-get install -y docker-ce docker-ce-cli …" exited 100 (do_docker, line N)
```

The whole run (after the menu) is also written to
`/var/log/install-app/<YYYYmmdd-HHMMSS>.log`, and the summary prints its path.
Ctrl-C during the run prints a partial summary before exiting. While the run is
active, apt waits up to 10 minutes for a busy dpkg lock (e.g. unattended-upgrades)
instead of failing.

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

- **apt packages** are purged (`apt-get purge`), then `apt-get autoremove` sweeps orphans
- **APT repos & GPG keys** added under `sources.list.d` / `keyrings` are deleted
- **Downloaded binaries** (`azcopy`, `BrowserStackLocal`, Postman, Navicat, etc.) are removed
- **shell rc blocks** are stripped from both `.zshrc` and `.bashrc` by their `# --- … ---` markers (only when both markers are present; a `.bak` copy is kept). The Tool-integrations block stays in `.bashrc` while other runtimes still use it
- **Mirror** is restored from the `*.bak` backups created during install

What it deliberately **leaves alone** (to avoid data loss), warning you instead:

- `git` & `curl` (too many other things depend on them)
- `/var/lib/docker`, `/var/lib/containerd`, `/etc/docker` (your images, volumes, config)
- `unixodbc-dev` after removing Navicat (other ODBC tools may use it)
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

Some changes require a **re-login** or **reboot**. The summary prints the hint
only when this run actually made such a change, and lists why (docker group
added, login shell changed, `/etc/environment` changed by fcitx5 or the Electron
hint, or `/var/run/reboot-required` present):

| Component | Requires |
|-----------|----------|
| Zsh (default shell) | Re-login |
| Docker group | Re-login |
| Fcitx5 / Wayland IME | Re-login |
| Waydroid | `waydroid init` + Wayland session |
| Swap | Active immediately |

Quick verification:

```bash
echo $SHELL                     # → /usr/bin/zsh (/bin/bash with --keep-shell)
node -v                         # → current LTS, e.g. v24.x.x
pnpm -v                         # → x.x.x
yarn -v                         # → 4.x.x
dotnet --list-sdks              # → 10.0.xxx
abp --version                   # → x.x.x
terraform -v                    # → Terraform vX.X.X
az version                      # → X.X.X
docker run hello-world          # → Hello from Docker!
claude --version                # → claude X.X.X
```

**Garbled text in the VS Code / Trae integrated terminal** (missing glyphs or `█` blocks, mostly on Vietnamese diacritics, italic or dim text): disable the terminal's GPU renderer and set a font with full glyph coverage in the user `settings.json` (`~/.config/Code/User/` or `~/.config/Trae/User/`):

```json
"terminal.integrated.gpuAcceleration": "off",
"terminal.integrated.fontFamily": "'DejaVu Sans Mono', 'Noto Sans Mono', monospace"
```

---

## Customization

### Project layout

```
install-app.sh     entrypoint — sources lib/ and apps/, then runs main
lib/
  core.sh          colours, glyphs, output helpers, sudo re-exec, package checks
  registry.sh      APPS + APP_GROUPS registry, mirror/.NET/IME config
  apt.sh           apt repo / download helpers
  shell-rc.sh      shell rc blocks, tool integrations, Wayland IME hook
  shared.sh        helpers shared by several apps (nvm, corepack, zsh plugins)
  ui-menu.sh       interactive menu
  runner.sh        step runner, logging, summary, main
apps/
  <key>.sh         one file per app: do_<key> (install) + undo_<key> (uninstall)
```

### Adding a new app

1. Add a line to the `APPS` array in `lib/registry.sh`
   (format `"key|group|Name::tagline|default_on"`, group is one of the
   `APP_GROUPS` keys; array order is install order):
   ```bash
   "myapp|desktop|My Application::a one-line tagline|1"    # 1 = on by default
   ```

2. Create `apps/myapp.sh` with a `do_myapp()` that has an idempotent skip check:
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

3. Add a matching `undo_myapp()` to the same file so it can be uninstalled too:
   ```bash
   undo_myapp() {
       info "Removing My Application..."
       apt_purge myapp            # or rm the binary / repo it installed
       success "My Application removed"
   }
   ```

The script checks at startup that every app has a known group, its
`apps/<key>.sh` file and both functions, and that every file in `apps/` is
registered.

Steps run in a subshell with `set -e`, so an unchecked failing command fails the
step. Guard expected failures with `|| true`, and add apt repos through
`add_apt_repo <list> <key-url> <key-path> <dearmor:0|1> <content>`, which rolls
the repo back when `apt-get update` fails.

### Changing swap size

Edit the size and check in `do_swap()` (`apps/swap.sh`):
```bash
fallocate -l 16G "$swapfile"
# Also update the size check: $((16 * 1024 * 1024 * 1024))
```

---

## System Requirements

| | |
|---|---|
| **OS** | Ubuntu 26.04 (resolute) |
| **Arch** | amd64 (x86_64) |
| **Privileges** | Root (`sudo`) |
| **Network** | Internet connection required |

---

## License

MIT
