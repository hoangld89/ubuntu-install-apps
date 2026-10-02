# CLAUDE.md

Bash post-install toolkit for Ubuntu 26.04 (resolute): a TUI menu picks which of
36 apps to install or uninstall, then runs each one as a step. Other releases get
a warning and the run continues.

## Layout

- `install-app.sh` — entrypoint: re-execs under bash, sources `lib/` (core,
  registry, apt, shell-rc, shared, ui-menu, ui-run, runner) and `apps/*.sh`, runs `main`.
- `lib/registry.sh` — `APPS` (`"key|group|Name::tagline|default_on"`, array order
  is install order) and `APP_GROUPS` (`"key|Title|Short|icon|ascii-icon"`, Short ≤ 11 chars).
- `apps/<key>.sh` — `do_<key>`, `undo_<key>` and helpers only that app uses.
  Helpers shared by two or more apps go in `lib/shared.sh`.
- Lib and app files only define functions and constants.

**Adding an app:** add its `APPS` line, create `apps/<key>.sh` with both
functions. `validate_registry` exits at startup if the group, file or a function
is missing.

## Invariants

- Each step runs in a subshell with `set -eE` + ERR trap: a failing command ends
  that step only. Call `run_step` (and any `do_`) as a plain statement — inside
  `if`/`||`/`&&`/`!` bash ignores `set -e` and the trap.
- Steps can't set globals for later steps: use `need_reboot "<reason>"` and
  `step_tmpdir`. Step output goes to the log with stdin `/dev/null`; steps never
  prompt (only the uninstall confirmation in `main` reads input).
- Inside a step `info` feeds the spinner status and `warn` is shown under the
  result line and in the summary — use `warn` for anything the user must see.
- Helpers called as `helper || return 1` run without `set -e`, so they check each
  command. `su - user -c` blocks start with `set -e`; nvm blocks source
  `$NVM_LOAD` first (nvm is not `set -e` safe).
- Menu redraw and spinner paths must not fork: string helpers (`ui_trunc`,
  `ui_pad`, `ui_rep`, `ui_ascii_text`, `ui_bar`, `ui_pill`, `item_chip`, `fmt_secs`) return via `REPLY`.
  Widths are counted on plain text under `LC_ALL=C.UTF-8`; cursor rows only
  switch foreground (`FG0`/`NOBOLD`) so the background survives.
- Never name an array `GROUPS` (bash reserves it).

## Conventions

- **Idempotent:** every `do_` skips already-installed state, and re-runs move
  old installs onto the current upstream method.
- **Output:** `info` / `success` / `warn` / `fail`, never raw `echo` for status.
  Colours are the `C_*` / `BG_SURFACE` names, glyphs the `G_*` / `RB_*` names
  (ASCII fallback via `setup_glyphs`); no hardcoded escapes or symbols.
- **Shell rc edits** sit between `# --- <label> ---` and `# --- end <label> ---`;
  `undo_` removes them with `strip_rc_block`. Shell config goes to every rc from
  `target_shell_rcs` (`.bashrc`, plus `.zshrc` when zsh is installed).
- **Login shell:** `ZSH_LOGIN_SHELL` (menu key `s`, `--keep-shell` = 0) decides
  whether `do_terminal` runs `chsh`.
- **Electron/Chromium apps:** add the `.desktop` path to `WAYLAND_IME_LAUNCHERS`
  and the key to `ELECTRON_KEYS`; runtimes go in `RUNTIME_KEYS`.
- **Helpers to reuse:** `add_apt_repo`, `add_apt_source`, `ensure_microsoft_gpg`,
  `run_remote_script`, `download_deb`, `pkg_installed` / `pkg_up_to_date`,
  `has_font` (never `fc-list | grep -q`: SIGPIPE + pipefail turns a match into
  a miss), `apt_purge`, `get_ubuntu_codename` / `get_ubuntu_version`.

## Writing rules

- **Comments:** none by default. Only the why, a workaround for an external
  limit, or a constraint invisible from that spot. One line; two lines only for
  a workaround that can't fit in one. No comments that restate code, section
  titles, or parameter lists.
- **No padding** in code, README or this file: state each fact once, no intros,
  recaps, marketing or history. Delete text that repeats what code or another
  section already says.

## Git, PRs and releases

- Script changes (`install-app.sh`, `lib/`, `apps/`) go on a `feat/…` / `fix/…`
  branch and reach `main` through a squash-merged PR. Docs-only changes may be
  committed to `main` directly.
- Versions follow SemVer in `TOOLKIT_VERSION` (`lib/core.sh`; not `VERSION`, which `/etc/os-release` defines): MAJOR for removed apps,
  flags or behaviour users rely on; MINOR for new apps or options; PATCH for fixes.
- Release: bump `TOOLKIT_VERSION` in the PR, then after merge tag `main` as `vX.Y.Z` and
  run `gh release create vX.Y.Z --generate-notes`.
- Verify before a PR: `bash -n` on every file, `shellcheck -x install-app.sh`,
  and `validate_registry` (source `install-app.sh`, call it).
