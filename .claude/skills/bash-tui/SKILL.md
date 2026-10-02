---
name: bash-tui
description: Design, build or review the pure-bash TUI of this toolkit (menu in lib/ui-menu.sh, run view and summary in lib/ui-run.sh, palette and glyphs in lib/core.sh). Use when adding or changing a menu row, pane, key binding, setting, footer hint, spinner/step line or summary, or when reviewing UI code for width, colour, flicker or fork problems.
---

# Bash TUI

The UI is hand-drawn with ANSI escapes: no gum, dialog, whiptail or other binary.
Read the file you change first; the invariants in `CLAUDE.md` still apply.

## Building blocks

| Need | Use | Where |
|---|---|---|
| Colour | `C_*` fg, `BG_SURFACE` / `BG_MAUVE` / `BG_RED`, `BOLD` / `NOBOLD`, `FG0` / `BG0`, `NC` | `lib/core.sh` |
| New colour | `rgb_esc 38\|48 <hex> <xterm-256>` with the Catppuccin Mocha hex and nearest 256 index; also blank it in `ui_plain` | `lib/core.sh` |
| Glyph | `G_*`, box `RB_*`, spinner `G_SPIN`; every new glyph gets a 7-bit twin in `setup_glyphs` | `lib/core.sh` |
| Cut / pad / repeat | `ui_trunc`, `ui_pad`, `ui_rep` → `REPLY` | `lib/core.sh` |
| Progress bar | `ui_bar filled total width colour fill empty` → `REPLY` | `lib/ui-menu.sh` |
| Key pill | `ui_pill key` (brackets in ASCII mode) | `lib/ui-menu.sh` |
| Row with cursor | `ui_row on left left_len right right_len` (one-column layout) | `lib/ui-menu.sh` |
| Pane frame | `pane_top`, `pane_rule`, `PANE_SEP` for a `├──┤` divider | `lib/ui-menu.sh` |
| Scrolling | `scroll_window cursor items rows TOP_VAR` + `↑ n more` / `↓ n more` rows | `lib/ui-menu.sh` |
| Footer hint | `hint key label` inside `build_hints` | `lib/ui-menu.sh` |
| Step / summary line | `step_line`, `run_footer`, `summary_row`, `run_emit` | `lib/ui-run.sh` |

## Rendering rules

- Build lines into `MENU_LINES` (`ui_add`), then `render_menu` paints from `\033[H`
  with `\033[K` per line and `\033[J` at the end. Never `clear` (it flickers).
- The menu lives in the alternate screen (`menu_ui_start` / `menu_ui_stop`, cursor
  hidden). Any path that leaves the loop — `i`, `q`, EOF, INT/TERM — must restore it.
- Fork budget: one fork per keypress is fine (`read_key` via `$(...)`, `tput` in
  `ui_term_size`); nothing per row, per cell or per spinner frame besides the
  spinner's `sleep`. Helpers called per row return through `REPLY` or named
  globals (`GSTAT_*`, `CELL_*`, `PANE_*`), never `echo` + `$(...)`.
- A helper that sets `REPLY` overwrites the caller's: copy it (`x=$REPLY`) before
  the next helper call.
- Expensive, rarely changing parts are cached by a key string (`BANNER_KEY`,
  `HINTS_KEY`); add every input that changes the output to that key.

## Width and alignment

- `UI_W` is the content width (terminal − 3, clamped 40–96); every row fits in it.
  Rows start with a two-space gutter.
- Measure plain text only: declare `local LC_ALL=C.UTF-8` in the function and take
  `${#var}` before adding escapes. Functions that join coloured pieces take the
  plain length as a separate argument (`ui_row`, `hint`'s `len|coloured`).
- Glyphs used in measured text must be one column wide. No emoji or East Asian
  wide characters; group icons follow the same rule.
- Columns: `ui_pad` fixed cells (name 18–20), `ui_trunc` the flexible one (tagline,
  detail), compute the gap with `ui_rep`. Clamp a gap to ≥ 1.
- Layout switch: two panes at ≥ 80 columns when `pane_rows` finds room, else one
  column. Banner drops first when height is short. Test a change at 80×24, 120×40
  and 60×20.

## Colour and emphasis

- Meaning, not decoration: green selected/ok, yellow partial/warning, red
  error/uninstall, overlay for off/secondary, sapphire for setting values, mauve
  for focus and progress. Uninstall mode swaps `FOCUS_COL` / `SEL_COL` to red.
- Cursor row: `BG_SURFACE` + `FOCUS_COL` `G_BAR`, name in `BOLD`. Inside it only
  switch foreground (`FG0`, `NOBOLD`); `NC` or `BG0` mid-row cuts the highlight.
  End the row with a pad of spaces before `NC` so the background reaches the edge.
- State never relies on colour alone: pair it with a glyph (`G_ON`/`G_OFF`,
  `G_OK`/`G_WARN`/`G_ERR`) or a count (`3/5`).
- Truecolor comes from `COLORTERM`; the 256-colour index must stay close to the hex.

## Keys and input

- `read_key` maps arrows (CSI and SS3 forms), `hjkl`, Enter, Space, Tab, bare ESC
  and EOF (→ `QUIT`) to names; add new special keys there, letters pass through.
- A new binding needs: the `case` in `interactive_menu`, a `hint` in `build_hints`
  (only for layouts where it works), and in two-pane mode a Settings row via
  `settings_row` if it changes a setting.
- Install-only keys check `MODE`. Prompts (`configure_*`) show the cursor with
  `tput cnorm` and hide it again after; they are the only place `read -p` is used.

## Run view

- Steps never draw: they call `info` (spinner sub-status) and `warn` (shown under
  the result line). Only `run_emit` writes to the terminal, and it copies a plain
  version to the log.
- Spinner is a background subshell that redraws one step line plus the footer bar
  every 0.1 s and stops when `$RUN_DIR/spinning` disappears. It only runs when
  `RUN_TTY=1`; non-tty output must still read correctly line by line.
- Step lines and summary rows share the 2 + glyph + 20-column name layout; keep
  any new line type on the same grid.

## Review checklist

1. `bash -n`, `shellcheck -x install-app.sh`, `validate_registry`.
2. No new fork in a per-row or per-frame path; `REPLY` copied before reuse.
3. Widths measured on plain text under `C.UTF-8`; no row exceeds `UI_W` at 120, 80
   and 60 columns.
4. ASCII mode (`MINT_ASCII=1`) and 256-colour mode (`COLORTERM=`) both render;
   every new glyph and colour has its fallback.
5. Cursor highlight runs to the row end in both layouts; uninstall mode recolours.
6. Terminal is restored (main screen, cursor visible) after `i`, `q`, Ctrl-C and
   closed stdin.
