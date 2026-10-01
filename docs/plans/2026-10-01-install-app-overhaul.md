# install-app.sh overhaul plan (2026-10-01)

Goal: every step either succeeds or is reported as failed with the failing command; re-runs are safe and move old installs onto the current upstream method; uninstall removes exactly what install added. One pass, in dependency order: framework → installers → docs → verify.

Source: audit by 3 review agents, plan audit (2026-10-01), manual confirmation of every high-severity item.

## Decisions (user, 2026-10-01)
- D1 Node: latest LTS (`nvm install --lts`). Today that is 24 (Krypton); Node 26 becomes LTS around late Oct 2026 and re-runs follow it.
- D2 Yarn: Yarn 4 (Berry).
- D3 adminuser: drop the feature.
- D4 .NET 8/9 from `ppa:dotnet/backports`, 10 from the Ubuntu archive. Both 8 and 9 reach end of support on 2026-11-10; the menu marks them as such.

## Phase 1 — Framework

- [x] F1. `run_remote_script`: delete the temp script explicitly before each `return`; the function sets no traps. (Current RETURN trap fires again in the caller and `set -u` aborts the whole run — confirmed.)
- [x] F2. Step runner in `main()`. `print_step_header`, `succeeded`, `failed` stay in the parent. Each step runs as a plain statement (any `if`/`||`/`&&`/`!` context disables both `set -e` and the ERR trap — verified on bash 5.3):
  ```bash
  set +e
  ( set -eE
    trap '_rc=$?; (( BASH_SUBSHELL == 1 )) && echo "  ✗ \"$BASH_COMMAND\" exited $_rc (line $LINENO)" >&2' ERR
    "${prefix}${key}" )
  rc=$?
  set -e
  ```
  The trap writes to stderr and only reports at subshell depth 1, so `$(…)` captures stay clean. The failing command/line is also recorded for the summary (F5).
  Prerequisite edits so intended soft failures don't abort a step:
  - `do_font`: `faces=$(fc-list | grep -ci 'MesloLGS NF' || true)`.
  - `do_terminal`: the oh-my-zsh setup `su` call fails the step explicitly (cleanup temp file, `fail`, `return 1`).
  - `do_update`: `apt-get update && … || return 1`.
  - Steps that create temp files (`do_azcopy`, `do_browserstack`, `do_postman`, `do_navicat`, `.deb` installers via `download_deb`) clean them with a step-local `trap 'rm -rf …' EXIT` (safe: each step is its own subshell).
  - Multi-command install blocks run through `su - user -c` start with `set -e` (nvm, pnpm/yarn, abp install blocks); probe blocks stay as they are.
  Unguarded `apt-get update` calls now fail their step — intended.
- [x] F3. apt robustness: `export DEBIAN_FRONTEND=noninteractive`; `/etc/apt/apt.conf.d/99install-app-run` with `DPkg::Lock::Timeout "600";` written at start of the install loop and removed on exit; `do_update` uses `-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold`; script code uses `apt-get`.
- [x] F4. `add_apt_repo` helper: `add_apt_repo <list-path> <key-url> <key-path> <dearmor:0|1> <repo-content>`. Downloads the key with `curl -fsSL` to a temp file, rejects empty, dearmors with `gpg --batch --yes` when asked, installs key + repo file, runs `apt-get update`; any failure removes key + repo file and returns 1. Each repo keeps its current file names (no duplicate sources on machines that already ran the script; undo paths unchanged).
  `ensure_microsoft_gpg` follows the same rules (`-s` guard, temp file + `mv`, return 1).
  Users: terraform, docker, fcitx5-lotus, anydesk (repo URL `https://deb.anydesk.com`), waydroid, teams (`ensure_teams_repo` becomes a call), dbeaver (A4), Microsoft repos (edge, vscode, azcli, dotnet via `ensure_microsoft_gpg`).
- [x] F5. Logging: after the menu returns (the TUI keeps the real terminal), output is teed to `/var/log/install-app/<YYYYmmdd-HHMMSS>.log`. The summary lists each failed step with its failing command + line and prints the log path. An INT/TERM trap during the install loop prints the partial summary.
- [x] F6. Reboot hint printed only with collected reasons (docker group added, login shell changed, fcitx5/`/etc/environment` changed, `/var/run/reboot-required` present). Steps report a reason by appending to a file under `/run/install-app/` (subshell-safe).
- [x] F7. `validate_registry` at startup: each APPS key appears in exactly one APP_GROUPS csv and has `do_`/`undo_` functions; otherwise exit naming the key.
- [x] F8. Framework details: `REAL_HOME` from `getent passwd`; abort with a message when the target user is root; `need_root` passes `MINT_ASCII` through sudo; `get_ubuntu_codename` reads os-release in a subshell; `read_key` decodes `ESC O A/B` and j/k; the release check accepts `UBUNTU_CODENAME=resolute`.
- [x] F9. rc handling: `strip_rc_block` deletes only when both markers exist (exact-match awk, `$rc.bak` first); `write_tool_integrations` replaces its block on every run so script updates reach existing machines; `resolve_shell_rc` decides from zsh actually installed; the integration trigger list includes `abp` and `yarn`; `DOTNET_ROOT` comes from `readlink -f /usr/bin/dotnet`; the block has no Cargo line.
- [x] F10. Wayland IME: the hook inserts flags after the real binary when `Exec=` starts with `env VAR=…`; uninstall removes `ELECTRON_OZONE_PLATFORM_HINT` from `/etc/environment` when no listed launcher remains.

## Phase 2 — Installers

System
- [x] S1. `do_mirror`: if `apt-get update` fails on the new mirror, restore the `.bak` files, update again, return 1.
- [x] S2. adminuser removed from APPS, APP_GROUPS, functions, README, CLAUDE.md. (No `administrator` account exists on this machine.)

Shell & fonts
- [x] T1. `do_terminal`: Oh My Zsh via `run_remote_script` with checked rc; zsh plugins appended only when missing from the user's `plugins=(…)`.
- [x] T2. `undo_terminal`: package list without `batcat` (its presence makes the whole purge fail — confirmed); `apt_purge` purges only installed packages; the shared Tool-integrations block stays in `.bashrc` while other runtimes are installed; `.zshrc.pre-oh-my-zsh` restored when present.
- [x] T3. `do_font`: each face downloads to a temp file and moves into place on success; skip only when all 4 faces exist.
- [x] T4. `do_msfonts`: package installed but fonts missing → `apt-get install --reinstall ttf-mscorefonts-installer`.
- [x] T5. `do_eza` / `do_fastfetch`: install from the 26.04 archive only (eza 0.23.4, fastfetch 2.57.1 are there). `undo_eza` keeps removing a leftover gierens repo from older runs.

Runtimes
- [x] R1. `do_nvm`: installer runs with `PROFILE=/dev/null` (the marked Tool-integrations block is the only rc wiring); installer and `nvm install --lts` exit codes checked; `nvm alias default 'lts/*'`; skip decided by an installed LTS node, not by `nvm.sh` existing. The unmarked NVM lines a previous nvm install appended to `.bashrc`/`.zshrc` are removed.
- [x] R2. pnpm + Yarn 4 through the standalone `corepack` npm package (Node ≥ 25 no longer bundles corepack; its bins provide `pnpm` and `yarn`): `npm i -g corepack`, then `corepack install -g pnpm@latest` / `corepack install -g yarn@stable`. Idempotency checks source nvm before probing. The `get.pnpm.io` fallback is gone (it always edits rc files, no opt-out).
- [x] R3. `undo_bun`: removes exactly the installer's `# bun` block (comment + `BUN_INSTALL` + `PATH` lines) and the `# bun completions` lines. (Current sed range deletes to end of file — confirmed.)
- [x] R4. `undo_pnpm`: removes the `# pnpm` … `# pnpm end` block left by older `get.pnpm.io` installs.
- [x] R5. .NET: menu offers 8, 9, 10 (8/9 labelled "EOL 2026-11-10"), input validated; 10 from the archive, 8/9 from `ppa:dotnet/backports`; everything lives in `/usr/lib/dotnet`; no `dotnet-install.sh` fallback; return 1 when any version failed; undo package globs include targeting/apphost/template packs and removes the PPA when it added it.

Apps
- [x] A1. `do_trae`: download URL from `api.trae.ai/icube/api/v1/native/version/trae/latest` → `data.manifest.linux.download[].["x64.deb"]` (package name `trae`). The resolved URL is stored in `/var/lib/install-app/trae.url`; a re-run reinstalls when the API URL differs (the version fields in the API, URL and package disagree, so the URL is the comparison key).
- [x] A2. `do_navicat`: download checked (non-empty file); `VERSION` written only after a successful install.
- [x] A3. `do_postman`: `tar --no-same-owner` + `chown -R root:root /opt/Postman` (current owner uid 1001 does not exist — confirmed); download checked; re-run fixes ownership on existing installs.
- [x] A4. `do_dbeaver`: official apt repo (`deb [signed-by=/usr/share/keyrings/dbeaver.gpg.key] https://dbeaver.io/debs/dbeaver-ce /`, key `https://dbeaver.io/debs/dbeaver.gpg.key`) through `add_apt_repo`; an existing .deb install moves onto it on re-run; undo removes repo + key.
- [x] A5. Claude Code: `do_claude` checks the installer rc and `~/.local/bin/claude`; `undo_claude` removes `~/.local/bin/claude` and `~/.local/share/claude` (official uninstall; currently 692 MB left behind — confirmed), config in `~/.claude` kept.
- [x] A6. `do_docker`: installed state = `dpkg -s docker-ce`; first purges the conflicting packages from Docker's docs (`docker.io docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc`, only those installed).
- [x] A7. `do_azcopy` / `do_browserstack` / `do_obs`: downloads and `add-apt-repository` checked.
- [x] A8. Undo details: `undo_vscode` removes `vscode.{list,sources}`; `undo_teamviewer` key line points at `/usr/share/keyrings/teamviewer-keyring.gpg`; `undo_docker` warning names `/var/lib/docker`, `/var/lib/containerd`, `/etc/docker`; `undo_navicat` mentions `unixodbc-dev` stays installed.

## Phase 3 — Docs
- [x] DOC1. README: app count 36, group table + menu mock match `APP_GROUPS`, runtime rows (Node LTS via nvm, pnpm/Yarn via corepack npm package, .NET 8/9/10 sources), Trae/DBeaver/Teams sources, log file location, reboot hint behaviour.
- [x] DOC2. CLAUDE.md: app count, registry line, step runner/error model, `add_apt_repo`, logging, reboot reasons; registry comment on mirror default; `msfonts` line indentation; unused APP_GROUPS icon field removed from the format.

## Phase 4 — Verify
- [x] V1. `bash -n`, shellcheck with no warnings beyond the 2 pre-existing ones.
- [x] V2. Sandbox tests (scratchpad, sourcing the script): `strip_rc_block` with a missing end marker; `undo_bun` block removal on a copy of a real rc; `add_apt_repo` with a bad key URL (rollback leaves no file, `apt-get update` clean); step runner (failing command → step reported failed with line, next step still runs, `$(…)` output unaffected); `run_remote_script` followed by a second step.
- [x] V3. Live run on this machine, install mode, selecting every installed app except `update` (no full system upgrade). Expected changes, shown to the user before the run: nvm lines cleanup in rc files, pnpm/yarn moved to the corepack npm package, DBeaver moved to its apt repo (26.1.2 → 26.2.1), Trae URL marker written (reinstall if the API URL is newer), Postman ownership fixed, Tool-integrations block rewritten. Then: second identical run → every step skips, rc 0; check log and summary.
- [x] V4. verifier skill, then commit + push.

## Out of scope
- AzCopy via apt: Microsoft's resolute repo has no azcopy package yet.
- Docker deb822 layout: the current `.list` works.
- Launcher override copies in `/usr/local/share/applications`: the dpkg hook keeps package launchers current.
- Version checks for Postman (self-updates once ownership is fixed) and Navicat (has its own upgrade path).
