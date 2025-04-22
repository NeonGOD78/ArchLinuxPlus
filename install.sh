#!/usr/bin/env -S bash -e
set -o pipefail
set -u
IFS=$'\n\t'

# Color definitions for styling
BOLD='\e[1m'
RESET='\e[0m'
BRED='\e[91m'
BBLUE='\e[34m'
BGREEN='\e[92m'
BYELLOW='\e[93m'

# Ensure we're running in Bash
[ -z "${BASH_VERSION:-}" ] && echo "This script must be run with bash." && exit 1

# ======================= Print Functions =======================

info_print() {
  printf "${BGREEN}[✔] %s${RESET}\n" "$1"
}

warning_print() {
  printf "${BYELLOW}[!] %s${RESET}\n" "$1"
}

error_print() {
  printf "${BRED}[✖] %s${RESET}\n" "$1"
}

success_print() {
  printf "${BGREEN}[✓] %s${RESET}\n" "$1"
}

input_print() {
  printf "${BYELLOW}[?] %s${RESET} " "$1"
}

print_separator() {
  printf "${BBLUE}------------------------------------------------------------${RESET}\n"
}

section_print() {
  printf "${BBLUE}==> %s${RESET}\n" "$1"
}

# ======================= Define Log File =======================
LOGFILE="/tmp/archinstall.log"
touch "$LOGFILE"
chmod 600 "$LOGFILE"
info_print "Log file created at $LOGFILE"

# ======================= Move Log File =======================
move_log_file() {
  if [[ -d "/mnt" ]]; then
    mkdir -p /mnt/var/log
    cp "$LOGFILE" /mnt/var/log/archinstall.log
    LOGFILE="/mnt/var/log/archinstall.log"
    info_print "Log file moved to $LOGFILE"
  else
    error_print "Error: /mnt directory is not mounted. Log file not moved."
  fi
}

# ======================= Password Prompt Helper ======================
get_valid_password() {
  local prompt="$1"
  local pass1 pass2

  while true; do
    input_print "$prompt: "
    stty -echo
    read -r pass1
    stty echo
    echo

    if [[ -z "$pass1" ]]; then
      warning_print "Password cannot be empty."
      continue
    fi

    input_print "Confirm $prompt: "
    stty -echo
    read -r pass2
    stty echo
    echo

    if [[ "$pass1" != "$pass2" ]]; then
      warning_print "Passwords do not match. Please try again."
    else
      break
    fi
  done

  echo "$pass1"
}

# ======================= Welcome Banner ======================
welcome_banner() {
  clear
  echo -ne "${BOLD}${BYELLOW}
===========================================================
    _             _     _     _            __  __
   / \   _ __ ___| |__ | |   (_)_ __  _   _\ \/ / _
  / _ \ | '__/ __| '_ \| |   | | '_ \| | | |\  /_| |_
 / ___ \| | | (__| | | | |___| | | | | |_| |/  \_   _|
/_/   \_\_|  \___|_| |_|_____|_|_| |_|\__,_/_/\_\|_|

===========================================================
${RESET}"
  info_print "Welcome to ArchLinux+, a script made to simplify the Arch Linux installation process."
  print_separator
}

# ======================= Keyboard Selection ======================
keyboard_selector () {
    input_print "Please insert the keyboard layout to use in console (enter empty to use DK, or \"/\" to look up for keyboard layouts): "
    read -r kblayout
    case "$kblayout" in
        '')
            kblayout="dk"
            info_print "The Danish keyboard layout will be used."
            loadkeys "$kblayout"
            return 0
            ;;
        '/')
            localectl list-keymaps
            clear
            return 1
            ;;
        *)
            if ! localectl list-keymaps | grep -Fxq "$kblayout"; then
                error_print "The specified keymap doesn't exist."
                return 1
            fi
            info_print "Changing console layout to $kblayout."
            loadkeys "$kblayout"
            return 0
            ;;
    esac
}

# ======================= Locale Selection ======================
locale_selector () {
    input_print "Please insert the locale you use (format: xx_XX. Enter empty to use en_DK.UTF-8, or \"/\" to search locales): "
    read -r locale
    case "$locale" in
        '') 
            locale="en_DK.UTF-8"
            info_print "$locale will be the default locale."
            echo "$locale UTF-8" >> /etc/locale.gen
            locale-gen
            echo "LANG=$locale" > /etc/locale.conf
            return 0
            ;;
        '/')
            sed -E '/^# +|^#$/d;s/^#| *$//g;s/ .*/ (Charset:&)/' /etc/locale.gen | less -M
            clear
            return 1
            ;;
        *)
            if ! grep -q "^#\?$(sed 's/[]\\.*[]/\\&/g' <<< "$locale") " /etc/locale.gen; then
                error_print "The specified locale doesn’t exist or isn’t supported."
                return 1
            fi
            echo "$locale UTF-8" >> /etc/locale.gen
            locale-gen
            echo "LANG=$locale" > /etc/locale.conf
            return 0
            ;;
    esac
}

# ======================= Hostname Setup ======================
hostname_selector () {
    input_print "Please enter the hostname: "
    read -r hostname
    if [[ -z "$hostname" ]]; then
        error_print "You need to enter a hostname in order to continue."
        return 1
    fi
    return 0
}

# ======================= Kernel Selection ======================
kernel_selector () {
    info_print "List of kernels:"
    info_print "1) Stable: Vanilla Linux kernel with a few specific Arch Linux patches applied"
    info_print "2) Hardened: A security-focused Linux kernel"
    info_print "3) Longterm: Long-term support (LTS) Linux kernel"
    info_print "4) Zen Kernel: A Linux kernel optimized for desktop usage"
    input_print "Please select the number of the corresponding kernel (e.g. 1): "
    read -r kernel_choice
    case $kernel_choice in
        1 ) kernel="linux"; return 0;;
        2 ) kernel="linux-hardened"; return 0;;
        3 ) kernel="linux-lts"; return 0;;
        4 ) kernel="linux-zen"; return 0;;
        * ) error_print "Invalid selection, please try again."; return 1;;
    esac
}

# ======================= Microcode Detection ======================
microcode_detector () {
    CPU=$(grep vendor_id /proc/cpuinfo)
    if [[ "$CPU" == *"AuthenticAMD"* ]]; then
        info_print "An AMD CPU has been detected, the AMD microcode will be installed."
        microcode="amd-ucode"
    else
        info_print "An Intel CPU has been detected, the Intel microcode will be installed."
        microcode="intel-ucode"
    fi
}

# ======================= Partition Disk ===================
partition_disk() {
  # Calculate default root partition size (50% of total disk size in GB)
  DISK_SIZE_GB=$(lsblk -bno SIZE "$DISK" | awk '{printf "%.0f", $1 / (1024*1024*1024)}')
  DEFAULT_ROOT_SIZE=$((DISK_SIZE_GB / 2))

  input_print "Enter root partition size (e.g. ${DEFAULT_ROOT_SIZE}G). Default is ${DEFAULT_ROOT_SIZE}G: "
  read -r root_size
  root_size=${root_size:-${DEFAULT_ROOT_SIZE}G}

  info_print "Creating partitions on $DISK..."
  parted -s "$DISK" \
    mklabel gpt \
    mkpart ESP fat32 1MiB 1025MiB \
    set 1 esp on \
    mkpart CRYPTROOT 1025MiB "$root_size" \
    mkpart CRYPTHOME "$root_size" 100% &>/dev/null

  partprobe "$DISK"

  if [[ "$DISK" =~ nvme ]]; then
    PART1="${DISK}p1"
    PART2="${DISK}p2"
    PART3="${DISK}p3"
  else
    PART1="${DISK}1"
    PART2="${DISK}2"
    PART3="${DISK}3"
  fi

  ESP="$PART1"
  CRYPTROOT="$PART2"
  CRYPTHOME="$PART3"
}

# ======================= Encrypt Partitions ===============
encrypt_partitions() {
  info_print "Creating LUKS encryption on root partition..."
  if ! echo -n "$password" | cryptsetup luksFormat "$CRYPTROOT" --type luks2 --batch-mode --label=CRYPTROOT -; then
    error_print "Failed to create LUKS encryption on root partition"
    return 1
  fi

  info_print "Creating LUKS encryption on home partition..."
  if ! echo -n "$password" | cryptsetup luksFormat "$CRYPTHOME" --type luks2 --batch-mode --label=CRYPTHOME -; then
    error_print "Failed to create LUKS encryption on home partition"
    return 1
  fi

  info_print "Opening encrypted root partition..."
  if ! echo -n "$password" | cryptsetup open "$CRYPTROOT" cryptroot --key-file=-; then
    error_print "Failed to open root partition"
    return 1
  fi

  info_print "Opening encrypted home partition..."
  if ! echo -n "$password" | cryptsetup open "$CRYPTHOME" crypthome --key-file=-; then
    error_print "Failed to open home partition"
    return 1
  fi
}

# ======================= Format Partitions ================
format_partitions() {
  info_print "Formatting EFI partition as FAT32..."
  mkfs.fat -F32 "$ESP" &>> "$LOGFILE"

  info_print "Formatting root (cryptroot) as BTRFS..."
  # Format the root partition as BTRFS
  mkfs.btrfs /dev/mapper/cryptroot &>> "$LOGFILE" || {
    error_print "Failed to format root partition as BTRFS"
    return 1
  }

  info_print "Formatting home (crypthome) as BTRFS..."
  # Format the home partition as BTRFS
  mkfs.btrfs /dev/mapper/crypthome &>> "$LOGFILE" || {
    error_print "Failed to format home partition as BTRFS"
    return 1
  }
}


# ======================= Install Base System ======================
install_base_system() {
  info_print "Installing the base system (this may take a while)..."

  if pacstrap -K /mnt base "$kernel" "$microcode" linux-firmware "$kernel"-headers \
      btrfs-progs grub grub-btrfs rsync efibootmgr snapper reflector snap-pac \
      zram-generator sudo inotify-tools zsh unzip fzf zoxide colordiff curl \
      btop mc git systemd ukify openssl sbsigntools sbctl &>> "$LOGFILE"; then

    success_print "Base system installed successfully."
    return 0
  else
    warning_print "Base system installation failed. Retrying in 5 seconds..."
    sleep 5
    return 1
  fi
}

# ======================= Setup Secure Boot Files ======================
setup_secureboot_structure() {
  info_print "Setting up Secure Boot file structure and tools..."

  mkdir -p /mnt/etc/secureboot
  if [[ ! -f /mnt/etc/secureboot/db.key || ! -f /mnt/etc/secureboot/db.crt ]]; then
    info_print "Generating Secure Boot keys..."
    openssl req -new -x509 -newkey rsa:2048 -sha256 -days 3650 \
      -nodes -subj "/CN=Secure Boot Signing" \
      -keyout /mnt/etc/secureboot/db.key \
      -out /mnt/etc/secureboot/db.crt &>/dev/null
    chmod 600 /mnt/etc/secureboot/db.key
  else
    info_print "Secure Boot keys already exist."
  fi

  info_print "Creating helper script: /usr/local/bin/update-uki"
  mkdir -p /mnt/usr/local/bin
  cat > /mnt/usr/local/bin/update-uki <<'EOF'
#!/bin/bash
set -e
UKI_OUTPUT="/efi/EFI/Linux/arch.efi"
UKI_OUTPUT_FB="/efi/EFI/Linux/arch-fallback.efi"
KERNEL="/boot/vmlinuz-linux"
INITRD="/boot/initramfs-linux.img"
INITRD_FB="/boot/initramfs-linux-fallback.img"
BACKUP_DIR="/.efibackup"
CMDLINE="rd.luks.name=/dev/mapper/cryptroot=cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ quiet loglevel=3"
ukify build --linux "$KERNEL" --initrd "$INITRD" --cmdline "$CMDLINE" --output "$UKI_OUTPUT"
[[ -f /etc/secureboot/db.key ]] && sbsign --key /etc/secureboot/db.key --cert /etc/secureboot/db.crt --output "$UKI_OUTPUT" "$UKI_OUTPUT"
cp "$UKI_OUTPUT" "$BACKUP_DIR/arch.efi.bak" || echo "Backup failed"
ukify build --linux "$KERNEL" --initrd "$INITRD_FB" --cmdline "$CMDLINE" --output "$UKI_OUTPUT_FB"
[[ -f /etc/secureboot/db.key ]] && sbsign --key /etc/secureboot/db.key --cert /etc/secureboot/db.crt --output "$UKI_OUTPUT_FB" "$UKI_OUTPUT_FB"
cp "$UKI_OUTPUT_FB" "$BACKUP_DIR/arch-fallback.efi.bak" || echo "Backup failed"
EOF
  chmod +x /mnt/usr/local/bin/update-uki

  info_print "Creating helper script: /usr/local/bin/sign-grub"
  cat > /mnt/usr/local/bin/sign-grub <<'EOF'
#!/bin/bash
set -e
GRUB_EFI="/boot/EFI/GRUB/grubx64.efi"
KEY="/etc/secureboot/db.key"
CERT="/etc/secureboot/db.crt"
[[ -f $GRUB_EFI && -f $KEY && -f $CERT ]] || { echo "Missing files."; exit 1; }
sbsign --key "$KEY" --cert "$CERT" --output "$GRUB_EFI" "$GRUB_EFI"
echo "[✓] GRUB successfully signed."
EOF
  chmod +x /mnt/usr/local/bin/sign-grub

  info_print "Creating /etc/motd message"
  cat > /mnt/etc/motd <<'EOF'
Welcome to your freshly installed Arch system 🎉
Useful commands:
  update-uki     → Rebuild + sign your Unified Kernel Images
  sign-grub      → Re-sign GRUB after reinstall/update
EOF

  info_print "Creating /.efibackup directory"
  mkdir -p /mnt/.efibackup

  info_print "Creating UKI systemd timer"
  mkdir -p /mnt/etc/systemd/system
  cat > /mnt/etc/systemd/system/update-uki.timer <<'EOF'
[Unit]
Description=Run update-uki daily

[Timer]
OnBootSec=5min
OnUnitActiveSec=1d

[Install]
WantedBy=timers.target
EOF

  info_print "Creating pacman hooks for UKI"
  mkdir -p /mnt/etc/pacman.d/hooks
  cat > /mnt/etc/pacman.d/hooks/95-ukify.hook <<'EOF'
[Trigger]
Type = Path
Operation = Install
Operation = Upgrade
Operation = Remove
Target = boot/vmlinuz-linux
Target = boot/initramfs-linux.img

[Action]
Description = Regenerating Unified Kernel Image (UKI)...
When = PostTransaction
Exec = /usr/local/bin/update-uki
EOF

  cat > /mnt/etc/pacman.d/hooks/96-ukify-fallback.hook <<'EOF'
[Trigger]
Type = Path
Operation = Install
Operation = Upgrade
Target = boot/initramfs-linux-fallback.img

[Action]
Description = Regenerating fallback Unified Kernel Image (UKI)...
When = PostTransaction
Exec = /usr/local/bin/update-uki-fallback.sh \
  --linux /boot/vmlinuz-linux \
  --initrd /boot/initramfs-linux-fallback.img \
  --cmdline "rd.luks.name=/dev/mapper/cryptroot=cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw quiet loglevel=3" \
  --output /efi/EFI/Linux/arch-fallback.efi && \
  sbsign --key /etc/secureboot/db.key \
         --cert /etc/secureboot/db.crt \
         --output /efi/EFI/Linux/arch-fallback.efi \
         /efi/EFI/Linux/arch-fallback.efi'
EOF

  info_print "Enabling UKI update timer..."
  arch-chroot /mnt systemctl enable update-uki.timer &>/dev/null || warning_print "Failed to enable update-uki.timer"

cat > /mnt/usr/local/bin/update-uki-fallback.sh <<'EOF'
#!/bin/bash
set -e

CMDLINE="rd.luks.name=/dev/mapper/cryptroot=cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw quiet loglevel=3"

ukify build \
  --linux /boot/vmlinuz-linux \
  --initrd /boot/initramfs-linux-fallback.img \
  --cmdline "$CMDLINE" \
  --output /efi/EFI/Linux/arch-fallback.efi

sbsign --key /etc/secureboot/db.key \
       --cert /etc/secureboot/db.crt \
       --output /efi/EFI/Linux/arch-fallback.efi \
       /efi/EFI/Linux/arch-fallback.efi
EOF

chmod +x /mnt/usr/local/bin/update-uki-fallback.sh
}

# ======================= Mount BTRFS Subvolumes ================
mount_btrfs_subvolumes() {
  info_print "Creating BTRFS subvolumes on root partition..."
  mount /dev/mapper/cryptroot /mnt
  for subvol in @ @snapshots @var_pkgs @var_log @srv @var_lib_portables @var_lib_machines @var_lib_libvirt; do
    btrfs subvolume create /mnt/$subvol &>> "$LOGFILE" || {
      error_print "Failed to create BTRFS subvolume $subvol"
      return 1
    }
  done
  umount /mnt

  info_print "Creating BTRFS subvolume on home partition..."
  mount /dev/mapper/crypthome /mnt
  btrfs subvolume create /mnt/@home &>> "$LOGFILE" || {
    error_print "Failed to create BTRFS subvolume @home"
    return 1
  }
  umount /mnt

  mountopts="ssd,noatime,compress-force=zstd:3,discard=async"

  info_print "Mounting root subvolume (@) to /mnt..."
  mount -o "$mountopts",subvol=@ /dev/mapper/cryptroot /mnt

  info_print "Creating mount directories..."
  mkdir -p /mnt/{.snapshots,var/log,var/cache/pacman/pkg,var/lib/libvirt,var/lib/machines,var/lib/portables,srv,efi,boot,home,root}
  chmod 750 /mnt/root

  # Mount remaining subvolumes with CoW disabled where needed
  declare -A mounts=(
    [@snapshots]=.snapshots
    [@var_log]=var/log
    [@var_pkgs]=var/cache/pacman/pkg
    [@var_lib_libvirt]=var/lib/libvirt
    [@var_lib_machines]=var/lib/machines
    [@var_lib_portables]=var/lib/portables
    [@srv]=srv
  )

  for subvol in "${!mounts[@]}"; do
    target="${mounts[$subvol]}"
    info_print "Mounting $subvol on /mnt/$target"
    mount -o "$mountopts",subvol="$subvol" /dev/mapper/cryptroot "/mnt/$target"
    chattr +C "/mnt/$target" 2>/dev/null || info_print "Could not disable CoW on /mnt/$target"
  done

  info_print "Mounting home subvolume on /mnt/home..."
  mount -o "$mountopts",subvol=@home /dev/mapper/crypthome /mnt/home

  info_print "Mounting EFI partition on /mnt/efi..."
  mount "$ESP" /mnt/efi
}

# ======================= Setup timezone & Clock ======================
setup_timezone_and_clock_chroot() {
  info_print "Setting timezone and synchronizing hardware clock (in chroot)..."
  arch-chroot /mnt /bin/bash -e <<'EOF'
set -euo pipefail
ZONE=$(curl -s http://ip-api.com/line?fields=timezone)
ln -sf "/usr/share/zoneinfo/$ZONE" /etc/localtime || echo "[!] Failed to set timezone"
hwclock --systohc || echo "[!] Failed to sync hardware clock"
EOF
}

# ======================= Setup Locale ======================
setup_locale_and_initramfs_chroot() {
  info_print "Generating locale and initramfs (in chroot)..."
  arch-chroot /mnt /bin/bash -e <<'EOF'
set -euo pipefail
echo "LANG=en_DK.UTF-8" > /etc/locale.conf
echo "LC_TIME=da_DK.UTF-8" >> /etc/locale.conf
echo "KEYMAP=dk" > /etc/vconsole.conf
locale-gen || echo "[!] Failed to generate locale"
mkinitcpio -P || echo "[!] mkinitcpio failed"
EOF
}

# ======================= setup Snapper ======================
setup_snapper_chroot() {
  info_print "Setting up Snapper configuration (in chroot)..."
  arch-chroot /mnt /bin/bash -e <<'EOF'
set -euo pipefail

# Unmount and remove old .snapshots if needed
umount /.snapshots &>/dev/null || true
rm -rf /.snapshots

# Create Snapper config and replace subvolume
snapper --no-dbus -c root create-config /
btrfs subvolume delete /.snapshots &>> \"$LOGFILE\" || true
mkdir /.snapshots
mount -a
chmod 750 /.snapshots
EOF
}

# ======================= Install GRUB ======================
install_grub_chroot() {
  info_print "Installing GRUB bootloader (in chroot)..."
  arch-chroot /mnt /bin/bash -e <<'EOF'
set -euo pipefail

grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
EOF
}

sign_grub_chroot() {
  info_print "Signing GRUB bootloader (in chroot)..."
  arch-chroot /mnt /bin/bash -e <<'EOF'
set -euo pipefail

if [[ -f /boot/EFI/GRUB/grubx64.efi && -f /etc/secureboot/db.key && -f /etc/secureboot/db.crt ]]; then
  sbsign --key /etc/secureboot/db.key \
         --cert /etc/secureboot/db.crt \
         --output /boot/EFI/GRUB/grubx64.efi \
         /boot/EFI/GRUB/grubx64.efi
else
  echo "[!] GRUB or Secure Boot keys not found, skipping signing."
fi
EOF
}

# ======================= Setup GRUB-BTRFS ======================
setup_grub_btrfs_chroot() {
  info_print "Configuring grub-btrfs in chroot..."

  arch-chroot /mnt /bin/bash -e <<'EOF'
set -euo pipefail

# Aktivér custom grub-btrfs menu entries
sed -i '/#GRUB_BTRFS_GRUB_DIRNAME=/s|#.*|GRUB_BTRFS_GRUB_DIRNAME="/boot/grub"|' /etc/default/grub-btrfs/config
sed -i 's|^#USE_CUSTOM_CONFIG=.*|USE_CUSTOM_CONFIG="true"|' /etc/default/grub-btrfs/config

# Custom UKI snapshot menu
cat > /etc/grub.d/42_grub-btrfs-custom <<'GRUBCUSTOM'
#!/bin/bash
. /usr/share/grub/grub-mkconfig_lib

snapshot="$1"
title="Arch Linux (UKI) Snapshot: ${snapshot##*/}"

cat <<GRUB_ENTRY
menuentry '$title' {
    search --no-floppy --file --set=root /EFI/Linux/arch.efi
    linuxefi /EFI/Linux/arch.efi
    options rootflags=subvol=${snapshot#/mnt} rd.luks.name=/dev/mapper/cryptroot=cryptroot root=/dev/mapper/cryptroot quiet loglevel=3
}
menuentry 'Arch Linux (UKI Fallback)' {
    search --no-floppy --file --set=root /EFI/Linux/arch-fallback.efi
    linuxefi /EFI/Linux/arch-fallback.efi
}
GRUB_ENTRY
GRUBCUSTOM
chmod +x /etc/grub.d/42_grub-btrfs-custom

# Klassisk fallback
cat > /etc/grub.d/41_fallback <<'GRUBFALLBACK'
#!/bin/bash
cat <<GRUBENTRY
menuentry "Arch Linux (Fallback Kernel)" {
    search --no-floppy --file --set=root /boot/vmlinuz-linux
    linux /boot/vmlinuz-linux root=/dev/mapper/cryptroot rd.luks.name=/dev/mapper/cryptroot=cryptroot rootflags=subvol=@ quiet loglevel=3
    initrd /boot/initramfs-linux.img
}
GRUBENTRY
GRUBFALLBACK
chmod +x /etc/grub.d/41_fallback
EOF
}

# ======================= Build UKI  ======================
build_uki_chroot() {
  info_print "Building and signing Unified Kernel Images (UKIs)..."

  arch-chroot /mnt /bin/bash -e <<'EOF'
set -euo pipefail

log="/var/log/ukify.log"
mkdir -p "$(dirname "$log")"

CMDLINE="rd.luks.name=/dev/mapper/cryptroot=cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw quiet loglevel=3"

# Main UKI
ukify build \
  --linux /boot/vmlinuz-linux \
  --initrd /boot/initramfs-linux.img \
  --cmdline "$CMDLINE" \
  --output /efi/EFI/Linux/arch.efi >> "$log" 2>&1 || echo "UKI build failed" >> "$log"

# Fallback UKI
ukify build \
  --linux /boot/vmlinuz-linux \
  --initrd /boot/initramfs-linux-fallback.img \
  --cmdline "$CMDLINE" \
  --output /efi/EFI/Linux/arch-fallback.efi >> "$log" 2>&1 || echo "Fallback UKI build failed" >> "$log"

# Sign both if keys exist
if [[ -f /etc/secureboot/db.key && -f /etc/secureboot/db.crt ]]; then
  sbsign --key /etc/secureboot/db.key --cert /etc/secureboot/db.crt \
         --output /efi/EFI/Linux/arch.efi /efi/EFI/Linux/arch.efi >> "$log" 2>&1 || echo "Sign arch.efi failed" >> "$log"

  sbsign --key /etc/secureboot/db.key --cert /etc/secureboot/db.crt \
         --output /efi/EFI/Linux/arch-fallback.efi /efi/EFI/Linux/arch-fallback.efi >> "$log" 2>&1 || echo "Sign fallback failed" >> "$log"
fi
EOF
}

generate_grub_cfg() {
  info_print "Generating GRUB configuration file..."

  arch-chroot /mnt /bin/bash -e <<'EOF'
set -euo pipefail

if grub-mkconfig -o /boot/grub/grub.cfg &>> \"$LOGFILE\"; then
  echo "[✓] GRUB config generated successfully."
else
  echo "[!] Failed to generate GRUB config."
fi
EOF
}

# ======================= Disk Selection ======================
select_disk() {
  section_print "Disk Selection"

  while true; do
    # Get list of physical disks (no loop, rom, or boot mounts)
    mapfile -t disks < <(lsblk -dpno NAME,SIZE,MODEL | grep -Ev "boot|rpmb|loop")

    if [[ "${#disks[@]}" -eq 0 ]]; then
      error_print "No suitable block devices found."
      exit 1
    fi

    echo
    info_print "Detected disks:"
    for i in "${!disks[@]}"; do
      printf "  %d) %s\n" "$((i+1))" "${disks[$i]}"
    done
    echo

    input_print "Select the number of the disk to install Arch on (or press Enter to cancel): "
    read -r disk_index

    if [[ -z "$disk_index" ]]; then
      error_print "Disk selection cancelled by user."
      exit 1
    fi

    if ! [[ "$disk_index" =~ ^[0-9]+$ ]] || (( disk_index < 1 || disk_index > ${#disks[@]} )); then
      warning_print "Invalid selection. Please try again."
      continue
    fi

    DISK=$(awk '{print $1}' <<< "${disks[$((disk_index-1))]}")

    echo
    success_print "You selected: $DISK"
    echo

    info_print "Partition layout:"
    lsblk -p -e7 -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINT,LABEL,UUID "$DISK"
    echo

    warning_print "!! ALL DATA ON $DISK WILL BE IRREVERSIBLY LOST !!"
	echo
    input_print "Do you want to proceed with this disk? [y/N]: "
    read -r confirm

    if [[ "${confirm,,}" == "y" ]]; then
      success_print "Disk $DISK confirmed and ready for partitioning."
      break
    else
      warning_print "Disk not confirmed. You can select another disk."
      echo
    fi
  done
}

# ======================= LUKS Password Input =====================
lukspass_selector() {
  local pass1 pass2

  while true; do
    input_print "Enter password to use for disk encryption (LUKS): "
    stty -echo
    read -r pass1
    stty echo
    echo

    if [[ -z "$pass1" ]]; then
      warning_print "Password cannot be empty."
      continue
    fi

    input_print "Confirm password: "
    stty -echo
    read -r pass2
    stty echo
    echo

    if [[ "$pass1" != "$pass2" ]]; then
      warning_print "Passwords do not match. Please try again."
    else
      password="$pass1"
      break
    fi
  done

  info_print "Disk encryption password has been set."
}

# ======================= Network Selector ======================
network_selector () {
    info_print "Network utilities:"
    info_print "1) NetworkManager: Universal network utility (both WiFi and Ethernet, highly recommended)"
    info_print "2) IWD: Utility to connect to networks written by Intel (WiFi-only, built-in DHCP client)"
    info_print "3) wpa_supplicant: Utility with support for WEP and WPA/WPA2 (WiFi-only, DHCPCD will be automatically installed)"
    info_print "4) dhcpcd: Basic DHCP client (Ethernet connections or VMs)"
    info_print "5) I will do this on my own (only advanced users)"
    input_print "Please select the number of the corresponding networking utility (e.g. 1): "
    read -r network_choice

    case "$network_choice" in
        1)
            network_pkg="networkmanager"
            systemctl_cmd="systemctl enable NetworkManager"
            ;;
        2)
            network_pkg="iwd"
            systemctl_cmd="systemctl enable iwd"
            ;;
        3)
            network_pkg="wpa_supplicant dhcpcd"
            systemctl_cmd="systemctl enable wpa_supplicant dhcpcd"
            ;;
        4)
            network_pkg="dhcpcd"
            systemctl_cmd="systemctl enable dhcpcd"
            ;;
        5)
            info_print "Skipping network configuration as requested by user."
            return 0
            ;;
        *)
            error_print "Invalid selection. Please run the script again and select a valid network utility."
            exit 1
            ;;
    esac

    info_print "Installing $network_pkg inside the chroot environment..."
    arch-chroot /mnt pacman -Sy --noconfirm $network_pkg &>> \"$LOGFILE\" || {
        error_print "Failed to install $network_pkg"
        exit 1
    }

    info_print "Enabling network service..."
    arch-chroot /mnt $systemctl_cmd || {
        warning_print "Failed to enable network service."
    }

    success_print "Network utility $network_pkg installed and enabled."
}

# ======================= ZRAM Setup ======================
setup_zram() {
  info_print "Configuring ZRAM..."

  cat > /mnt/etc/systemd/zram-generator.conf <<EOF
[zram0]
zram-size = min(ram, 8192)
compression-algorithm = zstd
EOF

  success_print "ZRAM configured with dynamic size (up to 8 GB) using zstd compression."
}

# ======================= Install editor ======================
install_editor() {
    info_print "Select a default text editor to install:"
    info_print "1) Nano (simple editor)"
    info_print "2) Neovim (modern Vim)"
    info_print "3) Vim (classic editor)"
    info_print "4) Micro (user-friendly terminal editor)"
    input_print "Please select the number of the corresponding editor (e.g. 1): "
    read -r editor_choice

    case "$editor_choice" in
        1)
            editor_pkg="nano"
            editor_bin="nano"
            ;;
        2)
            editor_pkg="neovim"
            editor_bin="nvim"
            ;;
        3)
            editor_pkg="vim"
            editor_bin="vim"
            ;;
        4)
            editor_pkg="micro"
            editor_bin="micro"
            ;;
        *)
            warning_print "Invalid selection, defaulting to nano."
            editor_pkg="nano"
            editor_bin="nano"
            ;;
    esac

    info_print "Installing $editor_pkg and setting it as default editor..."
    pacstrap /mnt "$editor_pkg" &>/dev/null
    echo "EDITOR=$editor_bin" >> /mnt/etc/environment
    echo "VISUAL=$editor_bin" >> /mnt/etc/environment
}

# ======================= Configure default shell ======================
configure_default_shell() {
    info_print "Setting default shell to zsh system-wide."
    sed -i 's|^SHELL=/usr/bin/bash|SHELL=/usr/bin/zsh|' /mnt/etc/default/useradd

    info_print "Downloading default .zshrc and related user files..."
    curl -sSLo /mnt/etc/skel/.zshrc https://raw.githubusercontent.com/NeonGOD78/ArchLinuxPlus/refs/heads/main/configs/etc/skel/.zshrc
    curl -sSLo /mnt/etc/zsh/zshrc https://raw.githubusercontent.com/NeonGOD78/ArchLinuxPlus/refs/heads/main/configs/etc/zsh/zshrc

    mkdir -p /mnt/etc/skel/.local/bin
    curl -sSLo /mnt/etc/skel/.local/bin/setup-default-zsh https://raw.githubusercontent.com/NeonGOD78/ArchLinuxPlus/refs/heads/main/configs/etc/skel/.local/bin/setup-default-zsh
    chmod +x /mnt/etc/skel/.local/bin/setup-default-zsh

    mkdir -p /mnt/etc/skel/.cache/oh-my-posh/themes
    curl -sSLo /mnt/etc/skel/.cache/oh-my-posh/themes/zen.toml https://raw.githubusercontent.com/NeonGOD78/ArchLinuxPlus/refs/heads/main/configs/etc/skel/.cache/oh-my-posh/themes/zen.toml

    curl -sSLo /mnt/etc/skel/.bashrc https://raw.githubusercontent.com/NeonGOD78/ArchLinuxPlus/refs/heads/main/configs/etc/skel/.bashrc
    curl -sSLo /mnt/etc/skel/.aliases https://raw.githubusercontent.com/NeonGOD78/ArchLinuxPlus/refs/heads/main/configs/etc/skel/.aliases
}

# ======================= Configure hostname & hosts ======================
configure_hostname_and_hosts() {
    info_print "Setting hostname..."
    echo "$hostname" > /mnt/etc/hostname

    info_print "Configuring /etc/hosts file..."
    cat > /mnt/etc/hosts <<HOSTFILE_EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain   $hostname
HOSTFILE_EOF
}

# =================== Pacman Eye-Candy Setup ===================
configure_pacman() {
    info_print "Applying eye-candy and performance tweaks to pacman."

    PACMAN_CONF="/mnt/etc/pacman.conf"

    sed -Ei '
        s/^#Color$/Color/
        /Color/ a ILoveCandy
        s/^#ParallelDownloads.*/ParallelDownloads = 10/
        s/^#VerbosePkgLists$/VerbosePkgLists/
        s/^#CheckSpace$/CheckSpace/
    ' "$PACMAN_CONF"
}

# =============== Pacman Repositories & Testing Setup ===============
configure_pacman_repos() {
    info_print "Enabling multilib and adding testing repositories with limited usage."

    PACMAN_CONF="/mnt/etc/pacman.conf"

    # Enable multilib repo
    sed -i '/#\[multilib\]/,/^#Include/ s/^#//' "$PACMAN_CONF"

    # Add testing repos with proper Usage flags if not already present
    if ! grep -q "\[core-testing\]" "$PACMAN_CONF"; then
        cat >> "$PACMAN_CONF" <<'EOF'

[core-testing]
Usage = Sync Upgrade Search Local
Include = /etc/pacman.d/mirrorlist

[extra-testing]
Usage = Sync Upgrade Search Local
Include = /etc/pacman.d/mirrorlist

[community-testing]
Usage = Sync Upgrade Search Local
Include = /etc/pacman.d/mirrorlist

[multilib-testing]
Usage = Sync Upgrade Search Local
Include = /etc/pacman.d/mirrorlist
EOF
    fi
}

# ======================= makepkg.conf Tweaks ========================
configure_makepkg() {
    info_print "Optimizing makepkg.conf for faster and clearer builds."

    MAKEPKG_CONF="/mnt/etc/makepkg.conf"

    # Use all available CPU threads for compiling
    sed -i "s/^#MAKEFLAGS=.*/MAKEFLAGS=\"-j$(nproc)\"/" "$MAKEPKG_CONF"

    # Enable colored build output
    sed -i 's/^#*\s*BUILDENV=.*/BUILDENV=(!distcc color !ccache !check !sign)/' "$MAKEPKG_CONF"

    # Ensure .zst package compression (standard since pacman 6)
    sed -i 's/^PKGEXT=.*/PKGEXT=".pkg.tar.zst"/' "$MAKEPKG_CONF"
}

# =================== System Services Enablement ===================
enable_system_services() {
    info_print "Enabling Reflector, automatic snapshots, BTRFS scrubbing, Grub Snapper menu and systemd-oomd."

    services=(
        reflector.timer
        snapper-timeline.timer
        snapper-cleanup.timer
        btrfs-scrub@-.timer
        btrfs-scrub@home.timer
        btrfs-scrub@var-log.timer
        btrfs-scrub@\\x2esnapshots.timer
        grub-btrfsd.service
        systemd-oomd
    )

    for service in "${services[@]}"; do
        systemctl enable "$service" --root=/mnt &>/dev/null || warning_print "Could not enable $service"
    done
}

# =========================== Final Message ===========================
finish_installation() {
  info_print "Done, you may now wish to reboot (further changes can be done by chrooting into /mnt)."
  info_print "Tip: If you ever rebuild your kernel manually, run: ${BOLD}update-uki${RESET} to regenerate and sign your UKI images."
}

# ====================== AUR Helper: yay Installer ======================
install_yay() {
    info_print "Installing yay (AUR helper)..."

    arch-chroot /mnt /bin/bash -e <<'EOF'
set -e

# Install required build tools
pacman -Sy --noconfirm git base-devel

# Create temporary user to build yay safely
useradd -m aurbuilder
echo "aurbuilder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/aurbuilder

# Build and install yay
sudo -u aurbuilder bash -c '
  cd /home/aurbuilder
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm
'

# Remove builder user and clean up
userdel -r aurbuilder
rm -f /etc/sudoers.d/aurbuilder

# Add yay alias to default shell configs
echo "alias aur='yay'" >> /etc/skel/.bashrc
echo "alias aur='yay'" >> /etc/skel/.zshrc

EOF

    success_print "yay installed successfully with alias 'aur' in .bashrc and .zshrc"
}

# ======================== GRUB Theme Setup =========================
configure_grub_theme() {
    info_print "Select GRUB theme resolution:"
    info_print "1) 1080p (1920x1080)"
    info_print "2) 2K (2560x1440)"
    input_print "Enter choice (1 or 2): "
    read -r theme_choice

    theme_url_base="https://github.com/NeonGOD78/ArchLinuxPlus/raw/main/configs/boot/grub/themes"

    case "$theme_choice" in
        1)
            theme_file="arch-1080p.zip"
            theme_dir="arch-1080p"
            gfx_mode="1920x1080"
            ;;
        2)
            theme_file="arch-2K.zip"
            theme_dir="arch-2K"
            gfx_mode="2560x1440"
            ;;
        *)
            warning_print "Invalid choice, defaulting to 1080p."
            theme_file="arch-1080p.zip"
            theme_dir="arch-1080p"
            gfx_mode="1920x1080"
            ;;
    esac

    info_print "Downloading and installing $theme_dir theme for GRUB."

    mkdir -p "/mnt/boot/grub/themes/$theme_dir"
    if ! curl -L "$theme_url_base/$theme_file" -o /tmp/theme.zip; then
        warning_print "Failed to download GRUB theme. Skipping theme installation."
        return 1
    fi

    bsdtar -xf /tmp/theme.zip -C "/mnt/boot/grub/themes/$theme_dir"

    echo "GRUB_THEME=\"/boot/grub/themes/$theme_dir/theme.txt\"" >> /mnt/etc/default/grub
    sed -i "s/^#GRUB_GFXMODE=.*/GRUB_GFXMODE=$gfx_mode/" /mnt/etc/default/grub

    echo 'GRUB_ENABLE_CRYPTODISK=y' >> /mnt/etc/default/grub

    # Save visuals config for later use
    save_boot_visuals_config

    echo 'GRUB_GFXPAYLOAD_LINUX=keep' >> /mnt/etc/default/grub

    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
}

# ======================== Plymouth Theme Setup =========================
configure_plymouth_theme() {
    info_print "Installing and configuring Plymouth dark theme."

    arch-chroot /mnt /bin/bash -e <<'EOF'
# Install plymouth
pacman -Sy --noconfirm plymouth

# Clone plymouth themes
git clone https://github.com/adi1090x/plymouth-themes.git /tmp/plymouth-themes
cp -r /tmp/plymouth-themes/arch-dark /usr/share/plymouth/themes/arch-dark
rm -rf /tmp/plymouth-themes

# Set theme
plymouth-set-default-theme -R arch-dark

# Enable splash in GRUB
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3"/' /etc/default/grub

# Add plymouth to mkinitcpio HOOKS if not already there
sed -i 's/^\(HOOKS=.*\)udev/\1plymouth udev/' /etc/mkinitcpio.conf

# Rebuild initramfs and grub
mkinitcpio -P
grub-mkconfig -o /boot/grub/grub.cfg
EOF
}

# =================== Save Boot Visuals Configuration ===================
save_boot_visuals_config() {
    info_print "Saving boot theme configuration to /etc/archinstaller.conf"

    config_file="/mnt/etc/archinstaller.conf"

    {
        echo "GRUB_THEME_DIR=$theme_dir"
        echo "GRUB_GFXMODE=$gfx_mode"
        echo "PLYMOUTH_THEME=arch-dark"
    } >> "$config_file"
}

# ===================== Dotfiles Setup via stow ======================
install_dotfiles_with_stow() {
    input_print "Do you want to clone and apply dotfiles from GitHub? (y/N): "
    read -r answer

    if [[ ! "$answer" =~ ^[Yy](es)?$ ]]; then
        info_print "Skipping dotfiles setup."
        return
    fi

    input_print "Enter your dotfiles GitHub repo URL (e.g. https://github.com/username/dotfiles): "
    read -r dotfiles_url

    if [[ -z "$dotfiles_url" ]]; then
        warning_print "No URL provided. Skipping."
        return
    fi

    info_print "Cloning dotfiles to ~/.dotfiles (shallow) and applying with stow..."

    arch-chroot /mnt /bin/bash -e <<EOF
set -euo pipefail

user="$username"
homedir="/home/\$user"

# Clone dotfiles repo to ~/.dotfiles
sudo -u \$user git clone --depth=1 "$dotfiles_url" "\$homedir/.dotfiles"

# Apply all stowable folders inside ~/.dotfiles
cd "\$homedir/.dotfiles"
sudo -u \$user stow */
EOF

    success_print "Dotfiles installed from ~/.dotfiles and applied using stow."
}

# ======================= Clone Dotfiles ======================
clone_dotfiles_repo() {
    input_print "Enter the GitHub repository URL of your dotfiles (HTTPS, e.g. https://github.com/youruser/dotfiles): "
    read -r repo_url

    if [[ -z "$repo_url" ]]; then
        warning_print "No repository URL entered. Skipping dotfiles setup."
        return 0
    fi

    info_print "Cloning dotfiles repository..."
    arch-chroot /mnt /bin/bash -e <<EOF
set -e
git clone --depth 1 "$repo_url" /home/$username/.dotfiles
chown -R $username:$username /home/$username/.dotfiles
EOF

    success_print "Dotfiles cloned to /home/$username/.dotfiles"
    info_print "Tip: Use 'stow <pkg>' to activate dotfiles inside the system."
}

# ======================= Dotfiles Setup =======================
dotfiles_clone() {
    input_print "Enter GitHub URL for your dotfiles repository (or leave blank to skip): "
    read -r dotfiles_url

    if [[ -z "$dotfiles_url" ]]; then
        info_print "No dotfiles repository specified, skipping."
        return
    fi

    info_print "Cloning dotfiles into /home/$username/.dotfiles..."

    arch-chroot /mnt /bin/bash -e <<EOF
user_home="/home/$username"
sudo -u "$username" git clone --depth 1 "$dotfiles_url" "\$user_home/.dotfiles"
chown -R "$username:$username" "\$user_home/.dotfiles"
EOF

    success_print "Dotfiles cloned to /home/$username/.dotfiles"
    info_print "You can now run 'stow <pkg>' from ~/.dotfiles after login."
}

# ======================= Generate fstab ======================
generate_fstab() {
  info_print "Generating /etc/fstab..."
  genfstab -U /mnt >> /mnt/etc/fstab
  success_print "fstab generated."
}


# ======================= Show Installation Log =======================
show_log_if_needed() {
  input_print "Would you like to view the log file now? (y/N): "
  read -r showlog
  if [[ "${showlog,,}" == "y" || "${showlog,,}" == "yes" ]]; then
    less +G "$LOGFILE"
  fi
}


# ======================= Prepare disk ==============
prepare_disk() {
  input_print "Do you want to secure wipe $DISK ? [y/N]: "
  read -r initial_zero
  if [[ "${initial_zero,,}" =~ ^(yes|y)$ ]]; then
    info_print "Secure wiping $DISK..."
    dd if=/dev/zero of="$DISK" bs=1M status=none
    success_print "Disk $DISK has been securely wiped."
    return 0
  fi

  sgdisk --zap-all "$DISK" &>/dev/null
  wipefs -af "$DISK" &>/dev/null
  partprobe "$DISK" &>/dev/null

  # Beregn root størrelse (50 % af disk)
  DISK_SIZE_GB=$(lsblk -bno SIZE "$DISK" | awk '{printf "%.0f", $1 / (1024*1024*1024)}')
  DEFAULT_ROOT_SIZE=$((DISK_SIZE_GB / 2))

  input_print "Enter root partition size (e.g. ${DEFAULT_ROOT_SIZE}G). Default is ${DEFAULT_ROOT_SIZE}G: "
  read -r root_size
  root_size=${root_size:-${DEFAULT_ROOT_SIZE}G}

  info_print "Creating partitions on $DISK..."
  parted -s "$DISK" \
    mklabel gpt \
    mkpart ESP fat32 1MiB 1025MiB \
    set 1 esp on \
    mkpart CRYPTROOT 1025MiB "$root_size" \
    mkpart CRYPTHOME "$root_size" 100% &>/dev/null

  partprobe "$DISK" &>/dev/null

  ESP="${DISK}p1"
  CRYPTROOT="${DISK}p2"
  CRYPTHOME="${DISK}p3"

  luks_found=false
  info_print "Checking for existing LUKS headers on partitions..."
  for part in "$CRYPTROOT" "$CRYPTHOME"; do
    if [[ -b $part ]] && cryptsetup isLuks "$part" &>/dev/null; then
      warning_print "LUKS header detected on $part"
      luks_found=true
    fi
  done

  if [[ "$luks_found" == true ]]; then
    warning_print "LUKS headers detected. Secure wiping is required."
    dd if=/dev/zero of="$DISK" bs=1M status=none
    success_print "Disk $DISK has been securely zeroed."
  else
    success_print "No LUKS partitions detected. Proceeding without zeroing."
  fi

  success_print "Disk prepared and partitions created successfully."
}


# ======================= Setup Users & Passwords ==============
setup_users_and_passwords() {
  section_print "User and Password Setup"

  input_print "Enter a system username (leave empty to only create root user): "
  read -r username

  input_print "Do you want to reuse the LUKS password for user and root? [Y/n]: "
  read -r reuse
  if [[ "${reuse,,}" =~ ^(n|no)$ ]]; then
    password=$(get_valid_password "Enter new system password")
  else
    info_print "Reusing LUKS password for user and root accounts."
  fi

  if [[ -n "$username" ]]; then
    if [[ "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
      useradd -m -G wheel -s /bin/bash "$username"
      echo "$username:$password" | chpasswd
      success_print "User '$username' created."
    else
      warning_print "Invalid username. Skipping user creation."
    fi
  else
    info_print "No username provided. Only root account will be created."
  fi

  echo "root:$password" | chpasswd
  success_print "Root password set."
}

# ======================= Main Installer Flow ==============
main() {
  welcome_banner
  keyboard_selector
  select_disk
  prepare_disk
  lukspass_selector
  encrypt_partitions
  format_partitions
  mount_btrfs_subvolumes
  kernel_selector
  microcode_detector
  locale_selector
  hostname_selector
    


  until install_base_system; do : ; done
  
  move_log_file
  setup_users_and_passwords
  generate_fstab
  configure_hostname_and_hosts
  setup_zram
  network_selector
  install_editor
  configure_default_shell
  setup_secureboot_structure
  setup_timezone_and_clock_chroot
  setup_locale_and_initramfs_chroot
  setup_snapper_chroot
  install_grub_chroot
  sign_grub_chroot
  setup_grub_btrfs_chroot
  build_uki_chroot
  generate_grub_cfg
  setup_users_and_passwords
  dotfiles_clone
  configure_pacman
  configure_pacman_repos
  configure_makepkg
  enable_system_services
  install_yay
  configure_grub_theme
  configure_plymouth_theme
  save_boot_visuals_config
  finish_installation
  show_log_if_needed
}

main

exit