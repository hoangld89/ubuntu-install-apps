# Two-pane menu design (2026-10-02)

Goal: replace the collapsible single-column menu with a lazygit-style two-pane layout (groups left, apps of the focused group right), fix the menu's colour roles and contrast, and move the primary action and settings keys to where they are read. Pure bash, no new dependencies; the no-fork redraw rule stays.

## Decisions (user, 2026-10-02)

- D1 Layout: two panes (option B of three mockups); single-column layout remains for terminals under 80 columns or too short for the panes.
- D2 Settings (mirror, IME, .NET, login shell) live in a Settings section at the bottom of the left pane, next to their keys.
- D3 Taglines render inside the right pane, truncated with `…`; there is no separate detail line.
- D4 Footer is one line: navigation hints left, `q quit` and an `i install N` button right-aligned.
- D5 Every accent colour has one role (table below); selected rows in uninstall mode are red.
- D6 Banner stays; the gradient rule under it and the large selection progress bar go.

## Discovery

Verified:
- Menu rendering, state and keys are all in `lib/ui-menu.sh` (`print_menu`, `group_row`, `item_row`, `build_hints`, `read_key`, `interactive_menu`).
- `item_row()` colours a selected app `C_GREEN` in both modes, so in `--uninstall` "will be removed" reads as "good".
- Unselected taglines use `C_SURFACE2`: contrast 2.5:1 on Catppuccin base `1e1e2e`, 1.9:1 on `BG_SURFACE` (`313244`). `C_OVERLAY` is 3.4:1, `C_SUBTEXT` 7.4:1.
- `APP_GROUPS` format is `"key|Title|icon|ascii-icon"` in `lib/registry.sh`; the loop after it fills `GROUP_LABEL`, `GROUP_ICON`, `GROUP_ICON_ASCII`; `validate_registry` checks groups, app files and functions.
- Largest group is `desktop` with 10 apps; there are 5 groups.
- Undo functions never read `MIRROR_HOST`, `IME_ENGINE` or `DOTNET_VERSIONS`, so settings are meaningless in uninstall mode.
- `ACTION_LABEL` is `Install` / `Remove` (`lib/runner.sh`); `main` already exits with "Nothing selected" when `count_selected` is 0.
- `ui_term_size` is shared with `lib/runner.sh` and `lib/ui-run.sh` reads `UI_W`; neither may change meaning.
- Box glyphs exist only as `RB_TL`, `RB_BL`, `RB_H`, `RB_V` in `lib/core.sh`.
- README "Menu" section holds a menu screenshot and the key table.

Assumed:
- The terminal background is Catppuccin base or similarly dark; contrast numbers shift on other backgrounds. Not checkable from code.

## Layout (90 columns, install mode)

```
  █▀▀ █▀▀ ▀█▀ █ █ █▀█   ubuntu setup · post-install toolkit
  ▄▄█ ██▄  █  █▄█ █▀▀   v1.1.0 · Ubuntu 26.04 · hoangle · zsh

  ╭─ Groups ─────────────────╮ ╭─ Languages & IDEs ─────────────────────────────── 6/9 ─╮
  │   ⚙ System         8/8   │ │▌● Node.js LTS       managed by nvm, swap versions on … │
  │ ▌ ◆ Languages      6/9   │ │ ○ Bun               all-in-one JS runtime & toolkit, … │
  │   ▲ DevOps         5/5   │ │ ● pnpm              fast, disk-efficient package mana… │
  │   ⬡ Databases      0/4   │ │ ● Yarn 4            the Berry JS package manager via … │
  │   ◎ Desktop      10/10   │ │ ● .NET SDK          build & run cross-platform… 8 · 10 │
  ├──────────────────────────┤ │ ○ ABP CLI           ABP Studio CLI for building ABP a… │
  │  m  mirror BizFly Cloud  │ │ ● VS Code           the editor that does it all        │
  │  g  IME    Bamboo        │ │ ○ Trae IDE          AI-native coding by ByteDance      │
  │  d  .NET   8 · 10        │ │ ● Claude Code       Anthropic's agentic dev CLI        │
  │  s  login  zsh           │ │                                                        │
  ╰──────────────────────────╯ ╰────────────────────────────────────────────────────────╯
   ↑↓ move  ←→ panel  space toggle  a all  n none                 q quit   i  install 27 
```

Geometry:
- Total width is `UI_W` (unchanged: `cols - 3`, clamped 40–96). Left pane is 28 columns, one space gap, right pane takes the rest.
- Two-pane mode needs `UI_COLS >= 80` and enough rows for both borders, the full left pane (groups + Settings rows) and the footer; otherwise the single-column menu renders.
- Pane height `PANE_H` = max(groups + Settings rows, largest group), so it never changes when the focused group changes. Settings rows = separator + 4 in install mode, 0 in uninstall. Capped by available rows but never below the left pane's content; the banner hides first (existing rule), then the right pane scrolls with `↑ n more` / `↓ n more` rows inside the pane.
- Right pane title: full group label left, `sel/total` right in the group count colour.
- Left pane rows: icon, short group label (11 columns), `sel/total`. Settings rows: key pill, name padded to 7, value in `C_SAPPHIRE` (13 columns).
- Settings values: mirror = its `MIRRORS` label up to the first ` — ` or ` (`; IME = engine label; .NET = versions joined by ` · `; login = `zsh` when `ZSH_LOGIN_SHELL=1`, `keep` otherwise. All pass through `ui_trunc`.
- App rows: dot, name padded to 18, tagline, and the `item_chip` value as right-edge chip for `dotnet` only; mirror, IME and login values show in Settings.
- Footer (both layouts): left hints, right `q quit` then the button. When both do not fit (two-pane at 80–83 columns), the left hints move to their own line above. `d` `m` `g` `s` hints appear in the single-column footer in install mode only.
- Button: ` i  install N ` with `ACTION_LABEL` lower-cased; `N` is the selected count. With N = 0 it uses `BG_SURFACE` + `C_OVERLAY`.

## Colour roles

| Role | Colour |
|---|---|
| Focused pane border and title, cursor bar `▌` | `C_MAUVE` (uninstall: `C_RED`) |
| Unfocused pane border | `C_SURFACE2` |
| Focused group in the left pane while the right pane has focus | `BG_SURFACE` row, no bar |
| Group icon | `C_LAVENDER` |
| Settings values and the `.NET` chip | `C_SAPPHIRE` |
| Selected app, install | `●` `C_GREEN`, name `C_TEXT` |
| Selected app, uninstall | `●` `C_RED`, name `C_TEXT` |
| Unselected app | `○` `C_OVERLAY`, name `C_SUBTEXT` |
| Tagline | `C_OVERLAY`; `C_SUBTEXT` on the cursor row |
| Group counts | all `C_GREEN`, some `C_YELLOW`, none `C_OVERLAY` |
| Action button | `BG_MAUVE` + `C_BASE` bold (uninstall: `BG_RED`, ` i  remove N `) |
| Footer key pills | `ui_pill` (`BG_SURFACE` + `C_TEXT`) |

The single-column layout uses the same app-row and tagline colours.

ASCII mode: borders `+ - |`, separator `+---+`, button `[i install N]`, cursor bar `|`.

## Keys

| Key | Left pane (groups) | Right pane (apps) |
|---|---|---|
| `↑` `↓` / `k` `j` | Move group; right pane follows | Move app |
| `→` / `l` / `Tab` / `Enter` | Focus right pane | — |
| `←` / `h` / `Tab` | — | Focus left pane |
| `Space` | Toggle whole group | Toggle app |
| `a` `n` | Select all / none | same |
| `d` `m` `g` `s` | Settings, install mode only (both layouts) | same |
| `i` / `q` | Start / quit | same |

Single-column mode keeps its other keys; `←` `→` `h` `l` `Tab` are ignored there.

## State and data flow

- New globals in `lib/ui-menu.sh`: `FOCUS` (`groups`|`apps`), `GROUP_CURSOR`, `APP_CURSOR`, `APP_TOP`. Moving the group cursor resets `APP_CURSOR` and `APP_TOP` to 0. The single-column `CURSOR` / `GROUP_EXPANDED` state stays separate, so a resize across 80 columns switches layout without corrupting either.
- `print_menu` computes the layout once per redraw, builds the left and right pane rows into two arrays of `(coloured, plain length)` pairs, joins them line by line with borders, then appends the footer and calls `render_menu`.
- Every new helper returns via `REPLY` or fills a global array; no `$(...)` in the per-row path.

## Error handling

- Clamp `GROUP_CURSOR`, `APP_CURSOR`, `APP_TOP` after every move and resize (the `clamp_cursor` pattern, ending in `return 0` for `set -e`).
- `read_key` maps `ESC [C` / `ESC OC` → `RIGHT`, `ESC [D` / `ESC OD` → `LEFT`, `$'\t'` → `TAB`, `l` / `h` → `RIGHT` / `LEFT`.
- `validate_registry` fails when a group has an empty short label or one longer than 11 characters (left-pane width).

## Out of scope

`ui_term_size` (two `tput` calls) and `key=$(read_key)` fork once per keypress; that is per key, not per row, and stays.

## Implementation plan

Branch `feat/two-pane-menu`, squash-merged PR, release `v1.1.0`.

| File | Change | Why |
|---|---|---|
| `lib/core.sh` | `TOOLKIT_VERSION="1.1.0"`; add `C_BASE` (`1e1e2e`/234), `BG_MAUVE` (`cba6f7`/183), `BG_RED` (`f38ba8`/211), clear them in `ui_plain`; add `RB_TR`, `RB_BR`, `RB_LT`, `RB_RT` with ASCII `+` in `setup_glyphs` | Button colours, closed pane borders, MINOR bump for a new layout |
| `lib/registry.sh` | `APP_GROUPS` becomes `"key|Title|Short|icon|ascii-icon"`; fill `GROUP_SHORT`; `validate_registry` checks the short label | Left pane needs short names |
| `lib/ui-menu.sh` | Read the new `APP_GROUPS` field order; add pane state, `pane_layout`, `groups_pane`, `apps_pane`, `settings_rows`, `pane_border`, `action_button`, `build_footer`; split `print_menu` into two-pane and single-column paths sharing `build_footer`; `build_banner` without the gradient rule; `item_row` uses the new colour roles; `item_chip` keeps its output (the run view in `lib/runner.sh` shows it as step detail); `read_key` gains `LEFT`/`RIGHT`/`TAB`; `interactive_menu` dispatches keys by layout and focus and handles `d m g` in install mode only | The redesign itself |
| `README.md` | Replace the Menu screenshot (version `v1.1.0`) with the two-pane layout; update the key table (panes, Tab, settings install-only) | Docs match behaviour |
| `CLAUDE.md` | `APPS`/`APP_GROUPS` format line gains `Short`; add the new `REPLY`-returning helpers to the no-fork list | Invariants stay accurate |

## Verification criteria

- `bash -n` on every file, `shellcheck -x install-app.sh`, `validate_registry` passes; a group with a 12-character short label makes it fail.
- Render `print_menu` non-interactively (source `install-app.sh`, define `tput() { case "$1" in cols) echo W;; lines) echo H;; esac; }`) at 120×40, 90×40, 80×24, 79×24 and 90×16 in install, uninstall and `--ascii` modes; strip escapes and check: every line ≤ `UI_COLS`, right borders aligned, pane heights equal, two-pane at ≥ 80 columns and single-column below.
- Focus each group: pane height constant; `desktop` (10 apps) scrolls at 90×16 with correct `more` counts.
- Uninstall: selected dots and button red, button reads `remove N`, Settings hidden, `d m g s` do nothing in both layouts.
- Run view: step lines still show mirror host, `.NET` versions, IME engine and login chip.
- N = 0: button dimmed.
- Keys: arrows, `h j k l`, Tab, Enter, Space on both panes; `ESC O C` / `ESC O D` under tmux.
- Resize across 80 columns mid-session: no `set -u` error, cursor stays in range.
- Count `$(` and external commands inside the redraw path: none added.
- Real run in a terminal (`./install-app.sh`, quit with `q`) to confirm truecolor and 256-colour rendering.
