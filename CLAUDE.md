# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A single-file Bash post-install setup for fresh Ubuntu / Linux Mint machines. An
interactive TUI menu lets the user pick which of ~24 apps to install (or
uninstall), then runs each installer in sequence. Everything lives in
`install-app.sh` (~1700 lines); `test-docker.sh` runs it safely in a throwaway
container.

## Testing

The script writes to `/etc`, adds apt repos, installs fonts, and changes the
default shell — **never run an unverified version on the host.** Test in a
disposable container via `test-docker.sh` (changes vanish on `--rm`):

```bash
bash -n install-app.sh                    # syntax-only parse check (fast first pass)
./test-docker.sh lint                     # shellcheck (koalaman/shellcheck container, --severity=warning)
./test-docker.sh func terminal eza font   # source script, run specific do_<KEY>s — crash test
./test-docker.sh all                      # non-interactive: install everything (--all)
./test-docker.sh                          # interactive INSTALL menu (TUI)
./test-docker.sh uninstall                # interactive UNINSTALL menu
./test-docker.sh shell                    # bash shell inside the container

IMAGE=ubuntu:22.04 ./test-docker.sh all   # different Ubuntu release (default ubuntu:24.04)
PRIVILEGED=1 ./test-docker.sh all         # --privileged, lets swap/docker actually run
```

`bash -n` and shellcheck are static and **cannot** catch `unbound variable`
errors that only fire under `set -u` at runtime — the container layers are what
catch those. See `TESTING.md` for what legitimately fails inside a container
(swap, docker/systemctl, GUI apps) vs. real bugs.

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
  runs before language runtimes so they write config into `.zshrc`).
- `APP_GROUPS` — `"groupkey|Title|icon|csv,of,app,keys"`; drives the collapsible
  TUI groups. Every app key must appear in exactly one group's CSV.
- `MIRRORS`, `DOTNET_VERSIONS` — config the user can change via menu keys.

**Sourceable for tests.** The entry point is guarded by
`if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi`, so sourcing the
script defines all functions without launching the menu. That's how
`test-docker.sh func` calls individual installers.

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
- **`.zshrc` edits** are wrapped in `# --- <label> ---` … `# --- end <label> ---`
  markers; `undo_` functions call `strip_zshrc_block <label>` to remove them
  cleanly. Reuse this pattern for any user-config edits.
- **Glyphs**: the UI uses Unicode box-drawing/symbols with an ASCII fallback.
  Use the `G_*` / `RB_*` glyph variables (set in `setup_glyphs`), never hardcode
  symbols, so `--ascii` / `MINT_ASCII=1` / non-UTF-8 locales stay legible.
- **Helpers to reuse**: `ensure_microsoft_gpg` (shared MS apt key),
  `apt_purge` (purge that never aborts the run), `get_ubuntu_codename` /
  `get_ubuntu_version` (handle Mint's upstream-release mapping).
- `set -euo pipefail` is on — guard commands that may fail with `|| true`.
