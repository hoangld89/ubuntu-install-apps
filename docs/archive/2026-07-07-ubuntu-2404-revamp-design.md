# Thiết kế: Nâng cấp install-app.sh cho Ubuntu 24.04

Ngày: 2026-07-07 · File chạm: `install-app.sh`, `CLAUDE.md`, `README.md`

## Mục tiêu

1. Script hỗ trợ chính Ubuntu 24.04 (noble), bỏ code Linux Mint.
2. Bộ gõ cho chọn engine: Unikey / Bamboo / Lotus trên fcitx5.
3. Thêm app: pnpm, Postman, Waydroid (thay BlueStacks), BrowserStack Local.
4. Không chọn zsh → cấu hình shell ghi vào bash mặc định (`.bashrc`).
5. Bật hỗ trợ bộ gõ Wayland cho các app Chromium/Electron.

## Quyết định đã chốt

- Version guard: cảnh báo mềm rồi tiếp tục (không refuse) khi không phải Ubuntu 24.04.
- Branding: wordmark ASCII vẽ lại thành "SETUP", nhãn "ubuntu setup", giữ palette xanh.
- pnpm: cài qua corepack (fallback standalone khi thiếu Node).
- `test-docker.sh`: không khôi phục (đã xóa).
- Wayland IME flags: dùng `--ozone-platform-hint=auto` (an toàn cho cả X11) thay vì `--ozone-platform=wayland` forced; kèm `--enable-features=UseOzonePlatform --enable-wayland-ime --wayland-text-input-version=3`.

## 1. Ubuntu 24.04 only

- Header comment + `usage()`: mô tả Ubuntu 24.04.
- `get_ubuntu_version()`: chỉ dùng `lsb_release -rs` / os-release.
- `do_mirror()`: target `sources.list`, `ubuntu.sources`.
- `do_docker()`: luôn dùng `distro=ubuntu`.
- `main()`: đầu hàm, nếu `ID != ubuntu` hoặc `VERSION_ID != 24.04` in `warn` rồi tiếp tục.
- Banner: wordmark "SETUP" (ANSI-shadow, 6 dòng, gradient G1–G6), nhãn `ubuntu setup`.

## 2. Bộ gõ chọn engine

- `IME_ENGINE="unikey"`; `INPUT_ENGINES=("unikey|Unikey" "bamboo|Bamboo" "lotus|Lotus")`.
- Phím menu `g` → `configure_input_method()` (chọn 1–3), gán `IME_ENGINE`, bật `SELECTED[fcitx5]=1`.
- Chip trên dòng `fcitx5`: hiển thị `[<IME_ENGINE>]`.
- Footer hint hiển thị phím `g` (ASCII + Unicode).
- `do_fcitx5()` cài `fcitx5` + `fcitx5-config-qt` + frontend chung, rồi theo `IME_ENGINE`:
  - `unikey` → `fcitx5-unikey`, `DefaultIM=unikey`.
  - `bamboo` → `fcitx5-bamboo`, `DefaultIM=bamboo`.
  - `lotus` → thêm keyring `https://fcitx5-lotus.pages.dev/pubkey.gpg` vào `/etc/apt/keyrings/fcitx5-lotus.gpg`, source `deb [signed-by=...] https://fcitx5-lotus.pages.dev/apt/noble noble main` → `fcitx5-lotus`, `DefaultIM=lotus`.
- `undo_fcitx5()`: purge cả `fcitx5-unikey fcitx5-bamboo fcitx5-lotus`, gỡ keyring + source lotus.

## 3. App mới

Mỗi app: 1 dòng `APPS`, thêm vào group CSV, `do_`/`undo_`.

- `pnpm` (group dev, sau bun): có Node → `corepack enable && corepack prepare pnpm@latest --activate`; không có Node → standalone `https://get.pnpm.io/install.sh`. PATH `~/.local/share/pnpm` nằm trong block tool-integrations.
- `postman` (group desktop): tarball `https://dl.pstmn.io/download/latest/linux_64` → `/opt/Postman`, symlink `/usr/local/bin/postman`, tạo `/usr/share/applications/postman.desktop`.
- `waydroid` (group desktop): `https://repo.waydro.id` thêm repo → `apt install waydroid`; hướng dẫn user chạy `waydroid init` trong phiên Wayland.
- `browserstack` (group devops): unzip `https://local-downloads.browserstack.com/BrowserStackLocal-linux-x64.zip` → `/usr/local/bin/BrowserStackLocal`.

## 4. Không chọn zsh → default bash

- `resolve_shell_rc()`: trả `.zshrc` nếu `SELECTED[terminal]=1` hoặc shell mặc định đã là zsh; ngược lại `.bashrc`.
- `write_tool_integrations(rc)`: ghi block `# --- Tool integrations ---` (marker) idempotent — chứa PATH nvm/bun/dotnet/azure/claude/cargo/pnpm.
- `do_terminal()` lo oh-my-zsh + plugin cho `.zshrc`; gọi `write_tool_integrations` cho `.zshrc`.
- `main()`: sau khi resolve rc, nếu bất kỳ runtime nào được chọn thì gọi `write_tool_integrations "$(resolve_shell_rc)"` (đảm bảo bash cũng nhận PATH khi không cài zsh).
- `do_eza()`: ghi alias vào `resolve_shell_rc()`.
- `strip_zshrc_block` → `strip_rc_block <label> <rc>`; `undo_terminal`/`undo_eza` gỡ trên rc đúng.

## 5. Wayland IME cho Chromium/Electron

- `enable_wayland_ime(desktop_file)`: chèn (idempotent, guard theo marker/chuỗi) các flag vào mọi dòng `Exec=` của file `.desktop`:
  `--enable-features=UseOzonePlatform --ozone-platform-hint=auto --enable-wayland-ime --wayland-text-input-version=3`.
- Gọi cuối các installer: `do_chrome`, `do_edge`, `do_vscode`, `do_teams`, `do_trae`, `do_postman`.
- `main()`: set `ELECTRON_OZONE_PLATFORM_HINT=auto` trong `/etc/environment`.

## Kế hoạch triển khai (file-by-file)

`install-app.sh`:
- Header (9–13) + `usage()` (1636–1650): mô tả Ubuntu 24.04.
- `APPS` (84–129): sửa tagline fcitx5; thêm `pnpm`, `postman`, `waydroid`, `browserstack`.
- Sau dòng 132: thêm `IME_ENGINE` + `INPUT_ENGINES`.
- `APP_GROUPS` (147–153): thêm keys vào CSV group dev/devops/desktop.
- `print_banner` (322–347): wordmark SETUP + nhãn `ubuntu setup`.
- chip (413–415): thêm case `fcitx5`.
- footer (442–448): thêm phím `g`.
- `configure_input_method()`: thêm cạnh `configure_mirror`.
- `case "$key"` (528–563): thêm nhánh `g)`.
- `get_ubuntu_version` (602–610): rút gọn.
- helpers mới gần `strip_zshrc_block` (625–634): `strip_rc_block`, `resolve_shell_rc`, `write_tool_integrations`, `enable_wayland_ime`.
- `do_mirror` (642–646): bỏ target Mint.
- `do_terminal` (702–792): tách block integrations, gọi helper.
- `do_eza` (877–920): ghi rc resolved.
- `do_pnpm`/`undo_pnpm`: thêm sau `do_bun`.
- `do_chrome/edge/teams/vscode/trae` (1026–1110): gọi `enable_wayland_ime`.
- `do_docker` (1189–1191): bỏ remap Mint.
- `do_fcitx5` (1279–1346): rẽ nhánh engine.
- `do_postman`/`undo_postman`, `do_waydroid`/`undo_waydroid`, `do_browserstack`/`undo_browserstack`.
- `undo_fcitx5` (1595–1614): purge 3 engine + gỡ repo lotus.
- `undo_terminal` (1423) / `undo_eza` (1468): dùng `strip_rc_block`.
- `main()` (1653+): version guard, `write_tool_integrations`, `/etc/environment` ELECTRON hint.

`CLAUDE.md`, `README.md`: cập nhật số app, bỏ Mint, mô tả engine bộ gõ + `resolve_shell_rc`.

## Verification Criteria

- `bash -n install-app.sh` pass.
- `--all` install trong Ubuntu 24.04: profile fcitx5 có `DefaultIM` khớp engine; `pnpm -v`, `/opt/Postman`, `waydroid`, `/usr/local/bin/BrowserStackLocal` hiện diện; `.desktop` của app Chromium/Electron chứa `--enable-wayland-ime`.
- Không chọn `terminal`: `.bashrc` chứa block tool-integrations + eza alias; không tạo `.zshrc`.
- `--uninstall --all` rồi re-run install: idempotent, không lỗi.
- Chạy trên non-24.04: in cảnh báo rồi tiếp tục.

Edge case: tên addon IM Lotus xác nhận là `lotus` lúc cài; repo lotus là bên thứ ba (không phải distro-official).
