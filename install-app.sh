#!/usr/bin/env bash
# dash parses line by line, so this re-exec runs before any bash-only syntax is read.
if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi
set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

# shellcheck source=lib/core.sh
source "$SCRIPT_DIR/lib/core.sh"
# shellcheck source=lib/registry.sh
source "$SCRIPT_DIR/lib/registry.sh"
# shellcheck source=lib/apt.sh
source "$SCRIPT_DIR/lib/apt.sh"
# shellcheck source=lib/shell-rc.sh
source "$SCRIPT_DIR/lib/shell-rc.sh"
# shellcheck source=lib/shared.sh
source "$SCRIPT_DIR/lib/shared.sh"
# shellcheck source=lib/ui-menu.sh
source "$SCRIPT_DIR/lib/ui-menu.sh"
# shellcheck source=lib/ui-run.sh
source "$SCRIPT_DIR/lib/ui-run.sh"
# shellcheck source=lib/runner.sh
source "$SCRIPT_DIR/lib/runner.sh"
for _app in "$SCRIPT_DIR"/apps/*.sh; do
    # shellcheck source=/dev/null
    source "$_app"
done
unset _app

# Only run main when executed directly — allows sourcing for tests.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
