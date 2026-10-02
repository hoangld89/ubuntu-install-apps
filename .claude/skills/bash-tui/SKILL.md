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
| ASCII text | `ui_ascii_text` (`—` `·` `…` → 7-bit, same width); `render_menu`, `run_emit` and `status_msg` (behind `info`/`success`/`warn`/`fail`) already apply it | `lib/core.sh` |
| Progress bar | `ui_bar filled total width colour fill empty` → `REPLY` | `lib/ui-menu.sh` |
| Key | `ui_pill key`: upper-cased bold lavender, as wide as the key; footer hints join `KEY label` with ` · ` | `lib/ui-menu.sh` |
| Badge / button | `ui_badge text bg cap fg`: text on `bg` between `G_CAP_L`/`G_CAP_R` half blocks drawn in `cap` (the bg as fg), `${#text} + 2` wide; brackets in ASCII mode. Used for the `SETUP` badge in the run header and the action button | `lib/ui-menu.sh` |
| Row with cursor | `ui_row on left left_len right right_len` (one-column layout) | `lib/ui-menu.sh` |
| Pane frame | `pane_top`, `pane_divider` (titled `├─ SETTINGS ─┤` at `PANE_SEP`; title never highlights since settings take no cursor), `pane_rule` | `lib/ui-menu.sh` |
| Scrolling | `scroll_window cursor items rows TOP_VAR` + `↑ n more` / `↓ n more` rows | `lib/ui-menu.sh` |
| Footer hint | `hint key label` inside `build_hints` | `lib/ui-menu.sh` |
| Step / summary line | `step_line`, `run_footer`, `summary_row`, `run_emit` | `lib/ui-run.sh` |

## Rendering rules

- Build lines into `MENU_LINES` (`ui_add`), then `render_menu` paints from `\033[H`
  with `\033[K` per line and `\033[J` at the end. Never `clear` (it flickers).
- The menu lives in the alternate screen (`menu_ui_start` / `menu_ui_stop`, cursor
  hidden). Any path that leaves the loop — `i`, `q`, EOF, INT/TERM — must restore it.
- Fork budget: one fork per keypress or per 0.5 s idle tick is fine (`read_key`
  via `$(...)`, `tput` in `ui_term_size` on redraw); nothing per row, per cell or
  per spinner frame besides the spinner's `sleep`. Helpers called per row return
  through `REPLY` or named globals (`GSTAT_*`, `CELL_*`, `PANE_*`), never
  `echo` + `$(...)`.
- Resize: the WINCH trap only sets `WINCHED`; `read_key` times out every 0.5 s
  with `TICK`, and the loop redraws on a key or on a tick with `WINCHED=1`. Keep
  `read_key` in its subshell: bash 5.3 handles a trap that interrupts `read`
  inconsistently (it resumes, or returns an empty key that reads as Enter).
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
  wide characters; group icons follow the same rule (`⚙` is an emoji that some
  terminals draw two columns wide).
- Columns: `ui_pad` fixed cells (name 18–20), `ui_trunc` the flexible one (tagline,
  detail), compute the gap with `ui_rep`. Clamp a gap to ≥ 1.
- Layout switch: two panes at ≥ 80 columns when `pane_rows` finds room, else one
  column. Below the panes `detail_line` shows the focused app's full tagline
  (blank while the groups pane has focus), so rows may cut taglines; the pane
  height reserves it through `PANE_CHROME`.
- Banner: two-row gradient block logo (`LOGO_FULL` "UBUNTU SETUP", `LOGO_SHORT`
  "SETUP" when the info would not fit beside `LOGO_FULL`, plain text in ASCII mode) with the two `MENU_INFO`
  parts right-aligned beside it, then a gradient `G_PROG_F` rule across `UI_W`.
  Logo letters are 3-4 columns of `█▀▄`; new letters follow the same font. It
  drops first when height is short. Test a change at 80×24, 120×40 and
  60×20.

## Colour and emphasis

- Meaning, not decoration: green selected/ok, yellow partial/warning, red
  error/uninstall, overlay for off/secondary, sapphire for setting values, mauve
  for focus and progress. `mode_theme` (called once in `main`) sets `FOCUS_COL`,
  `SEL_COL`, `ACCENT_BG` and `ACCENT_RAMP`: mauve for install, red for uninstall.
  Read those instead of testing `MODE` for a colour.
- Cursor row: `BG_SURFACE` + `FOCUS_COL` `G_BAR`, name in `BOLD`. Inside it only
  switch foreground (`FG0`, `NOBOLD`); `NC` or `BG0` mid-row cuts the highlight.
  End the row with a pad of spaces before `NC` so the background reaches the edge.
- Case: chrome is upper-case and bold (keys, the fixed `GROUPS` / `SETTINGS`
  titles, the action button, the logo); content keeps its own case (group and app
  names, also as the apps pane title, taglines, setting values), since all-caps
  lists are slow to scan and upper-casing breaks acronyms (`IDEs` → `IDES`). No
  letter-spacing: monospace caps are already evenly spaced; space around elements. `read_key` lower-cases
  letters, so an upper-case key on screen works with or without Shift.
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
- Detail text starts `STEP_PREFIX_W` columns in, both in step lines (glyph +
  20-column name) and in summary rows (box edge + glyph + name cell derived from
  `STEP_PREFIX_W`); keep new line types on that grid.

## Review checklist

1. `bash -n`, `shellcheck -x install-app.sh`, `validate_registry`.
2. No new fork in a per-row or per-frame path; `REPLY` copied before reuse.
3. Widths measured on plain text under `C.UTF-8`; no row exceeds `UI_W` at 120, 80
   and 60 columns.
4. ASCII mode (`MINT_ASCII=1`) prints none of the toolkit's own non-ASCII text
   (command output in error tails passes through) and 256-colour mode
   (`COLORTERM=`) renders; every new glyph and colour has its fallback, and new
   output paths go through `ui_ascii_text`.
5. Cursor highlight runs to the row end in both layouts; uninstall mode recolours.
6. Terminal is restored (main screen, cursor visible) after `i`, `q`, Ctrl-C and
   closed stdin.
7. A visible menu change re-runs `docs/screenshot.sh` so the README image matches.
