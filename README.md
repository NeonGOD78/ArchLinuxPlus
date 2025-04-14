ArchLinux Installer+ :zap:


A fully automated, powerful, and modern installer for Arch Linux — designed to create a secure, Btrfs-based system with encrypted root and home, Snapper snapshots, GRUB bootloader, Unified Kernel Image (UKI) support, and more.



:rocket: Features

Full disk encryption using LUKS2
Separate encrypted /home partition
Btrfs with subvolume layout
Snapper with grub-btrfs integration for boot-time rollback
Unified Kernel Image (UKI) generation via ukify
Automatic UKI rebuild on kernel upgrades (via pacman hook)
Microcode detection (Intel/AMD)
GRUB bootloader with UKI entry included
Optional user creation with zsh, oh-my-posh, and zinit
yay AUR helper preinstalled
Virtual machine guest additions included (KVM, VMware, VirtualBox, Hyper-V)
Networking utility selection (NetworkManager, IWD, etc.)
Auto timezone detection via ip-api.com
Default text editor selection
Optional Secure Boot readiness with sbctl

:hammer: Requirements
UEFI system
Internet connection
At least one empty disk

:package: How to use
Boot into the official Arch ISO and run:
bash <(curl -sL bit.lt/archlinuxplus)
Then follow the prompts to:
Select your disk
Set passwords
Choose kernel/network
Enter hostname/locale
Partition and install
The script will:

Set up encrypted partitions and Btrfs subvolumes

Install base system + tools
Generate UKI
Configure GRUB with luks + Btrfs
Enable all relevant services
At the end, your system is ready to boot — just reboot!

:lock: Encrypted Layout
/dev/mapper/cryptroot (Btrfs)
@ (root)
@snapshots (for Snapper)
@var_pkgs, @var_log, etc.
/dev/mapper/crypthome (Btrfs)
@home

All mounted with optimized Btrfs flags: ssd,noatime,compress-force=zstd:3,discard=async

:floppy_disk: EFI & UKI
The script mounts EFI to /efi and generates a UKI to:
/efi/EFI/Linux/arch.efi
Also adds a GRUB menu entry to boot via UKI.
On kernel upgrades, the UKI is automatically rebuilt via:
/etc/pacman.d/hooks/95-ukify.hook
/usr/local/bin/update-uki


:camera_flash: Snapper + grub-btrfs
Automatic snapshots + GRUB menu integration is enabled:
snapper-timeline.timer
snapper-cleanup.timer
grub-btrfsd.service
You can boot into a snapshot directly via GRUB.


:sparkles: Optional Tools Installed
btop, mc, git, fzf, zoxide, colordiff, curl, etc.
yay for AUR access
zsh with oh-my-posh theme & zinit
ZRAM configured (up to 8GiB, zstd compression)

:question: FAQ

Does it work with Secure Boot?  Yes — the system is sbctl-ready, but you'll need to enroll your own keys manually.
Does it support dual booting with Windows?  Yes, as long as you install Arch on a separate disk or separate EFI entry.
Can I use UKI with systemd-boot?  This script uses GRUB because of Snapper rollback support.
Is it safe for beginners?  Yes — the script guides you interactively. However, data will be erased, so use with caution.

:tada: Credits

Developed by @NeonGOD78 Inspired by years of manual installs and refined to be fast, modern and reliable.

Contributions welcome!

