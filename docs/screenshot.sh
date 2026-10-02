#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
OUT="$ROOT/docs/images/menu.png"
COLS=100
ROWS=30

python3 -c 'import rich' 2>/dev/null || { echo "python3 rich is missing: sudo apt install python3-rich" >&2; exit 1; }
fc-list 2>/dev/null | grep -i 'MesloLGS NF' >/dev/null || { echo "MesloLGS NF font is missing (installed by the Fonts app)" >&2; exit 1; }
CHROME=""
for c in google-chrome chromium chromium-browser; do
    if command -v "$c" >/dev/null; then CHROME=$c; break; fi
done
[[ -n "$CHROME" ]] || { echo "Chrome or Chromium is needed to render the PNG" >&2; exit 1; }

# Snap Chromium has a private /tmp, so the work files live inside the repo.
WORK=$(mktemp -d "$ROOT/docs/.shot.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

frame() {
    export COLORTERM=truecolor LC_ALL=C.UTF-8 MINT_ASCII=0
    # shellcheck source=../install-app.sh
    source "$ROOT/install-app.sh"
    setup_glyphs
    tput() { case "$1" in cols) echo "$COLS" ;; lines) echo "$ROWS" ;; esac; }
    get_ubuntu_version() { echo 26.04; }
    user_login_shell() { echo /usr/bin/zsh; }
    REAL_USER=user MODE=install
    mode_theme
    init_defaults
    SELECTED[bun]=0; SELECTED[abp]=0; SELECTED[trae]=0
    GROUP_CURSOR=1; FOCUS=apps; APP_CURSOR=1
    build_menu_info
    render_menu() { printf '%s\n' "${MENU_LINES[@]}"; }
    print_menu
}
(frame) > "$WORK/menu.ansi"

dims=$(python3 - "$WORK/menu.ansi" "$WORK/menu.svg" $(( COLS - 1 )) <<'PY'
import re, sys
from rich.console import Console
from rich.terminal_theme import TerminalTheme
from rich.text import Text

src, dst, cols = sys.argv[1], sys.argv[2], int(sys.argv[3])
mocha = TerminalTheme((30, 30, 46), (205, 214, 244), [
    (69, 71, 90), (243, 139, 168), (166, 227, 161), (249, 226, 175),
    (137, 180, 250), (245, 194, 231), (148, 226, 213), (186, 194, 222)])
console = Console(record=True, width=cols, force_terminal=True, color_system="truecolor", file=open("/dev/null", "w"))
console.print(Text.from_ansi(open(src, encoding="utf-8").read().rstrip("\n")), crop=False, soft_wrap=True)
svg = console.export_svg(title="./install-app.sh", theme=mocha).replace(
    "font-family: Fira Code, monospace", 'font-family: "MesloLGS NF", monospace')
open(dst, "w", encoding="utf-8").write(svg)
w, h = re.search(r'viewBox="0 0 ([\d.]+) ([\d.]+)"', svg).groups()
print(round(float(w)), round(float(h) + 0.5))
PY
)
read -r width height <<< "$dims"
[[ "$width" =~ ^[0-9]+$ && "$height" =~ ^[0-9]+$ ]] || { echo "Bad SVG size: '$dims'" >&2; exit 1; }

printf '<!doctype html><style>html,body{margin:0}img{display:block;width:%spx}</style><img src="menu.svg">\n' "$width" > "$WORK/page.html"
rm -f "$OUT"
"$CHROME" --headless=new --no-sandbox --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
    --default-background-color=00000000 --window-size="$width,$height" \
    --screenshot="$OUT" "file://$WORK/page.html" > "$WORK/chrome.log" 2>&1 || true
[[ -s "$OUT" ]] || { cat "$WORK/chrome.log" >&2; echo "Chrome did not write $OUT" >&2; exit 1; }

# A terminal frame has few colours, so a 256-colour palette shrinks the PNG several-fold with no visible change.
python3 - "$OUT" <<'PY' || echo "Pillow not found; leaving the PNG unquantised" >&2
import sys
try:
    from PIL import Image
except ImportError:
    sys.exit(1)
img = Image.open(sys.argv[1])
img.quantize(256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).save(sys.argv[1], optimize=True)
PY
echo "Wrote $OUT"
