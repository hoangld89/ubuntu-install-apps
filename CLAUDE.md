# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Bash post-install setup for fresh Ubuntu 26.04 (resolute) machines. An
interactive TUI menu lets the user pick which of 36 apps to install (or
uninstall), then runs each installer in sequence. A non-26.04 host gets a soft
warning at startup but the run still proceeds.

## Layout

- `install-app.sh` — entrypoint: bash re-exec guard, `SCRIPT_DIR`, sources
  `lib/` in a fixed order (core, registry, apt, shell-rc, shared, ui-menu,
  runner) then every `apps/*.sh`, and calls `main` when executed directly.
- `lib/core.sh` — colours, glyphs, output helpers, `need_root`, path constants,
  `pkg_*`, `need_reboot`, `step_tmpdir`.
- `lib/registry.sh` — `APPS`, `APP_GROUPS`, menu config, `validate_registry`.
- `lib/apt.sh` — apt/download helpers. `lib/shell-rc.sh` — rc blocks, tool
  integrations, Wayland IME. `lib/shared.sh` — helpers used by two or more apps.
- `lib/ui-menu.sh` — menu state, rendering, key loop. `lib/runner.sh` — step
  runner, logging, summary, `usage`, `main`.
- `apps/<key>.sh` — `do_<key>`, `undo_<key>` and helpers only that app uses.
  App and lib files only define functions and constants; nothing runs at
  source time except building registry lookup tables.

## Architecture

**Single dispatch loop, paired functions.** Each app has a key (e.g. `docker`)
and exactly two functions: `do_<key>` (install) and `undo_<key>` (uninstall).
`main()` builds a `prefix` of `do_` or `undo_` from `$MODE`, then iterates the
`APPS` registry calling `${prefix}${key}` for every selected app. **To add an
app you must:** (1) add a `"key|group|Name::tagline|default_on"` line to `APPS`
in `lib/registry.sh`, (2) create `apps/<key>.sh` with both `do_<key>` and
`undo_<key>`. `validate_registry` checks at startup that the group exists, the
file exists, both functions are defined, and every `apps/*.sh` has an entry; it
exits naming the bad key or file.

**The registries are the source of truth** (`lib/registry.sh`):
- `APPS` — ordered `"key|group|Name::tagline|default_on"`. `::` splits highlighted
  name from dim tagline; install order = array order, so ordering matters
  (e.g. `mirror` runs first so later steps use the fast mirror; `terminal`/zsh
  runs before language runtimes so `.zshrc` exists when they write to it).
- `APP_GROUPS` — `"groupkey|Title|icon|ascii-icon"`; drives the collapsible TUI
  groups in array order. `GROUP_APPS[groupkey]` (built from `APPS`) lists each
  group's apps in `APPS` order. Never name an array `GROUPS` — bash reserves it.
- `MIRRORS`, `DOTNET_VERSIONS`, `INPUT_ENGINES`/`IME_ENGINE` — config the user
  changes via menu keys (`m` mirror, `d` .NET, `g` Vietnamese input engine).
  `do_fcitx5` branches on `IME_ENGINE` (unikey / bamboo / lotus); `lotus` pulls
  a third-party fcitx5 apt repo, the other two ship in Ubuntu's archive.
  `DOTNET_VERSIONS` accepts 8, 9, 10: 10 from the archive, 8/9 from
  `ppa:dotnet/backports` (added only when needed, marker in `/var/lib/install-app`).

**Step runner and error model.** `run_step` runs each `${prefix}${key}` in a
subshell with `set -eE` and an ERR trap: any unchecked failing command ends that
step only, the first failing command/function/line goes to `/run/install-app/step-error`
and into the summary, and the next step still runs. `run_step` must be called as
a plain statement — inside an `if`/`||`/`&&`/`!` context bash ignores `set -e` and
the ERR trap, even inside the subshell (same reason a `do_` must not be called
that way). Helpers called as `helper || return 1` run without `set -e`, so they
check each command explicitly. Because steps are subshells, a step can't set
globals for later steps: reboot reasons go through `need_reboot "<reason>"`
(appends to `/run/install-app/reboot-reasons`), temp files through
`step_tmpdir` (`$STEP_TMP`, removed by the step's EXIT trap). `su - user -c`
install blocks start with `set -e`; blocks that use nvm source `nvm.sh` first
(`$NVM_LOAD`) because nvm is not `set -e` safe.

**Run lifecycle.** After the menu, `start_logging` tees stdout/stderr to
`/var/log/install-app/<YYYYmmdd-HHMMSS>.log` (tee ignores INT so the summary still
lands); an INT/TERM trap prints a partial summary; `/etc/apt/apt.conf.d/99install-app-run`
sets `DPkg::Lock::Timeout "600"` for the run and the EXIT trap removes it.
`DEBIAN_FRONTEND=noninteractive` is exported; script code uses `apt-get`. The
reboot hint is printed only with collected reasons (plus `/var/run/reboot-required`).

**Re-exec guards.** The script re-execs itself under `bash` if launched with
`sh`/dash (top of `install-app.sh`), and `need_root()` re-execs
`$SCRIPT_DIR/install-app.sh` under `sudo` passing original
args through (so `--uninstall`/`--all` survive) plus `MINT_ASCII` via `sudo env`.
Runs as root throughout; user-file edits target `REAL_USER`/`REAL_HOME` (from
`$SUDO_USER`, home from `getent passwd`) and `chown` back. A target user of root
aborts the run.

**TUI rendering.** `interactive_menu()` is the key loop; `print_menu()` builds
lines into a `MENU_LINES` array then `render_menu()` paints them on the alternate
screen (`\033[?1049h`) for flicker-free redraw. `read_key()` decodes arrow keys
(`ESC [ A/B` and `ESC O A/B`) and `k`/`j`.

## Conventions

- **Idempotency is required** — the script is advertised as safe to re-run.
  Every `do_` guards against already-installed state (check `command -v`,
  `pkg_installed`, repo file existence, marker presence) before acting; a second
  identical run should skip every step. Re-runs also move old installs onto the
  current upstream method (e.g. DBeaver/Teams `.deb` → apt repo, Trae keyed on
  the API download URL in `/var/lib/install-app/trae.url`).
- **Output helpers**: `info` / `success` / `warn` / `fail` for all user-facing
  lines — don't raw `echo` status. `print_step_header` numbers each step.
- **Shell rc edits** are wrapped in `# --- <label> ---` … `# --- end <label> ---`
  markers; `undo_` functions call `strip_rc_block <label> [rc…]` to remove them
  from `.zshrc` and `.bashrc` (only when both markers exist; `filter_rc` keeps a
  `.bak` and the owner). Reuse this pattern for any user-config edits.
- **Shell config reaches every installed shell** — `target_shell_rcs()` prints
  `.bashrc`, plus `.zshrc` when zsh is installed (the Terminal Kit runs before
  every runtime), so tools are on PATH whatever the login shell is. Runtime
  PATH/env goes through the shared `write_tool_integrations <rc>` block
  (shell-agnostic; the Azure completion is gated on `$ZSH_VERSION`), which
  `main()` writes to each target rc and rewrites in place on every run so script
  updates reach existing machines; `do_eza` writes its aliases the same way.
- **Login shell is a pre-run option** — `ZSH_LOGIN_SHELL` (default `1`,
  `--keep-shell` sets `0`) decides whether `do_terminal` runs `chsh` to zsh.
  Steps never prompt; the only interactive read after the menu is the
  uninstall confirmation in `main()`.
- **Wayland IME for Chromium/Electron** — `enable_wayland_ime` (called from
  `main()`) installs `/usr/local/sbin/wayland-ime-launchers` plus a
  `DPkg::Post-Invoke` hook (`/etc/apt/apt.conf.d/99wayland-ime-launchers`) that
  injects Ozone/Wayland IME flags into the `Exec=` lines of every launcher in
  `WAYLAND_IME_LAUNCHERS` after each apt run, so package upgrades can't drop them.
  A new Electron app → add its `.desktop` path to that array. `main()` also sets
  `ELECTRON_OZONE_PLATFORM_HINT=auto` in `/etc/environment`.
- **Glyphs**: the UI uses Unicode box-drawing/symbols with an ASCII fallback.
  Use the `G_*` / `RB_*` glyph variables (set in `setup_glyphs`), never hardcode
  symbols, so `--ascii` / `MINT_ASCII=1` / non-UTF-8 locales stay legible.
- **Helpers to reuse**: `add_apt_repo <list> <key-url> <key-path> <dearmor:0|1>
  <content>` (temp-file key, rollback of key + list when `apt-get update`
  fails), `add_apt_source` (same for a list whose key is already in place),
  `ensure_microsoft_gpg` (shared MS apt key), `run_remote_script <user> <cmd>
  <url> [args]` (downloads to a temp file; `<cmd>` may be `env VAR=… bash`),
  `download_deb`, `pkg_installed` / `pkg_up_to_date`, `has_font` (never
  `fc-list | grep -q`: with pipefail the SIGPIPE makes a match look like a miss),
  `apt_purge` (purges only installed packages, never aborts the run),
  `get_ubuntu_codename` / `get_ubuntu_version`.
- `set -euo pipefail` is on — guard commands that may fail with `|| true`.
