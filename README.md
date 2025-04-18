> ⚠️ **DISCLAIMER**: This project is a **work in progress**.  
> **Do not use in production environments yet!**  
> Things may break, and features are being actively developed.

```
      _             _     _     _            __  __     
     / \   _ __ ___| |__ | |   (_)_ __  _   _\ \/ / _   
    / _ \ | '__/ __| '_ \| |   | | '_ \| | | |\  /_| |_ 
   / ___ \| | | (__| | | | |___| | | | | |_| |/  \_   _|
  /_/   \_\_|  \___|_| |_|_____|_|_| |_|\__,_/_/\_\|_|

                 ✦ ARCHLINUX+ INSTALLER ✦
```

## 🎯 Overview

**ArchLinux+** is a powerful, modular and modern Arch Linux installer built for users who want full control, fast deployment, and optional graphical environments.  
It offers full disk encryption, Secure Boot, Snapper + grub-btrfs integration, and plenty of QoL tweaks out of the box.

---

## 🚀 Quick Install

Run the following command from a live Arch ISO to launch the installer:

```bash
bash <(curl -sL bit.ly/archlinuxplus)
```

> ⚠️ Make sure you are running in a live ISO with network access.  
> The script will guide you through everything – from keyboard and disk selection to bootloader, shell, dotfiles and more.

---

## ✨ Features

- Full **LUKS2 disk encryption**
- **Separate /home** with its own LUKS volume
- **BTRFS** with multiple subvolumes
- **Snapper** + **grub-btrfs** for snapshot boot recovery
- **UKI** (Unified Kernel Images) and **Secure Boot** ready
- **ZRAM**, **Reflector**, **BTRFS scrubbing**, **systemd-oomd**
- Configurable **dotfiles** cloning with **stow**
- Optional **GRUB theme** + **Plymouth boot splash**
- Choose between kernels: stable, hardened, LTS, or zen
- Choose your editor and networking stack
- Install AUR helper `yay` automatically
- Clean and customizable: your choices, your Arch

---

## 🛠️ Requirements

- Arch Linux ISO (2023+ recommended)
- UEFI-based system
- Internet connection
- A clean drive (data will be wiped!)

---

## 📸 Screenshots

_Add your GRUB theme / plymouth / boot shots here later!_

---

## 🧠 License

MIT – Do whatever you want. Contributions welcome!

---

## 🙌 Credits

Thanks to the Arch community and all the open source authors that make this kind of scripting possible!
