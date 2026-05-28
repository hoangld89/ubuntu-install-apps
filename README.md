<p align="center">
  <img src="https://img.shields.io/badge/Ubuntu-22.04%20|%2024.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" />
  <img src="https://img.shields.io/badge/Linux%20Mint-21%20|%2022-87CF3E?style=for-the-badge&logo=linuxmint&logoColor=white" />
  <img src="https://img.shields.io/badge/Shell-Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white" />
</p>

# Ubuntu / Linux Mint &mdash; Post-install Setup Script

Script cai dat tu dong cac ung dung va cau hinh he thong sau khi cai moi Ubuntu hoac Linux Mint.
Co menu tuong tac de chon/bo tung thanh phan truoc khi cai.

---

## Khoi chay nhanh

```bash
# Clone repo
git clone <repo-url> && cd ubuntu-install-script

# Chay voi menu tuong tac
sudo bash install.sh

# Hoac cai tat ca khong hoi
sudo bash install.sh --all
```

---

## Menu tuong tac

Khi chay `sudo bash install.sh`, script se hien menu nhu sau:

```
╔══════════════════════════════════════════════════╗
║   Ubuntu / Linux Mint — App Installer            ║
╚══════════════════════════════════════════════════╝

       ── System ──
  [x]  1) System Update & Upgrade
  [x]  2) Swap 8GB + swappiness 10

       ── Browser & Communication ──
  [x]  3) Google Chrome
  [x]  4) Microsoft Teams

       ── IDE & Editor ──
  [x]  5) Visual Studio Code
  [x]  6) Trae IDE

       ── Languages & Runtime ──
  [x]  7) NVM + Node.js 24
  [x]  8) .NET SDK (chon version)            [versions: 10]

       ── Terminal Utilities ──
  [x]  9) Terminal tools (zsh, tmux, htop, jq, yq, rg, fzf, bat)

       ── DevOps & Infrastructure ──
  [x] 10) Terraform
  [x] 11) Azure CLI
  [x] 12) Docker + Docker Compose

       ── Database Tools ──
  [x] 13) DBeaver Community
  [x] 14) Navicat Premium Lite

       ── Productivity ──
  [x] 15) Fcitx5 (Vietnamese input)
  [x] 16) VLC Media Player
  [x] 17) Claude CLI

  a) Select all    n) Deselect all    d) .NET versions
  s) Start install  q) Quit
```

### Thao tac

| Phim | Tac dung |
|------|----------|
| `1` &ndash; `17` | Bat/tat tung thanh phan |
| `a` | Chon tat ca |
| `n` | Bo chon tat ca |
| `d` | Cau hinh .NET SDK versions (vd: nhap `8 9 10`) |
| `s` | Bat dau cai dat |
| `q` | Thoat |

---

## Chi tiet tung thanh phan

### System

| # | Thanh phan | Mo ta |
|---|------------|-------|
| 1 | **System Update** | `apt update && upgrade && autoremove` |
| 2 | **Swap 8GB** | Tao `/swapfile` 8GB, `swappiness=10`, persistent qua `/etc/fstab` va `/etc/sysctl.conf` |

### Browser & Communication

| # | Thanh phan | Nguon cai | Mo ta |
|---|------------|-----------|-------|
| 3 | **Google Chrome** | `.deb` truc tiep | Trinh duyet chinh |
| 4 | **Microsoft Teams** | Microsoft repo | Ung dung lam viec nhom |

### IDE & Editor

| # | Thanh phan | Nguon cai |
|---|------------|-----------|
| 5 | **VS Code** | Microsoft apt repo |
| 6 | **Trae IDE** | `.deb` tu CDN |

### Languages & Runtime

| # | Thanh phan | Mo ta |
|---|------------|-------|
| 7 | **NVM + Node.js 24** | Cai NVM v0.40.3 cho user hien tai, tu dong cai Node 24 va set default |
| 8 | **.NET SDK** | Mac dinh version 10. Nhan `d` trong menu de chon nhieu version (vd: `8 9 10`). Tu dong fallback sang install script neu version chua co trong apt |

### Terminal Utilities

| # | Thanh phan | Bao gom |
|---|------------|---------|
| 9 | **Terminal tools** | Xem chi tiet ben duoi |

<details>
<summary><b>Chi tiet cac tool trong Terminal tools</b></summary>

| Tool | Mo ta |
|------|-------|
| **zsh** | Shell mac dinh moi (thay the bash) |
| **Oh My Zsh** | Framework cau hinh zsh voi plugins |
| **zsh-autosuggestions** | Goi y lenh khi go |
| **zsh-syntax-highlighting** | To mau cau lenh |
| **tmux** | Terminal multiplexer, giu session khi SSH |
| **htop** | Monitor CPU/RAM truc quan |
| **jq** | Parse va xu ly JSON trong terminal |
| **yq** | Parse va xu ly YAML (tuong tu jq) |
| **ripgrep (`rg`)** | Tim kiem noi dung file cuc nhanh |
| **fzf** | Fuzzy finder cho file, history, pipe |
| **bat** | `cat` voi syntax highlighting va line numbers |

</details>

### DevOps & Infrastructure

| # | Thanh phan | Nguon cai | Mo ta |
|---|------------|-----------|-------|
| 10 | **Terraform** | HashiCorp apt repo | Infrastructure as Code |
| 11 | **Azure CLI** | Microsoft apt repo | Quan ly Azure resources |
| 12 | **Docker + Compose** | Docker apt repo | Docker CE + Compose plugin + buildx. Tu dong them user vao group `docker` |

### Database Tools

| # | Thanh phan | Nguon cai | Mo ta |
|---|------------|-----------|-------|
| 13 | **DBeaver Community** | `.deb` latest | GUI client ho tro nhieu loai DB |
| 14 | **Navicat Premium Lite** | AppImage | DB management, chay bang lenh `navicat` hoac tu app menu |

### Productivity

| # | Thanh phan | Nguon cai | Mo ta |
|---|------------|-----------|-------|
| 15 | **Fcitx5 + Unikey** | apt | Go tieng Viet. Tu dong cau hinh bien moi truong va autostart. Re-login de kich hoat |
| 16 | **VLC** | apt | Media player |
| 17 | **Claude CLI** | npm (global) | AI assistant trong terminal. Can NVM/Node (muc 7) cai truoc |

---

## Dependency

Script cai theo dung thu tu trong menu. Luu y:

```
NVM + Node.js (7)  ──>  Claude CLI (17)     Claude can npm tu NVM
```

> Neu chon Claude CLI ma khong chon NVM, script se canh bao va bo qua.

---

## Sau khi cai dat

Mot so thay doi can **re-login** hoac **reboot** de co hieu luc:

| Thanh phan | Can |
|------------|-----|
| Docker group | Re-login |
| Fcitx5 | Re-login |
| Zsh (default shell) | Re-login |
| Swap | Co hieu luc ngay |

```bash
# Kiem tra nhanh sau khi re-login
docker run hello-world          # Docker hoat dong?
node -v                         # Node version?
dotnet --list-sdks              # .NET SDK?
terraform -v                    # Terraform?
az version                      # Azure CLI?
echo $SHELL                     # Da chuyen sang zsh?
```

---

## Yeu cau he thong

- **OS**: Ubuntu 22.04+ hoac Linux Mint 21+
- **Arch**: amd64 (x86_64)
- **Quyen**: Root (chay bang `sudo`)
- **Mang**: Can ket noi internet de tai packages

---

## Tuy chinh

### Them app moi

1. Them entry vao mang `APPS` trong `install.sh`:
   ```bash
   APPS=(
       ...
       "myapp|My Application|1"    # 1 = mac dinh chon, 0 = mac dinh bo
   )
   ```

2. Them ham `do_myapp()`:
   ```bash
   do_myapp() {
       info "Installing My Application..."
       # cac lenh cai dat
       success "My Application installed"
   }
   ```

### Thay doi swap size

Sua dong `fallocate` trong ham `do_swap()`:
```bash
fallocate -l 16G /swapfile    # doi tu 8G sang 16G
```

---

## License

Internal use.
