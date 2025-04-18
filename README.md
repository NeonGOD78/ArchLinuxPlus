DO NOT USE YET !!  WORK IN PROGRESS !!

# ArchLinux+

**ArchLinux+** is a fully interactive and modular Arch Linux installation script, tailored for power users who want a modern, secure, and elegant system setup — quickly and with full control.

---

## 🚀 Features

- 🖥️ **Interactive CLI interface** with colorful, user-friendly prompts
- 🧩 **Modular architecture** for easier debugging and expansion
- 💾 **Visual disk selector** with partition layout and verification
- 🔐 **Full LUKS2 encryption** for root and separate `/home` partition
- 📦 **Btrfs subvolume layout**:
  - `@`, `@home`, `@snapshots`, `@var_log`, `@var_pkgs`, `@srv`, `@var_lib_*`
  - CoW disabled on relevant subvolumes for performance
- 📸 **Snapper + grub-btrfs integration** for GRUB boot menu rollback
- 🔧 **Kernel selection**: Stable, LTS, Hardened, Zen
- 🧠 **Microcode detection** (Intel/AMD)
- 🛜 **Network choices**: NetworkManager, iwd, wpa_supplicant, dhcpcd
- 🌍 **Regional defaults**:
  - Locale: `en_DK.UTF-8`
  - Hostname: `archlinux`
- ✨ **ZRAM**, Plymouth splash, GRUB themes (1080p and 2K)
- 🛡️ **Secure Boot support** with key generation, UKI build/sign automation
- 🧰 **AUR helper** yay installed and ready to use
- 💅 **Default shell set to ZSH**, with curated configs, aliases, and themes
- ⚙️ **Pacman tweaks**: Color, Candy, ParallelDownloads, Testing repos (search/update only)
- 🧬 **Dotfiles integration** with GitHub + stow support

---

## 🛠️ How to Use

1. Boot into the official Arch Linux ISO
2. Run this command:
```bash
bash <(curl -s https://raw.githubusercontent.com/NeonGOD78/ArchLinuxPlus/main/install.sh)
```

---

## 📝 Dotfiles Support

During the installation, you can optionally enter a GitHub URL for your dotfiles repo.  
The script will:
- Clone to `~/.dotfiles`
- Automatically apply folders using `stow`

---

## 📜 Secure Boot

If Secure Boot is enabled:
- Keys are generated
- UKI and GRUB are signed
- You can later use `update-uki` or `sign-grub` after kernel/boot updates

---

## 🧪 Future Plans

- Optional desktop environment selection: KDE, XFCE, Hyprland, Sway
- Remote LUKS unlock (Dropbear, SSH)
- System health features (smartd, btrfs stats)
- Server profiles (Docker, NAS, Hypervisor)

---

## ❤️ Credits

- The Arch Linux community
- Tools: `snapper`, `btrfs-progs`, `grub-btrfs`, `ukify`, `sbctl`
- [adi1090x](https://github.com/adi1090x) for Plymouth themes

---

## ⚠️ Disclaimer

This script wipes all data on the selected disk and performs a full system installation.  
**Use at your own risk**. You are responsible for your data.

---

## 🌐 GitHub Repository

**https://github.com/NeonGOD78/ArchLinuxPlus**