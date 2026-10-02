---
name: bash-tui
description: Design, build or review the pure-bash TUI of this toolkit (menu in lib/ui-menu.sh, run view and summary in lib/ui-run.sh, palette and glyphs in lib/core.sh). Use when adding or changing a menu row, pane, key binding, setting, footer hint, spinner/step line or summary, or when reviewing UI code for width, colour, flicker or fork problems.
---

# Bash TUI

Hand-drawn ANSI, no gum/dialog/whiptail. Read the file you change first;
`CLAUDE.md` invariants apply and are not repeated here.

## Building blocks

| Need | Use |
|---|---|
| Colour (`lib/core.sh`) | `C_*`, `BG_SURFACE`/`BG_MAUVE`/`BG_RED`, `BOLD`/`NOBOLD`, `FG0`/`BG0`, `NC`. New: `rgb_esc 38\|48 <hex> <256-index>` (Catppuccin Mocha hex, nearest index), blanked in `ui_plain` |
| Glyph (`lib/core.sh`) | `G_*`, box `RB_*`, `G_SPIN`; each new one gets a 7-bit twin in `setup_glyphs` |
| Text (`lib/core.sh`) | `ui_trunc`, `ui_pad`, `ui_rep`; `ui_ascii_text` (`—` `·` `…` → 7-bit), already applied by `render_menu`, `run_emit`, `status_msg`; any new output path must call it |
| Menu (`lib/ui-menu.sh`) | `ui_bar filled total width colour fill empty`; `ui_pill key` (upper-case bold lavender); `ui_badge text bg cap fg` (half-block caps, `${#text}+2` wide, brackets in ASCII); `ui_row on left left_len right right_len` (one-column); `pane_top`/`pane_divider`/`pane_rule`; `scroll_window cursor items rows TOP_VAR` → `SCROLL_FROM`/`SCROLL_TO`; `hint key label` in `build_hints` |
| Run (`lib/ui-run.sh`) | `step_line`, `run_footer`, `summary_row`, `run_emit` |

## Rendering

- Lines go into `MENU_LINES` (`ui_add`); `render_menu` paints from `\033[H`, `\033[K`
  per line, `\033[J` at the end. Never `clear`.
- Alternate screen via `menu_ui_start`/`menu_ui_stop`, cursor hidden. Every exit
  from the loop (`i`, `q`, EOF, INT/TERM) restores it.
- Allowed forks: one per keypress or 0.5 s tick (`read_key`, `tput` on redraw) and
  the spinner's `sleep`. Per-row helpers return via `REPLY` or globals (`GSTAT_*`,
  `CELL_*`, `PANE_*`); copy `REPLY` before the next helper call.
- Resize: WINCH only sets `WINCHED`; the loop redraws on a key or on a `TICK` with
  `WINCHED=1`. Keep `read_key` in its subshell: bash 5.3 can turn a trap during
  `read` into an empty key that reads as Enter.
- Cached parts (`BANNER_KEY`, `HINTS_KEY`): every input that changes the output
  goes into the key.

## Layout

- `UI_W` = terminal − 3, clamped 40–96; rows start with a two-space gutter.
- Joiners of coloured pieces take the plain length separately (`ui_row`, `hint`'s
  `len|coloured`).
- Measured glyphs are one column: no emoji or wide characters (`⚙` draws two).
- Fixed cells with `ui_pad` (name 18–20), the flexible one with `ui_trunc`, gap with
  `ui_rep`, clamped ≥ 1.
- Two panes at ≥ 80 columns when `pane_rows` finds room, else one column.
  `detail_line` under the panes shows the full tagline, so rows may cut it;
  `PANE_CHROME` reserves its row.
- Banner: two-row gradient logo in 3-4 column `█▀▄` letters (`LOGO_FULL`, or
  `LOGO_SHORT` when `MENU_INFO` won't fit beside it; text in ASCII), `MENU_INFO`
  right-aligned, a `G_PROG_F` rule below. It drops first when height is short.

## Colour and emphasis

- Green selected/ok, yellow partial/warning, red error/uninstall, overlay
  off/secondary, sapphire setting values, mauve focus/progress. Use `FOCUS_COL`,
  `SEL_COL`, `ACCENT_BG`, `ACCENT_RAMP` from `mode_theme`, not `MODE` tests.
- Cursor row: `BG_SURFACE` + `FOCUS_COL` `G_BAR`, name `BOLD`, space-padded to the
  edge before `NC`.
- Chrome (keys, `GROUPS`/`SETTINGS`, action button, logo) is upper-case bold;
  content keeps its case (`IDEs`). No letter-spacing.
- State pairs colour with a glyph (`G_ON`/`G_OFF`, `G_OK`/`G_WARN`/`G_ERR`) or a
  count (`3/5`).

## Keys

- `read_key` names arrows (CSI/SS3), `hjkl`, Enter, Space, Tab, ESC, EOF (→ `QUIT`);
  letters pass through lower-cased, so on-screen upper-case keys need no Shift.
- A new binding: `case` in `interactive_menu`, `hint` in `build_hints` for layouts
  where it works, and `settings_row` in two-pane mode if it changes a setting.
  Install-only keys check `MODE`.
- `configure_*` prompts are the only `read -rp`; `interactive_menu` toggles the
  cursor around them.

## Run view

- Steps never draw: `info` feeds the spinner, `warn` shows under the result line.
  Only `run_emit` writes, copying plain text to the log.
- The spinner subshell redraws one step line and the footer every 0.1 s until
  `$RUN_DIR/spinning` is gone, only when `RUN_TTY=1`; non-tty output reads line by
  line.
- Detail text starts at `STEP_PREFIX_W` in step lines and summary rows; new line
  types use that grid.

## Check and review

Run `.claude/skills/bash-tui/check.sh`: the static checks from `CLAUDE.md`, then
the menu frame rendered headless at 120x40, 80x24 and 60x20 in install, ASCII,
256-colour and uninstall mode. It prints failures only, else one `ok` line.

It does not cover the run view and summary, keys, resize, the cursor highlight or
terminal restore after `i`, `q`, Ctrl-C and closed stdin: check those in a real
run. A visible menu change re-runs `docs/screenshot.sh`.

Report review findings most severe first, each with `file:line` and the rule it
breaks.
