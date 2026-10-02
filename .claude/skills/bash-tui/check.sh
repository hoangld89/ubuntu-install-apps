#!/usr/bin/env bash
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../../.." || exit 1
fail=0

for f in install-app.sh lib/*.sh apps/*.sh; do bash -n "$f" || fail=1; done
if command -v shellcheck >/dev/null; then shellcheck -x install-app.sh || fail=1; else echo "FAIL shellcheck not installed"; fail=1; fi
bash -c 'source ./install-app.sh && validate_registry' || fail=1

render() {
    # shellcheck disable=SC2016
    COLS=$1 ROWS=$2 MODE=$3 MINT_ASCII=$4 COLORTERM=$5 bash -c '
        source ./install-app.sh; setup_glyphs
        tput() { case "$1" in cols) echo "$COLS" ;; lines) echo "$ROWS" ;; esac; }
        get_ubuntu_version() { echo 26.04; }; user_login_shell() { echo /usr/bin/zsh; }
        REAL_USER=user; mode_theme; init_defaults; build_menu_info; print_menu' </dev/null \
        | sed 's/\x1b\[[0-9;?]*[A-Za-z]//g'
}

frames=0
for size in 120x40 80x24 60x20; do
    cols=${size%x*} rows=${size#*x}
    for variant in "install 0 truecolor" "install 1 truecolor" "install 0 -" "uninstall 0 truecolor"; do
        read -r mode ascii colorterm <<< "$variant"
        [[ "$colorterm" == - ]] && colorterm=""
        label="$size $mode ascii=$ascii colorterm=${colorterm:-none}"
        if ! frame=$(render "$cols" "$rows" "$mode" "$ascii" "$colorterm"); then
            echo "FAIL $label: render exited non-zero"; fail=1; continue
        fi
        height=$(wc -l <<< "$frame")
        width=$(LC_ALL=C.UTF-8 wc -L <<< "$frame")
        if (( height < 5 || height > rows || width >= cols )); then
            echo "FAIL $label: $height rows, $width columns"; fail=1
        fi
        if (( ascii )) && LC_ALL=C grep -q $'[\x80-\xff]' <<< "$frame"; then
            echo "FAIL $label: non-ASCII output"; fail=1
        fi
        frames=$((frames + 1))
    done
done

(( fail )) || echo "ok: static checks and $frames frames"
exit "$fail"
