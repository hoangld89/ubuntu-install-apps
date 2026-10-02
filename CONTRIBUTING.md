# Contributing

## Project layout

```
install-app.sh     entrypoint
lib/               core, registry (APPS, APP_GROUPS), apt, shell-rc, shared, ui-menu, ui-run, runner
apps/<key>.sh      do_<key> (install) + undo_<key> (uninstall), one file per app
docs/screenshot.sh regenerates docs/images/menu.png (needs python3-rich and Chrome/Chromium)
```

## Adding an app

1. Add `"key|group|Name::tagline|default_on"` to `APPS` in `lib/registry.sh`. Array order is install order.
2. Create `apps/<key>.sh` with both functions:

```bash
do_myapp() {
    if command -v myapp &>/dev/null; then
        success "My App already installed, skipping"
        return
    fi
    info "Installing My App..."
    apt-get install -y myapp
}

undo_myapp() {
    apt_purge myapp
}
```

3. Add a row to the [Apps](README.md#apps) table in the README.

Steps run with `set -e`; guard expected failures with `|| true` and add apt repos with `add_apt_repo`. `validate_registry` exits at startup if the group, file or a function is missing. Full conventions and invariants are in [CLAUDE.md](CLAUDE.md).

## Before opening a PR

```bash
for f in install-app.sh lib/*.sh apps/*.sh; do bash -n "$f"; done
shellcheck -x install-app.sh
bash -c 'source ./install-app.sh && validate_registry'
```

## Pull requests

`main` is protected. Work on a `feat/…`, `fix/…` or `docs/…` branch and open a PR; it is squash-merged. Bump `TOOLKIT_VERSION` in `lib/core.sh` following SemVer: MAJOR for removed apps, flags or behaviour users rely on; MINOR for new apps or options; PATCH for fixes.
