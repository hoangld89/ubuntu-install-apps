# Design: Screenshot & Screen-Capture Tools

**Date**: 2026-07-07
**File touched**: `install-app.sh` (single file)

## Goal

Bổ sung các tool chụp/quay màn hình cho Ubuntu 24.04, thay thế cho bộ tool
Windows quen thuộc. Ánh xạ Windows → Linux:

| Tool Windows | Vai trò | Xử lý trên Linux |
|---|---|---|
| Lightshot | Chụp nhanh + annotate | **Flameshot** (mới thêm) |
| ShareX | Chụp + annotate + upload | **Flameshot** (trùng vai trò) |
| ScreenToGif | Quay màn hình → GIF/video | **OBS Studio** (mới thêm; xuất mp4/mkv/webm) |
| FastStoneCapture | Scrolling capture | Không thêm — không có tool desktop native tương đương |
| LDPlayer | Emulator test mobile | **Waydroid** (đã có sẵn trong script) |

Kết quả: thêm đúng **2 app mới** — `flameshot` và `obs`.

## Scope

- Thêm Flameshot và OBS Studio theo pattern registry + paired-function của script.
- Scrolling capture: không có tương đương; bỏ qua (nhu cầu web dùng extension trình duyệt).
- Mobile emulator: Waydroid đã phủ; giữ nguyên.

## Design

### Flameshot (thay Lightshot + ShareX)

- **Cài**: `apt install -y flameshot` — có sẵn trong Ubuntu 24.04 archive
  (candidate 12.1.0-2build2, hỗ trợ Wayland qua portal). Không cần thêm repo.
- **Idempotency**: install guard `command -v flameshot`; phần cấu hình chạy lại
  mỗi lần (đảm bảo cả máy đã cài sẵn Flameshot cũng được cấu hình đúng).
- **Wayland**: đảm bảo `xdg-desktop-portal-gnome` được cài (portal screenshot).
  Trên GNOME Wayland, portal chỉ cấp quyền chụp cho lệnh kích hoạt bằng phím —
  chạy `flameshot gui` từ terminal sẽ báo "unable to capture screen". Vì vậy
  `apply_flameshot_shortcut` gỡ `Print` khỏi screenshot mặc định
  (`org.gnome.shell.keybindings show-screenshot-ui = []`) rồi tạo custom
  keybinding GNOME gán `Print` → `flameshot gui`. Chạy dưới `REAL_USER` (cần
  dconf + DBus session bus của user), thao tác mảng `custom-keybindings`
  idempotent qua slot cố định `.../custom-keybindings/flameshot/`.
- Là Qt app → không cần `enable_wayland_ime` (chỉ dành cho Chromium/Electron).
- **undo**: `apt_purge flameshot`; `remove_flameshot_shortcut` khôi phục
  `Print` về screenshot GNOME (`gsettings reset show-screenshot-ui`) + gỡ slot
  khỏi list + `reset-recursively`; xóa `~/.config/flameshot` (dưới `REAL_USER`).

### OBS Studio (thay ScreenToGif — vai trò quay màn hình)

- **Cài**: PPA chính thức `ppa:obsproject/obs-studio` → `apt install -y obs-studio`.
  Cho bản mới nhất với PipeWire screen-capture cho Wayland (portal có sẵn trên
  GNOME 24.04). Binary là `obs`.
- Đảm bảo `add-apt-repository` tồn tại: cài `software-properties-common` nếu thiếu.
- `add-apt-repository -y` tự chạy `apt update`, nên không gọi `apt update` riêng.
- **Idempotency**: guard `command -v obs`; `add-apt-repository` không tạo dòng repo trùng.
- Xuất mp4/mkv/webm — không xuất GIF trực tiếp; cần GIF thì convert bằng `ffmpeg`.
- **undo**: `apt_purge obs-studio`; gỡ PPA bằng `add-apt-repository -y --remove`
  (xử lý đúng cả format deb822 `.sources` của Ubuntu 24.04) + rm glob cả
  `*.list` lẫn `*.sources`; xóa `~/.config/obs-studio` (dưới `REAL_USER`).

### Vị trí trong registry & group

- Thêm khối `# ── Media & Capture ──` trong `APPS`, ngay sau dòng `vlc`,
  trước `# ── AI Tools ──`:
  - `"flameshot|Flameshot::screenshot, annotate & share in a snap|1"`
  - `"obs|OBS Studio::record & stream your screen, pro-grade|1"`
- Nối `,flameshot,obs` vào cuối CSV của group `desktop` trong `APP_GROUPS`.
- Cả hai `default_on = 1`, đồng nhất với toàn bộ registry hiện tại.

## Implementation Plan

File duy nhất bị đụng: **`install-app.sh`**

1. **`APPS` array** (sau dòng `vlc`, ~line 129): thêm comment `# ── Media & Capture ──`
   + 2 dòng đăng ký `flameshot` và `obs`.
2. **`APP_GROUPS`** (line 166): nối `,flameshot,obs` vào CSV group `desktop`.
3. **Sau `do_vlc`** (~line 1580): thêm `do_flameshot()` và `do_obs()`.
4. **Sau `undo_vlc`** (~line 1888): thêm `undo_flameshot()` và `undo_obs()`.

## Verification Criteria

- `bash -n install-app.sh` — không lỗi cú pháp.
- Mỗi key `flameshot`/`obs` xuất hiện đúng 1 lần trong 1 group CSV.
- Chạy menu (dry): 2 app mới hiện trong group "Apps & Desktop", chọn/bỏ chọn được.
- Cài thật trên Ubuntu 24.04:
  - `command -v flameshot` và `command -v obs` trả về đường dẫn.
  - Chạy lại script → cả hai báo "already installed, skipping" (idempotent).
- Uninstall (`--uninstall`): package bị purge; PPA OBS bị gỡ (không còn file
  `.list`/`.sources`); `~/.config/{flameshot,obs-studio}` bị xóa.

### Known edge cases

- Flameshot trên GNOME Wayland chỉ chụp được khi khởi động bằng phím → script
  tự gán `Print`; user có thể cần log out/in để shortcut mới có hiệu lực.
- PPA OBS trên 24.04 ghi file deb822 `.sources` — undo phải glob cả 2 đuôi.
- OBS không xuất GIF; đây là giới hạn đã biết khi bỏ Kooha.
