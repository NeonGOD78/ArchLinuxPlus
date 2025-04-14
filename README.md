📦 What is this?

ArchLinux Installer+ is a fully automated, interactive installation script for Arch Linux, optimized for:

    💾 Full-disk LUKS2 encryption (root + /home)

    🧠 Btrfs subvolumes with Snapper & grub-btrfs integration

    💥 Support for Unified Kernel Images (UKI)

    🧰 Extra features like ZRAM, yay, microcode detection, virtual guest additions, and more

🚀 Quick Install
bash <(curl -sL https://bit.ly/archlinuxplus)
🛠️ Features
Feature	Included
Full-disk LUKS2 encryption	✅
Separate encrypted /home	✅
Btrfs with subvolumes	✅
Snapper + grub-btrfs	✅
UKI support via ukify	✅
Auto EFI/UKI backup	✅
Auto grub-mkconfig & entries	✅
ZRAM via zram-generator	✅
yay (AUR helper) installation	✅
Network selector (NM, iwd, etc.)	✅
Auto microcode detection	✅
Virtualization guest tools	✅
Default zsh + custom dotfiles	✅
🧠 Subvolume layout
Subvolume	Mountpoint	Notes
@	/	Main root filesystem
@home	/home	On separate LUKS volume
@snapshots	/.snapshots	For Snapper
@var_pkgs	/var/cache/pacman/pkg	NOCOW
@var_log	/var/log	NOCOW
@var_lib_machines	/var/lib/machines	NOCOW
@var_lib_portables	/var/lib/portables	NOCOW
@srv	/srv	
@root	/root	750 permissions
🔐 Encryption layout

    / is on /dev/mapper/cryptroot (LUKS2)

    /home is on /dev/mapper/crypthome (LUKS2)

    /efi is separate FAT32 ESP

Uses rd.luks.name=UUID=cryptroot in GRUB and UKI.
🎯 Requirements

    UEFI system

    Stable internet connection

    GPT-partitioned disk

    At least 30 GB+ free space recommended

📸 Screenshots (optional)
💬 Credits

Script and structure by NeonGOD78

    Inspired by ArchWiki, archinstall, Snapper guides, and the community.

🧪 Warning

This script will erase your selected disk. Be sure to back up any important data. Use at your own risk.
📬 Feedback & Contributions

Pull requests, issues, and ideas are welcome on GitHub!

👉 View the repository


