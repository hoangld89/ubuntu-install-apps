#!/usr/bin/env bash
#
# test-docker.sh — Safely test install-app.sh inside a disposable Ubuntu container.
#
# Nothing here touches your host: every apt install, /etc write and shell change
# happens inside the container, which is removed (--rm) the moment it exits.
#
# Usage:
#   ./test-docker.sh                 Open the interactive INSTALL menu (TUI)
#   ./test-docker.sh uninstall       Open the interactive UNINSTALL menu (TUI)
#   ./test-docker.sh all             Non-interactive: install everything
#   ./test-docker.sh help            Just run --help
#   ./test-docker.sh lint            Run shellcheck via container
#   ./test-docker.sh func KEY...     Source the script and run do_<KEY> for each
#                                    KEY (e.g. terminal eza font). Quick crash test.
#   ./test-docker.sh shell           Drop into a bash shell in the container
#
# Env:
#   IMAGE=ubuntu:22.04 ./test-docker.sh     Override the base image (default 24.04)
#   PRIVILEGED=1 ./test-docker.sh all       Add --privileged (lets swap/docker run)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="${IMAGE:-ubuntu:24.04}"
RUN_OPTS=(--rm -v "$SCRIPT_DIR:/mnt:ro")
[[ "${PRIVILEGED:-0}" == "1" ]] && RUN_OPTS+=(--privileged)

cmd="${1:-menu}"; shift || true

case "$cmd" in
    menu|"")
        docker run -it "${RUN_OPTS[@]}" "$IMAGE" bash /mnt/install-app.sh
        ;;
    uninstall)
        docker run -it "${RUN_OPTS[@]}" "$IMAGE" bash /mnt/install-app.sh --uninstall
        ;;
    all)
        docker run -it "${RUN_OPTS[@]}" "$IMAGE" bash /mnt/install-app.sh --all
        ;;
    help)
        docker run "${RUN_OPTS[@]}" "$IMAGE" bash /mnt/install-app.sh --help
        ;;
    lint)
        docker run --rm -v "$SCRIPT_DIR:/mnt:ro" koalaman/shellcheck:stable \
            --severity=warning /mnt/install-app.sh
        ;;
    func)
        [[ $# -gt 0 ]] || { echo "Usage: $0 func KEY [KEY...]"; exit 1; }
        # Source the script (main is guarded by BASH_SOURCE check), then call each
        # do_<KEY>. Runs as root inside the container, so no sudo re-exec needed.
        fns=""; for k in "$@"; do fns+="do_${k}; "; done
        docker run -it "${RUN_OPTS[@]}" "$IMAGE" bash -c "
            set -euo pipefail
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq
            source /mnt/install-app.sh
            $fns
            echo '--- all requested do_ functions returned without crashing ---'
        "
        ;;
    shell)
        docker run -it "${RUN_OPTS[@]}" "$IMAGE" bash
        ;;
    *)
        echo "Unknown command: $cmd"
        grep '^#' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
        exit 1
        ;;
esac
