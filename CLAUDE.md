# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A single-file Bash post-install setup for fresh Ubuntu 24.04 (noble) machines. An
interactive TUI menu lets the user pick which of ~28 apps to install (or
uninstall), then runs each installer in sequence. Everything lives in
`install-app.sh`. A non-24.04 host gets a soft warning at startup but the run
still proceeds.

## Architecture

**Single dispatch loop, paired functions.** Each app has a key (e.g. `docker`)
and exactly two functions: `do_<key>` (install) and `undo_<key>` (uninstall).
`main()` builds a `prefix` of `do_` or `undo_` from `$MODE`, then iterates the
`APPS` registry calling `${prefix}${key}` for every selected app. **To add an
app you must:** (1) add a `"key|Name::tagline|default_on"` line to the `APPS`
array, (2) add the key to the right group's CSV in `APP_GROUPS`, (3) write both
`do_<key>` and `undo_<key>`.

**The registries are the source of truth** (top of file, ~line 84):
- `APPS` — ordered `"key|Name::tagline|default_on"`. `::` splits highlighted
  name from dim tagline; install order = array order, so ordering matters
  (e.g. `mirror` runs first so later steps use the fast mirror; `terminal`/zsh
  runs before language runtimes so shell config lands in `.zshrc` when chosen).
- `APP_GROUPS` — `"groupkey|Title|icon|csv,of,app,keys"`; drives the collapsible
  TUI groups. Every app key must appear in exactly one group's CSV.
- `MIRRORS`, `DOTNET_VERSIONS`, `INPUT_ENGINES`/`IME_ENGINE` — config the user
  changes via menu keys (`m` mirror, `d` .NET, `g` Vietnamese input engine).
  `do_fcitx5` branches on `IME_ENGINE` (unikey / bamboo / lotus); `lotus` pulls
  a third-party fcitx5 apt repo, the other two ship in Ubuntu's archive.


**Re-exec guards.** The script re-execs itself under `bash` if launched with
`sh`/dash (line 5), and `need_root()` re-execs under `sudo` passing original
args through (so `--uninstall`/`--all` survive). Runs as root throughout; user-
file edits target `REAL_USER`/`REAL_HOME` (from `$SUDO_USER`) and `chown` back.

**TUI rendering.** `interactive_menu()` is the key loop; `print_menu()` builds
lines into a `MENU_LINES` array then `render_menu()` paints them on the alternate
screen (`\033[?1049h`) for flicker-free redraw. `read_key()` decodes arrow/escape
sequences.

## Conventions

- **Idempotency is required** — the script is advertised as safe to re-run.
  Every `do_` guards against already-installed state (check `command -v`, repo
  file existence, marker presence) before acting.
- **Output helpers**: `info` / `success` / `warn` / `fail` for all user-facing
  lines — don't raw `echo` status. `print_step_header` numbers each step.
- **Shell rc edits** are wrapped in `# --- <label> ---` … `# --- end <label> ---`
  markers; `undo_` functions call `strip_rc_block <label>` to remove them cleanly
  from both `.zshrc` and `.bashrc`. Reuse this pattern for any user-config edits.
- **Shell target is dynamic** — `resolve_shell_rc()` returns `.zshrc` when the
  zsh Terminal Kit is selected (or zsh is already the login shell), else
  `.bashrc`, so tools work even when zsh isn't installed. Runtime PATH/env goes
  through the shared `write_tool_integrations <rc>` block (shell-agnostic; the
  Azure completion is gated on `$ZSH_VERSION`); `do_eza` writes aliases to the
  resolved rc.
- **Wayland IME for Chromium/Electron** — `enable_wayland_ime <desktop-file>`
  injects Ozone/Wayland IME flags into a launcher's `Exec=` lines so fcitx5 can
  type into Chrome/Edge/VS Code/Teams/Trae/Postman; `main()` also sets
  `ELECTRON_OZONE_PLATFORM_HINT=auto` in `/etc/environment`.
- **Glyphs**: the UI uses Unicode box-drawing/symbols with an ASCII fallback.
  Use the `G_*` / `RB_*` glyph variables (set in `setup_glyphs`), never hardcode
  symbols, so `--ascii` / `MINT_ASCII=1` / non-UTF-8 locales stay legible.
- **Helpers to reuse**: `ensure_microsoft_gpg` (shared MS apt key),
  `apt_purge` (purge that never aborts the run), `get_ubuntu_codename` /
  `get_ubuntu_version`.
- `set -euo pipefail` is on — guard commands that may fail with `|| true`.
