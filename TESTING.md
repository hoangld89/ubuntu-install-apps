# Testing

How to test `install-app.sh` **safely**, without touching your real machine.

The script installs packages, adds apt repos, writes to `/etc`, changes your
default shell and installs fonts. You never want to run an unverified version of
it directly on your workstation. Instead, run it inside a **disposable Ubuntu
container** — every change happens inside the container and is thrown away the
moment it exits (`--rm`).

## Prerequisites

- Docker (on WSL: enable Docker Desktop's WSL integration, or run `dockerd`).
- Verify it works: `docker info` should succeed.

All commands below are wrapped by the helper script [`test-docker.sh`](./test-docker.sh).

## Layers of testing

From cheapest/safest to most realistic:

| Layer | Command | What it catches |
|-------|---------|-----------------|
| Syntax | `bash -n install-app.sh` | parse errors |
| Static analysis | `./test-docker.sh lint` | quoting bugs, unused vars, unsafe patterns |
| Runtime smoke | `./test-docker.sh func terminal eza font` | functions that crash at runtime |
| Non-interactive full | `./test-docker.sh all` | the whole install path end-to-end |
| Interactive | `./test-docker.sh` | the TUI menu, key handling, confirmation gates |

> `bash -n` and `shellcheck` are static — they cannot catch things like an
> `unbound variable` that only triggers under `set -u` in a real environment.
> That class of bug is exactly what the container layers find.

## The helper: `test-docker.sh`

```bash
./test-docker.sh                 # interactive INSTALL menu (TUI)
./test-docker.sh uninstall       # interactive UNINSTALL menu (TUI)
./test-docker.sh all             # non-interactive: install everything
./test-docker.sh help            # run --help
./test-docker.sh lint            # shellcheck via koalaman/shellcheck container
./test-docker.sh func KEY...     # source the script, run do_<KEY> for each KEY
./test-docker.sh shell           # drop into a bash shell in the container
```

Environment overrides:

```bash
IMAGE=ubuntu:22.04 ./test-docker.sh        # test on a different Ubuntu release
PRIVILEGED=1       ./test-docker.sh all     # add --privileged (swap/docker can run)
```

### How `func` works

The script guards its entry point:

```bash
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

so it can be `source`d without running the menu. `test-docker.sh func terminal eza font`
sources the script inside the container (as root, so no sudo re-exec) and calls
`do_terminal`, `do_eza`, `do_font` in turn — a fast way to confirm individual
installers don't crash.

## What legitimately fails in a plain container

These are **environment limits, not script bugs**. Don't chase them unless you
add `PRIVILEGED=1` or use a systemd-enabled image:

- **swap** — `swapon` is blocked in an unprivileged container.
- **docker / systemctl** — no init system / daemon inside the container.
- **GUI apps** (Chrome, Edge, Teams, VLC, fcitx5, …) — the `.deb` installs, but
  the app obviously can't launch.
- **`/dev/tty`** — when you pipe input instead of attaching a TTY, prompts that
  read from `/dev/tty` fall back to their default (the script handles this).

## Manual verification examples

Confirm the Nerd Font really registered with fontconfig:

```bash
./test-docker.sh shell
# inside the container:
apt-get update -qq && source /mnt/install-app.sh && do_font
fc-list | grep -i 'MesloLGS NF'      # should list 4 faces
```

Confirm the minimal zsh plugin set:

```bash
./test-docker.sh func terminal
# then inspect /root/.zshrc inside the container:
#   plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
```

## Cleanup

Containers are started with `--rm`, so they self-destruct on exit. To reclaim
the pulled base/lint images:

```bash
docker image rm ubuntu:24.04 koalaman/shellcheck:stable
```
