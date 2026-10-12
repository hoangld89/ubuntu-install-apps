# Modular layout + Catppuccin UI design (2026-10-01)

Goal: split the 2942-line `install-app.sh` into one file per app plus a small set of libraries, and redesign the TUI and run output with a Catppuccin Mocha truecolor palette in pure bash. Install/uninstall behaviour of all 36 apps stays identical.

## Decisions (user, 2026-10-01)
- D1 Layout: one file per app (`apps/<key>.sh`, flat directory), shared code under `lib/`.
- D2 UI: pure bash, truecolor with 256-colour fallback, no new dependencies; ASCII mode kept.
- D3 Redesign scope: banner, menu list, run output, final summary.
- D4 Run output: compact — one spinner line per step, full output only in the log file, last 15 lines of a failed step shown inline.
- D5 Palette: Catppuccin Mocha.
- D6 zsh login shell: a Terminal Kit option chosen before the run (menu key `s`), default `yes`; `do_terminal` reads it instead of prompting.
- D8 CLI: `--keep-shell` keeps the current login shell (sets the option to `no`); `--all` uses the defaults.
- D9 Shell config reaches every installed shell: the Tool-integrations block and eza aliases go to `.bashrc` always and to `.zshrc` when zsh is installed, so the login-shell choice never decides whether runtimes are on PATH.
- D7 Menu viewport: the list scrolls when it exceeds the terminal height; the banner hides on short terminals.

## Architecture

```
install-app.sh     entrypoint: re-exec under bash, resolve SCRIPT_DIR, source lib + apps, main "$@"
lib/
  core.sh          constants, palette, glyphs, setup_glyphs, info/success/warn/fail, need_root,
                   get_ubuntu_codename/version, pkg_installed/pkg_up_to_date, has_font,
                   need_reboot, step_tmpdir
  registry.sh      APPS, APP_GROUPS, MIRRORS, DOTNET_VERSIONS, INPUT_ENGINES, validate_registry
  apt.sh           fetch_key, ensure_microsoft_gpg, add_apt_source, add_ppa, add_apt_repo,
                   run_remote_script, apt_purge, download_deb
  shell-rc.sh      strip_rc_block, filter_rc, target_shell_rcs, runtimes_present,
                   tool_integrations_block, write_tool_integrations, enable_wayland_ime,
                   remove_wayland_ime_if_unused
  shared.sh        helpers/constants used by two or more apps (e.g. NVM_LOAD, corepack_*,
                   ensure_teams_repo); exact list fixed by grep during the split
  runner.sh        run state, run_step, step_failure_reason, start_logging, cleanup_run,
                   interrupt_run, usage, main
  ui-menu.sh       menu state (init_defaults, build_visible, toggles), banner, render,
                   read_key, interactive_menu, configure_dotnet/mirror/input_method/zsh
  ui-run.sh        spinner, per-step result line, progress footer, failure tail, print_summary
apps/
  <key>.sh         do_<key>, undo_<key>, and helpers/constants used only by that app
```

### Registry
`APPS` carries the group as a column; group order and icons live in `APP_GROUPS`:
```bash
APPS=( "mirror|system|APT Mirror::route apt through Vietnam's fastest mirrors|1" … )
APP_GROUPS=( "system|System & Shell|⚙|#" "dev|Languages & IDEs|◆|>" … )   # key|title|icon|ascii-icon
```
`APP_GROUPS` keeps its name with the new column layout (`GROUPS` is a bash special variable; assignments to it are discarded). Install order is `APPS` order. Menu groups list their apps in `APPS` order, which matches today's CSV order in every group. `validate_registry` checks: every app's group exists in `APP_GROUPS`; `apps/<key>.sh` exists; `do_<key>` and `undo_<key>` are defined; every `apps/*.sh` file has a registry entry. It exits naming the bad key or file.

### App files
App files contain only function and constant definitions; nothing executes at top level. A helper used by exactly one app lives in that app's file; a helper used by two or more apps lives in `lib/shared.sh`.

### Loading
`SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")`. Libraries are sourced in a fixed order (core, registry, apt, shell-rc, shared, ui-menu, ui-run, runner), then every `apps/*.sh`. `need_root` re-execs `sudo env MINT_ASCII=… COLORTERM=… bash "$SCRIPT_DIR/install-app.sh" "$@"`, so the script works from any working directory and keeps truecolor detection through sudo. `main` runs only when the entrypoint is executed directly.

## UI

### Palette
Catppuccin Mocha: mauve `#cba6f7`, blue `#89b4fa`, sapphire `#74c7ec`, teal `#94e2d5`, green `#a6e3a1`, yellow `#f9e2af`, peach `#fab387`, red `#f38ba8`, text `#cdd6f4`, subtext `#a6adc8`, overlay `#6c7086`, surface0 `#313244`.
`rgb_esc <38|48> <hex> <xterm-256 index>` emits a 24-bit escape when `COLORTERM` is `truecolor` or `24bit`, otherwise the listed xterm-256 index. Named colour variables (`C_MAUVE`, `C_GREEN`, …, `BG_SURFACE`) are set once when `lib/core.sh` is sourced; `ui_plain` blanks them inside steps. ASCII mode (`--ascii`, `MINT_ASCII=1`, non-UTF-8 locale) swaps glyphs as today; colours stay.

### Banner
Two-line half-block wordmark with a per-column horizontal gradient mauve → sapphire, info chips on the right, gradient rule below:
```
  ▄▀▀ █▀▀ ▀█▀ █ █ █▀▄   ubuntu setup · post-install toolkit
  ▄██ ██▄  █  ▀▄█ █▀    Ubuntu 26.04 · hoangle · zsh · 36 apps
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
Uninstall mode uses a red → peach gradient and a warning line. ASCII mode prints a plain-text title line.

### Menu
```
   ▾ ⚙  System & Shell             ████████  8/8
      ● APT Mirror        route apt through Vietnam's…   bizflycloud
  ▌   ● Terminal Kit      zsh · oh-my-zsh · tmux · fzf…  login: yes
      ○ Swap File         8 GB swap · swappiness 10
   ▸ ◆  Languages & IDEs           ██████░░  6/9
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   28/36 selected  ━━━━━━━━━━━━━━━━━━━━━━━━━━░░░░░░░
   ↑↓ move  ␣ toggle  ⏎ expand  a all  n none  d .NET  m mirror  g IME  s zsh  i install  q quit
```
- The cursor row has a full-width surface0 background plus the `▌` marker.
- Group rows show a mini bar and count: green when all selected, yellow when partial, overlay when none.
- Value chips: `.NET` versions, mirror host, IME engine, `login: yes|no` on Terminal Kit.
- Key hints are one line of keys drawn as pills (surface0 background).
- Lines are truncated to `tput cols` (taglines first) so nothing wraps. Widths are measured on the plain text before colour is applied, counting characters under a UTF-8 `LC_CTYPE` (`C.UTF-8`) so `·`/`—` count as one column even when sudo leaves the locale blank.
- Viewport: when banner + list + footer exceed `tput lines`, the list scrolls to keep the cursor visible, with `↑ n more` / `↓ n more` markers; below a height threshold the banner is hidden. Terminal size is re-read on every redraw.
- Key `s` toggles `ZSH_LOGIN_SHELL` (`1` by default, `0` with `--keep-shell`) and selects Terminal Kit when turned on. The chip shows only while Terminal Kit is selected.

### Run view
```
  ◆ Installing 28 apps · log /var/log/install-app/20261001-101500.log

  ✓ APT Mirror          bizflycloud                    2s
  ✓ System Update                                   1m12s
  ! Terminal Kit                                       41s
      Keeping current shell. zsh is installed — run 'zsh' anytime to use it
  ⠹ Swap File           allocating 8G…                 4s
  ━━━━━━━━━━━━━━━━━━░░░░░░░░░░░░░░  3/28 · 1m59s
```
- Each step keeps today's model: `run_step` called as a plain statement, subshell with `set -eE` and the ERR trap. The step runs with stdin from `/dev/null` and stdout/stderr appended to `$LOG_FILE`.
- Before each step the runner records the log's byte size (offset) and start time.
- `info` writes the message to the log and the latest message to `$RUN_DIR/status`; the spinner shows it as the step's sub-status.
- `warn` writes to the log and appends to `$RUN_DIR/step-warnings`; after the step its warnings print dimmed yellow under the result line and the step counts as warned in the summary.
- The spinner is a background process that redraws the last two lines (spinner line + footer) on the saved terminal fd about 10 times a second; finished lines scroll up normally. It runs while `$RUN_DIR/spinning` exists: the runner removes that file, then `wait "$SPIN_PID" || true`, then clears the two lines before printing the result line. The spinner exits on its own, so no signal is sent and bash prints no "Terminated" job message. The spinner also exits when its parent PID is gone, so an aborted run never leaves it drawing; `interrupt_run` and `cleanup_run` remove the flag file and wait for it.
- Result glyph: `✓` green, `!` yellow (succeeded with warnings), `✗` red; the elapsed time is right-aligned.
- On failure: the `step_failure_reason` line, then a dimmed block of the last 15 lines of that step's output taken from the log after the recorded offset.
- Every result line and warning is also appended to the log as plain text (no escapes), so the log reads top to bottom.
- Without a tty on fd 3 (piped, CI): no spinner and no redraw; each step prints its result line when it finishes.
- Ctrl-C: the INT/TERM trap stops the spinner, restores the cursor, and prints the partial summary.
- `start_logging` saves the terminal on fd 3/4 and creates the log; output is no longer teed globally. Pre-run output (OS warning, uninstall confirmation) goes to the terminal.
- The post-loop work (`write_tool_integrations`, the Electron hint, `enable_wayland_ime`; in uninstall mode `apt-get autoremove` and `remove_wayland_ime_if_unused`) runs as one more spinner line labelled "Finalizing", with output to the log and any `warn` shown under it.

### Summary
```
  ╭─ Done · 27 installed · 1 failed · 6m42s ───────────────────╮
  │ ✗ Docker        "apt-get install docker-ce" exited 100 (do_docker, line 31)
  │ ! Terminal Kit  Keeping current shell. zsh is installed — run 'zsh' anytime
  ╰────────────────────────────────────────────────────────────╯
  ⟳ Reboot or re-login to apply
     ▸ docker group added
  Log  /var/log/install-app/20261001-101500.log
```
The header colour follows the outcome (green / yellow / red; yellow for interrupted). The box lists failed and warned steps; it is omitted when there are none. The summary is printed to the terminal and appended to the log.

## Data flow and error model
Unchanged: `APPS` order, `${prefix}${key}` dispatch, `need_reboot`, `step_tmpdir`, `/run/install-app/step-error`, `99install-app-run`, INT/TERM handling, the post-loop tool-integration and Wayland IME steps.
Added: `$RUN_DIR/status`, `$RUN_DIR/step-warnings`, per-step log offset, `RUN_WARNED` / `RUN_WARNED_WHY` arrays for the summary.

## Shell targeting and login shell
- `target_shell_rcs` prints `$REAL_HOME/.bashrc`, plus `$REAL_HOME/.zshrc` when zsh is installed.
- `main()` writes the Tool-integrations block to every path from `target_shell_rcs` (same trigger as today: a runtime app is selected). `do_eza` writes its alias block the same way. `do_terminal` keeps writing the block to `.zshrc` it creates. Both blocks are shell-agnostic (Azure completion gated on `$ZSH_VERSION`; `alias` works in both shells).
- Re-runs on machines that only have the block in `.zshrc` gain it in `.bashrc`; the block is rewritten in place, so no duplicates.
- `undo_` paths already strip both rc files (`strip_rc_block … .zshrc .bashrc`, `undo_terminal` keeps the `.bashrc` block while runtimes remain) and stay as they are.
- `ZSH_LOGIN_SHELL` (`1` default) is set from the CLI before the menu; `--keep-shell` sets `0`. `do_terminal`: when `1` and the login shell is not zsh, `chsh -s "$(command -v zsh)"`, `need_reboot "login shell changed to zsh"`; when `0`, `info` that the current shell is kept. Uninstall mode ignores the option.
- `usage` lists `--keep-shell`.

## Delivery
Three commits:
0. Shell targeting and login-shell option on the current single file (behaviour fix).
1. Modular split, no behaviour change (code moved verbatim; registry gains the group column).
2. UI redesign (palette, banner, menu, run view, summary, key `s`).

## Implementation plan

### Phase 0 — shell targeting fix (single file)
- `install-app.sh`: `resolve_shell_rc` replaced by `target_shell_rcs`; `main()` and `do_eza` loop over its output; `ZSH_LOGIN_SHELL` global (default `1`), `--keep-shell` flag parsed in `main()` and listed in `usage`; `do_terminal` uses `ZSH_LOGIN_SHELL` in place of the `/dev/tty` prompt; `need_root` forwards args as today, so `--keep-shell` survives the sudo re-exec.
- `CLAUDE.md`: "Shell target is dynamic" convention rewritten for `target_shell_rcs` and the login-shell option.
- `README.md`: `--keep-shell` in Quick Start / options; note that runtimes are wired into both bash and zsh.

### Phase 1 — modular split
- `install-app.sh`: entrypoint only — bash re-exec guard, `SCRIPT_DIR`, ordered sourcing, `main "$@"` behind the `BASH_SOURCE` guard.
- `lib/core.sh`: colours, glyphs, `setup_glyphs`, output helpers, `need_root` (re-exec via `$SCRIPT_DIR`), `get_ubuntu_*`, `pkg_*`, `has_font`, `need_reboot`, `step_tmpdir`, path constants (`RUN_DIR`, `STATE_DIR`, `LOG_DIR`, `APT_RUN_CONF`).
- `lib/registry.sh`: `APPS` with group column, `APP_GROUPS` with icons, mirror/.NET/IME config, rewritten `validate_registry`.
- `lib/apt.sh`: apt and download helpers.
- `lib/shell-rc.sh`: rc block helpers, tool integrations, Wayland IME.
- `lib/shared.sh`: helpers and constants used by two or more apps.
- `lib/runner.sh`: run state, `run_step`, `step_failure_reason`, logging, `print_summary`, `interrupt_run`, `usage`, `main`.
- `lib/ui-menu.sh`: menu state, rendering, `read_key`, `interactive_menu`, `configure_*`; reads groups from the new registry columns.
- `apps/mirror.sh`: `do_mirror`, `undo_mirror`.
- `apps/update.sh`: `do_update`, `undo_update`.
- `apps/swap.sh`: `do_swap`, `undo_swap`, `SWAPPINESS_CONF`, `resolve_swapfile`, `remove_swapfile`.
- `apps/terminal.sh`: `do_terminal`, `undo_terminal`, terminal-only helpers.
- `apps/font.sh`: `do_font`, `undo_font`, `apply_terminal_font`, `revert_terminal_font`, `install_vn_web_fonts`.
- `apps/msfonts.sh`: `do_msfonts`, `undo_msfonts`.
- `apps/eza.sh`: `do_eza`, `undo_eza`.
- `apps/fastfetch.sh`: `do_fastfetch`, `undo_fastfetch`.
- `apps/nvm.sh`: `do_nvm`, `undo_nvm`, nvm-only helpers.
- `apps/bun.sh`: `do_bun`, `undo_bun`.
- `apps/pnpm.sh`: `do_pnpm`, `undo_pnpm`.
- `apps/yarn.sh`: `do_yarn`, `undo_yarn`.
- `apps/dotnet.sh`: `do_dotnet`, `undo_dotnet`, `DOTNET_PPA`, `DOTNET_PPA_MARKER`.
- `apps/abp.sh`: `do_abp`, `undo_abp`.
- `apps/chrome.sh`: `do_chrome`, `undo_chrome`.
- `apps/edge.sh`: `do_edge`, `undo_edge`.
- `apps/teams.sh`: `do_teams`, `undo_teams`.
- `apps/vscode.sh`: `do_vscode`, `undo_vscode`, `remove_stale_vscode_launcher`.
- `apps/trae.sh`: `do_trae`, `undo_trae`, `TRAE_URL_FILE`, `trae_latest_url`.
- `apps/terraform.sh`: `do_terraform`, `undo_terraform`.
- `apps/azcli.sh`: `do_azcli`, `undo_azcli`, `azcli_codename`, `write_azcli_repo`.
- `apps/azcopy.sh`: `do_azcopy`, `undo_azcopy`.
- `apps/docker.sh`: `do_docker`, `undo_docker`.
- `apps/browserstack.sh`: `do_browserstack`, `undo_browserstack`.
- `apps/mysqlclient.sh`: `do_mysqlclient`, `undo_mysqlclient`.
- `apps/pgclient.sh`: `do_pgclient`, `undo_pgclient`.
- `apps/dbeaver.sh`: `do_dbeaver`, `undo_dbeaver`, `DBEAVER_LIST`, `DBEAVER_KEY`.
- `apps/navicat.sh`: `do_navicat`, `undo_navicat`, `remove_navicat_user_entries`.
- `apps/fcitx5.sh`: `do_fcitx5`, `undo_fcitx5`.
- `apps/postman.sh`: `do_postman`, `undo_postman`.
- `apps/waydroid.sh`: `do_waydroid`, `undo_waydroid`.
- `apps/vlc.sh`: `do_vlc`, `undo_vlc`.
- `apps/obs.sh`: `do_obs`, `undo_obs`.
- `apps/anydesk.sh`: `do_anydesk`, `undo_anydesk`.
- `apps/teamviewer.sh`: `do_teamviewer`, `undo_teamviewer`.
- `apps/claude.sh`: `do_claude`, `undo_claude`.
- `.shellcheckrc` (new): `shell=bash`, `external-sources=true`, `source-path=SCRIPTDIR`; the entrypoint carries `# shellcheck source=lib/<file>.sh` directives for each library and every lib/app file starts with `# shellcheck shell=bash`.
- `CLAUDE.md`: Architecture section rewritten for the file layout, registry columns, and the steps to add an app.
- `README.md`: project layout and "adding an app" section.

Per-file helper placement above follows a first-pass grep; the split re-checks every helper's callers and moves any multi-app helper to `lib/shared.sh`.

### Phase 2 — UI
- `lib/core.sh`: Catppuccin palette via `rgb_esc`, truecolor detection with 256-colour fallback, `ui_plain`; `info` writes `$RUN_DIR/status`, `warn` appends `$RUN_DIR/step-warnings` while a step runs.
- `lib/ui-menu.sh`: new banner, group/app rows, cursor background, key-hint line, width truncation, viewport, key `s` and its `login: yes|no` chip.
- `lib/ui-run.sh` (new): spinner process, result line, footer, failure tail, `print_summary` (moved from `runner.sh`).
- `lib/runner.sh`: step output to the log, stdin `/dev/null`, offsets, durations, warnings, spinner start/stop around `run_step`, global tee removed.
- `README.md`: menu/run view illustrations, key `s`.
- `CLAUDE.md`: TUI rendering and output model sections.

## Assumptions to validate
- A1 After Phase 0 no step reads interactive input (grep finds `/dev/tty` only in the uninstall confirmation in `main`).
- A2 Tools invoked by steps behave the same with stdin from `/dev/null` (apt runs noninteractive with `--force-confold`; `su - user -c` does not read stdin).
- A3 `declare -f` output is a reliable equality check for moved functions (it normalises formatting, so verbatim moves compare equal).

## Verification Criteria

### Phase 0
- `bash -n`, `shellcheck` with no new findings vs `HEAD`.
- With `REAL_HOME` pointed at a scratch home: zsh absent → `target_shell_rcs` prints only `.bashrc`; zsh present → both. Running `write_tool_integrations` over the list twice leaves exactly one block per file.
- A scratch home that has the block only in `.zshrc` gains it in `.bashrc` after the main-loop write.
- `--keep-shell` sets `ZSH_LOGIN_SHELL=0`, survives the sudo re-exec, and appears in `--help`; `--all` alone leaves it at `1`.
- `do_terminal` contains no `read` from `/dev/tty`; `grep -n '/dev/tty'` shows only the uninstall confirmation in `main`.
- On a real machine: install with `--keep-shell` keeps bash and `node`/`dotnet`/`ll` work in a new bash terminal; install without it switches to zsh and they work in zsh.

### Phase 1
- `bash -n` passes on every file.
- Shellcheck parity: concatenate the entrypoint, `lib/*.sh` and `apps/*.sh` in source order into a bundle in the scratchpad and run `shellcheck` on it; its set of finding codes and messages matches `shellcheck install-app.sh` at `HEAD` (27 findings today), apart from findings on lines that change on purpose. Per-file runs are not the gate, since cross-file globals raise SC2034/SC2154 there.
- Function parity: source `git show HEAD:install-app.sh` and the new entrypoint in two separate bash processes; `declare -f` of every function present in both is identical, except intended changes (`validate_registry`, menu functions reading groups, `need_root`). Every old function exists in the new tree.
- Variable parity: `declare -p` of every non-registry global constant matches.
- `./install-app.sh --help` works from the repo root and from another directory.
- `validate_registry` passes; deleting an app file, removing a `do_`, or giving an unknown group each fail with the key named.
- Install order printed from the new `APPS` equals the old order.

### Phase 2
- Menu renders correctly with `COLORTERM=truecolor`, with `TERM=xterm-256color` and no `COLORTERM`, with `--ascii`, in uninstall mode, at 80×24 with all groups expanded (viewport scrolls, cursor stays visible), and at width 60 (no wrapped lines).
- Keys `a n d m g s i q`, arrows, `j/k`, Enter, Space all behave as before; `s` toggles the chip and selects Terminal Kit.
- Run view: a stub step that succeeds, one that warns, one that fails (tail shows its last 15 lines), one slow step (spinner sub-status updates from `info`).
- `./install-app.sh --all | cat` (no tty): one plain line per step, no escape-sequence redraws.
- Ctrl-C during a step: spinner stops, cursor visible, partial summary printed, exit 130.
- The log contains every step's full output plus plain-text result lines and the summary.
- Real run on a machine: a second identical run skips every step (idempotency unchanged).
