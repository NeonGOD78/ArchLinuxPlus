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

# ======================= Password Prompt Helper ======================
get_valid_password() {
  local prompt="$1"
  local pass1 pass2

  while true; do
    input_print "$prompt: "
    read -r -s pass1
    echo

    if [[ -z "$pass1" ]]; then
      warning_print "Password cannot be empty."
      continue
    fi

    input_print "Confirm $prompt: "
    read -r -s pass2
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
    input_print "Please insert the keyboard layout to use in console (enter empty to use US, or \"/\" to look up for keyboard layouts): "
    read -r kblayout
    case "$kblayout" in
        '') kblayout="us"
            info_print "The standard US keyboard layout will be used."
            return 0;;
        '/') localectl list-keymaps
             clear
             return 1;;
        *) if ! localectl list-keymaps | grep -Fxq "$kblayout"; then
               error_print "The specified keymap doesn't exist."
               return 1
           fi
        info_print "Changing console layout to $kblayout."
        loadkeys "$kblayout"
        return 0
    esac
}

# ======================= Locale Selection ======================
locale_selector () {
    input_print "Please insert the locale you use (format: xx_XX. Enter empty to use en_US, or \"/\" to search locales): "
    read -r locale
    case "$locale" in
        '') locale="en_US.UTF-8"
            info_print "$locale will be the default locale."
            return 0;;
        '/') sed -E '/^# +|^#$/d;s/^#| *$//g;s/ .*/ (Charset:&)/' /etc/locale.gen | less -M
                clear
                return 1;;
        *)  if ! grep -q "^#\?$(sed 's/[]\\.*[]/\\&/g' <<< "$locale") " /etc/locale.gen; then
                error_print "The specified locale doesn't exist or isn't supported."
                return 1
            fi
            return 0
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

# ======================= Reuse LUKS Password ======================
reuse_password() {
  input_print "Do you want to use the same password for root and user? (YES/no): "
  read -r choice
  choice=${choice,,}  # to lowercase

  if [[ "$choice" == "yes" || "$choice" == "y" || -z "$choice" ]]; then
    rootpass="$password"
    userpass="$password"
    info_print "Same password will be used for root and user."
  else
    info_print "Separate passwords will be used."
    rootpass=$(get_valid_password "root password")
    userpass=$(get_valid_password "user password")
  fi
}

# ======================= Disk Wipe Confirmation ==========
confirm_disk_wipe() {
  input_print "This will delete the current partition table on $DISK. Proceed? [y/N]: "
  read -r response
  if ! [[ "${response,,}" =~ ^(yes|y)$ ]]; then
    error_print "Disk wipe cancelled."
    exit 1
  fi
  info_print "Wiping $DISK..."
  wipefs -af "$DISK" &>/dev/null
  sgdisk -Zo "$DISK" &>/dev/null
}

# ======================= Partition Disk ===================
partition_disk() {
  input_print "Enter root partition size (e.g. 100G): "
  read -r root_size
  if [[ -z "$root_size" ]]; then
    error_print "You must specify a root size."
    exit 1
  fi

  info_print "Creating partitions on $DISK..."
  parted -s "$DISK" \
    mklabel gpt \
    mkpart ESP fat32 1MiB 1025MiB \
    set 1 esp on \
    mkpart CRYPTROOT 1025MiB "$root_size" \
    mkpart CRYPTHOME "$root_size" 100%

  partprobe "$DISK"

  ESP="/dev/disk/by-partlabel/ESP"
  CRYPTROOT="/dev/disk/by-partlabel/CRYPTROOT"
  CRYPTHOME="/dev/disk/by-partlabel/CRYPTHOME"
}

# ======================= Encrypt Partitions ===============
encrypt_partitions() {
  info_print "Encrypting root partition..."
  echo -n "$password" | cryptsetup luksFormat "$CRYPTROOT" -d - &>> \"$LOGFILE\"
  echo -n "$password" | cryptsetup open "$CRYPTROOT" cryptroot -d -

  info_print "Encrypting home partition..."
  echo -n "$password" | cryptsetup luksFormat "$CRYPTHOME" -d - &>> \"$LOGFILE\"
  echo -n "$password" | cryptsetup open "$CRYPTHOME" crypthome -d -
}

# ======================= Format Partitions ================
format_partitions() {
  info_print "Formatting EFI partition as FAT32..."
  mkfs.fat -F32 "$ESP" &>> \"$LOGFILE\"

  info_print "Formatting root (cryptroot) as BTRFS..."
  mkfs.btrfs /dev/mapper/cryptroot &>> \"$LOGFILE\"

  info_print "Formatting home (crypthome) as BTRFS..."
  mkfs.btrfs /dev/mapper/crypthome &>> \"$LOGFILE\"
}


# ======================= Install Base System ======================
install_base_system() {
  info_print "Installing the base system (this may take a while)..."

if pacstrap -K /mnt base "$kernel" "$microcode" linux-firmware "$kernel"-headers \
    btrfs-progs grub grub-btrfs rsync efibootmgr snapper reflector snap-pac \
    zram-generator sudo inotify-tools zsh unzip fzf zoxide colordiff curl \
    btop mc git systemd ukify openssl sbsigntools sbctl &>> \"$LOGFILE\"; then

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
    btrfs subvolume create /mnt/$subvol &>> \"$LOGFILE\"
  done
  umount /mnt

  info_print "Creating BTRFS subvolume on home partition..."
  mount /dev/mapper/crypthome /mnt
  btrfs subvolume create /mnt/@home &>> \"$LOGFILE\"
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

setup_timezone_and_clock_chroot() {
  info_print "Setting timezone and synchronizing hardware clock (in chroot)..."
  arch-chroot /mnt /bin/bash -e <<'EOF'
set -euo pipefail
ZONE=$(curl -s http://ip-api.com/line?fields=timezone)
ln -sf "/usr/share/zoneinfo/$ZONE" /etc/localtime || echo "[!] Failed to set timezone"
hwclock --systohc || echo "[!] Failed to sync hardware clock"
EOF
}

setup_locale_and_initramfs_chroot() {
  info_print "Generating locale and initramfs (in chroot)..."
  arch-chroot /mnt /bin/bash -e <<'EOF'
set -euo pipefail
locale-gen || echo "[!] Failed to generate locale"
mkinitcpio -P || echo "[!] mkinitcpio failed"
EOF
}

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

setup_users_and_passwords() {
  info_print "Setting passwords and creating user..."

  echo "root:$rootpass" | arch-chroot /mnt chpasswd
  arch-chroot /mnt usermod -s /usr/bin/zsh root

  if [[ -n "$username" ]]; then
    echo "%wheel ALL=(ALL:ALL) ALL" > /mnt/etc/sudoers.d/wheel
    info_print "Adding the user $username to the system with root privileges..."
    arch-chroot /mnt useradd -m -G wheel -s /usr/bin/zsh "$username"
    echo "$username:$userpass" | arch-chroot /mnt chpasswd
  fi
}

# ======================= Disk Selection ======================
select_disk() {
  section_print "Disk Selection"

  # Hent liste over fysiske diske (ingen loop, rom eller boot mounts)
  mapfile -t disks < <(lsblk -dpno NAME,SIZE,MODEL | grep -Ev "boot|rpmb|loop")

  if [[ "${#disks[@]}" -eq 0 ]]; then
    error_print "No suitable block devices found."
    exit 1
  fi

  echo
  info_print "Detected disks:"
  for i in "${!disks[@]}"; do
    printf "  %d) %s
" "$((i+1))" "${disks[$i]}"
  done
  echo

  input_print "Select the number of the disk to install Arch on (e.g. 1): "
  read -r disk_index

  # Check if input is a number in valid range
  if ! [[ "$disk_index" =~ ^[0-9]+$ ]] || (( disk_index < 1 || disk_index > ${#disks[@]} )); then
    error_print "Invalid selection. Aborting."
    exit 1
  fi

  DISK=$(awk '{print $1}' <<< "${disks[$((disk_index-1))]}")

  echo
  success_print "You selected: $DISK"
  echo

  info_print "Partition layout:"
  lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINT,LABEL,UUID "$DISK" | less -S
  clear

  warning_print "⚠️  This will WIPE the entire disk: $DISK"
  input_print "Type 'yes' to confirm and continue: "
  read -r confirm

  if [[ "${confirm,,}" != "yes" ]]; then
    error_print "Disk selection aborted."
    exit 1
  fi

  success_print "Disk $DISK confirmed and ready for partitioning."
}

# ======================= LUKS Password Input ======================
lukspass_selector() {
  input_print "Enter password to use for disk encryption (LUKS): "

  old_stty_cfg=$(stty -g)
  stty -echo
  read -r password
  stty "$old_stty_cfg"
  echo

  if [[ -z "$password" ]]; then
    error_print "No password entered. Aborting."
    exit 1
  fi

  info_print "Disk encryption password set."
}

# ======================= Root Password Setup ======================
rootpass_selector() {
  rootpass=$(get_valid_password "root password")
  info_print "Root password has been set."
}

# ======================= User + Password Setup ======================
userpass_selector() {
 input_print "Enter username for new user: "
read -r username

if [[ -z "$username" ]]; then
  error_print "Username cannot be empty."
  exit 1
fi

userpass=$(get_valid_password "password for user $username")
info_print "User $username and password registered."
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


# ======================= Main Installer Flow ==============
main() {
  welcome_banner
  keyboard_selector
  select_disk
  lukspass_selector
  reuse_password
  kernel_selector
  microcode_detector
  locale_selector
  hostname_selector
  userpass_selector
  rootpass_selector
  confirm_disk_wipe
  partition_disk
  encrypt_partitions
  format_partitions
  mount_btrfs_subvolumes

  until install_base_system; do : ; done

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