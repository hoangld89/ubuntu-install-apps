# 📢 Thông báo: Phần mềm tương thích khi chuyển từ Windows sang Ubuntu

Phần lớn phần mềm quen thuộc trên Windows **đã có sẵn phiên bản cho Ubuntu** Chrome, Edge, VS Code, VLC, Postman, DBeaver, AnyDesk, TeamViewer, OBS… đều dùng bình thường, giao diện gần như không đổi.

Các **công cụ lập trình dòng lệnh** cũng chạy y hệt trên Ubuntu, dùng đúng lệnh như trên Windows: Node.js, **Yarn**, pnpm, Bun, .NET SDK, **ABP CLI** (lệnh `abp`), Docker, Azure CLI, Terraform… Không cần đổi công cụ, chỉ cài qua script cài đặt là dùng được.

Tuy nhiên, có **4 nhóm phần mềm** sẽ không dùng đúng app cũ như trên Windows, mà chuyển sang **phần mềm tương đương** trên Ubuntu. Chức năng giống hệt, chỉ khác tên và đôi chút thao tác:

| Nhu cầu | Trên Windows | Trên Ubuntu (dùng thay thế) |
|---|---|---|
| ⌨️ **Gõ tiếng Việt** | Unikey | **Fcitx5** (bộ gõ Unikey / Bamboo / Lotus) |
| 📸 **Chụp ảnh màn hình** | Snipping Tool / Snip & Sketch | **Flameshot** (hoặc phím **Print Screen** có sẵn) |
| 📱 **Giả lập mobile (chạy app Android)** | BlueStacks / LDPlayer / NoxPlayer | **Waydroid** |
| 🎥 **Quay màn hình** | Bandicam / Camtasia | **OBS Studio** |

## Lưu ý nhanh cho từng phần mềm

- **Gõ tiếng Việt (Fcitx5):** Sau khi cài, chuyển đổi tiếng Việt ↔ tiếng Anh bằng phím tắt (thường là `Ctrl + Space`). Hỗ trợ cả kiểu gõ Telex và VNI như Unikey.
- **Chụp màn hình (Flameshot):** Nhấn phím `Print Screen` để mở Flameshot, chọn vùng chụp, có sẵn công cụ vẽ / mũi tên / làm mờ trước khi lưu hoặc copy. Ngoài ra vẫn dùng được công cụ chụp có sẵn của Ubuntu bằng phím `Print`. Xem cách gán / đổi phím chụp bên dưới nếu Flameshot chưa mở khi nhấn `Print`.
- **Waydroid:** Cho phép chạy ứng dụng Android ngay trong Ubuntu, thay cho các trình giả lập trên Windows.
- **OBS Studio:** Miễn phí, mạnh mẽ, quay màn hình và livestream chuyên nghiệp — cũng có sẵn bản Windows nên nếu quen rồi thì dùng luôn.

## Cách gán / đổi phím chụp cho Flameshot

Flameshot **không tự tạo phím tắt** khi cài — bạn phải gán tay. Lệnh mở chụp nhanh là `flameshot gui`.

**Các bước (trên GNOME / Ubuntu):**

1. Mở **Settings → Keyboard → Keyboard Shortcuts → View and Customize Shortcuts**.
2. Nếu muốn dùng phím `Print`: vào mục **Screenshots**, tắt / đổi shortcut mặc định đang chiếm phím `Print` (Ubuntu gán sẵn phím này cho công cụ chụp có sẵn).
3. Kéo xuống cuối, chọn **Custom Shortcuts → dấu `+`** và điền:
   - **Name:** `Flameshot`
   - **Command:** `flameshot gui`
   - **Shortcut:** nhấn phím bạn muốn (ví dụ `Print`, hoặc tổ hợp như `Ctrl + Alt + S`).
4. Lưu lại là dùng được ngay.

**Lưu ý khi cài bản snap (từ App Center):**
- Lần đầu nên chạy lệnh `flameshot` một lần trong Terminal để khởi động daemon, rồi mới gán phím tắt.
- Nếu đang chạy **Wayland** mà nhấn phím không chụp được (màn hình đen / không phản hồi): đăng nhập lại và chọn phiên **"Ubuntu on Xorg"** ở màn hình login, hoặc liên hệ IT để cài lại bản `.deb`/apt.

## Đổi mật khẩu đăng nhập sau khi cài

Máy được IT cài sẵn với **mật khẩu tạm**. Sau khi nhận máy, bạn **nên đổi mật khẩu ngay** để bảo mật.

**Cách 1 — qua giao diện (khuyến nghị):**

1. Mở **Settings → System → Users** (hoặc **Users & Groups**).
2. Chọn tài khoản của bạn → bấm vào mục **Password**.
3. Nhập **mật khẩu hiện tại** (mật khẩu tạm do IT cấp), rồi nhập **mật khẩu mới** 2 lần.
4. Bấm **Change** để lưu.

**Cách 2 — qua Terminal:**

```bash
passwd
```

Nhập lần lượt: mật khẩu hiện tại → mật khẩu mới → nhập lại mật khẩu mới. (Khi gõ mật khẩu, màn hình **không hiện ký tự** nào — đó là bình thường, cứ gõ rồi nhấn Enter.)

> **Lưu ý:** Mật khẩu này cũng là mật khẩu dùng khi chạy lệnh `sudo`. Sau khi đổi, hãy nhớ mật khẩu mới — nếu quên sẽ phải nhờ IT khôi phục.

Nếu cần hỗ trợ cài đặt hoặc làm quen với phần mềm mới, vui lòng liên hệ bộ phận IT.

Trân trọng.
