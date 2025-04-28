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
exec > >(tee -a "$LOGFILE") 2>&1
info_print "Log file created at $LOGFILE"

# ======================= Move Log File =======================
move_log_file() {
  if [[ -d /mnt ]]; then
    mkdir -p /mnt/var/log
    cp "$LOGFILE" /mnt/var/log/archinstall.log
    LOGFILE="/mnt/var/log/archinstall.log"
    info_print "Log file moved to $LOGFILE"
  else
    warning_print "Warning: /mnt is not mounted. Log file not moved."
  fi
}

check_tty() {
  if { [ ! -e /dev/tty ] || [ ! -r /dev/tty ]; } && { [ ! -e /dev/console ] || [ ! -r /dev/console ]; }; then
    error_print "No usable terminal device detected."
    error_print "This script must be run inside a real terminal."
    exit 1
  fi
}

read_from_tty() {
  if [ -e /dev/tty ] && [ -r /dev/tty ]; then
    read "$@" < /dev/tty
  elif [ -e /dev/console ] && [ -r /dev/console ]; then
    read "$@" < /dev/console
  else
    error_print "No usable terminal device found for input."
    exit 1
  fi
}

# ======================= Password Prompt Helper ======================
get_valid_password() {
  local prompt="$1"
  local show_password=""
  local pass1 pass2

  input_print "Show password while typing? [y/N]:"
  read_from_tty -r show_password
  echo

  while true; do
    input_print "$prompt"
    if [[ "${show_password,,}" == "y" ]]; then
      stty echo
    else
      stty -echo
    fi
    read_from_tty -r pass1
    stty echo
    echo

    if [[ -z "$pass1" ]]; then
      warning_print "Password cannot be empty. Please try again."
      continue
    fi

    input_print "Confirm $prompt"
    if [[ "${show_password,,}" == "y" ]]; then
      stty echo
    else
      stty -echo
    fi
    read_from_tty -r pass2
    stty echo
    echo

    if [[ -z "$pass2" ]]; then
      warning_print "Confirmation password cannot be empty. Please try again."
      continue
    fi

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

# ======================= Encrypt Partitions ===============
encrypt_partitions() {
  section_print "Encrypting root and home partitions with LUKS2"
  
  partprobe "$DISK"
  udevadm settle
  sleep 1

  # Prompt for LUKS password
  info_print "Setting up LUKS password..."
  password=$(get_valid_password "Enter LUKS password")
  
  # Encrypt and open root partition
  info_print "Encrypting root partition: $CRYPTROOT"
  echo -n "$password" | cryptsetup luksFormat "$CRYPTROOT" -q --type luks2 - || {
    error_print "Failed to format LUKS on $CRYPTROOT"
    exit 1
  }

  echo -n "$password" | cryptsetup open "$CRYPTROOT" cryptroot - || {
    error_print "Failed to open LUKS root partition"
    exit 1
  }

  # Encrypt and open home partition
  info_print "Encrypting home partition: $CRYPTHOME"
  echo -n "$password" | cryptsetup luksFormat "$CRYPTHOME" -q --type luks2 - || {
    error_print "Failed to format LUKS on $CRYPTHOME"
    exit 1
  }

  echo -n "$password" | cryptsetup open "$CRYPTHOME" crypthome - || {
    error_print "Failed to open LUKS home partition"
    exit 1
  }

  success_print "LUKS encryption completed and both devices are opened."
}

# ======================= Format Partitions ================
format_partitions() {
  section_print "Formatting partitions"

  # Format EFI system partition
  info_print "Formatting EFI partition as FAT32..."
  mkfs.fat -F32 "$ESP" &>> "$LOGFILE" || {
    error_print "Failed to format EFI partition ($ESP) as FAT32"
    return 1
  }

  # Format encrypted root partition with Btrfs
  info_print "Formatting root partition (cryptroot) as BTRFS..."
  mkfs.btrfs /dev/mapper/cryptroot &>> "$LOGFILE" || {
    error_print "Failed to format root partition as BTRFS"
    return 1
  }

  # Format encrypted home partition with Btrfs
  info_print "Formatting home partition (crypthome) as BTRFS..."
  mkfs.btrfs /dev/mapper/crypthome &>> "$LOGFILE" || {
    error_print "Failed to format home partition as BTRFS"
    return 1
  }

  success_print "All partitions formatted successfully."
}

# ======================= Install Base System ======================
install_base_system() {
  info_print "Installing the base system (this may take a while)..."

  if pacstrap -K /mnt base "$kernel" "$microcode" linux-firmware "$kernel"-headers \
      btrfs-progs grub grub-btrfs rsync efibootmgr snapper reflector snap-pac \
      zram-generator sudo inotify-tools zsh unzip fzf zoxide colordiff curl \
      btop mc git systemd ukify openssl sbsigntools sbctl base-devel &>> "$LOGFILE"; then

    success_print "Base system installed successfully."
    return 0
  else
    warning_print "Base system installation failed. Retrying in 5 seconds..."
    sleep 5
    return 1
  fi
}

# ======================= Setup Secure Boot Files ======================
setup_secureboot() {
  info_print "Setting up Secure Boot..."

  # Ensure the cryptroot device is defined
  cryptroot="/dev/mapper/cryptroot"
  root_uuid=$(blkid -s UUID -o value "$cryptroot")
  success_print "Found root UUID: $root_uuid"

  # Create Secure Boot directory
  info_print "Creating Secure Boot directory..."
  arch-chroot /mnt mkdir -p /etc/secureboot

  # Generate Secure Boot keys
  info_print "Generating Secure Boot keys..."
  openssl req -new -x509 -newkey rsa:2048 -keyout /mnt/etc/secureboot/db.key -out /mnt/etc/secureboot/db.crt -nodes -days 36500 -subj "/CN=My Secure Boot Signing Key/"

  # Create kernel command line
  info_print "Creating /etc/kernel/cmdline..."
  arch-chroot /mnt mkdir -p /etc/kernel
  echo "root=UUID=$root_uuid rw loglevel=3 quiet splash" | tee /mnt/etc/kernel/cmdline

  # Create update-uki helper script
  info_print "Creating update-uki script..."
  arch-chroot /mnt bash -c "cat > /usr/local/bin/update-uki << 'EOF'
#!/bin/bash
ukify build \
  --linux /boot/vmlinuz-linux \
  --initrd /boot/initramfs-linux.img \
  --cmdline /etc/kernel/cmdline \
  --output /efi/EFI/Linux/arch-linux.efi
sbsign --key /etc/secureboot/db.key --cert /etc/secureboot/db.crt /efi/EFI/Linux/arch-linux.efi --output /efi/EFI/Linux/arch-linux.efi
EOF"
  arch-chroot /mnt chmod +x /usr/local/bin/update-uki

  # Create UKI Pacman Hook
  info_print "Creating 95-ukify.hook..."
  arch-chroot /mnt mkdir -p /etc/pacman.d/hooks
  arch-chroot /mnt bash -c "cat > /etc/pacman.d/hooks/95-ukify.hook << 'EOF'
[Trigger]
Type = Package
Operation = Install
Operation = Upgrade
Target = linux

[Action]
Description = Updating and signing UKI...
When = PostTransaction
Exec = /usr/local/bin/update-uki
EOF"

  # Create UKI Fallback Pacman Hook
  info_print "Creating 96-ukify-fallback.hook..."
  arch-chroot /mnt bash -c "cat > /etc/pacman.d/hooks/96-ukify-fallback.hook << 'EOF'
[Trigger]
Type = Path
Operation = Install
Operation = Upgrade
Operation = Remove
Target = vmlinuz-linux
Target = initramfs-linux-fallback.img

[Action]
Description = Regenerating and signing fallback UKI...
When = PostTransaction
Exec = /usr/bin/bash -c \"ukify build \
  --linux /boot/vmlinuz-linux \
  --initrd /boot/initramfs-linux-fallback.img \
  --cmdline /etc/kernel/cmdline \
  --output /efi/EFI/Linux/arch-fallback.efi && \
  sbsign --key /etc/secureboot/db.key --cert /etc/secureboot/db.crt /efi/EFI/Linux/arch-fallback.efi --output /efi/EFI/Linux/arch-fallback.efi\"
EOF"

  # Create UKI Update Service
  info_print "Creating update-uki.service..."
  arch-chroot /mnt bash -c "cat > /etc/systemd/system/update-uki.service << 'EOF'
[Unit]
Description=Update and sign Unified Kernel Image
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/update-uki
EOF"

  # Create UKI Update Timer
  info_print "Creating update-uki.timer..."
  arch-chroot /mnt bash -c "cat > /etc/systemd/system/update-uki.timer << 'EOF'
[Unit]
Description=Run update-uki weekly

[Timer]
OnBootSec=10min
OnUnitActiveSec=1w
Unit=update-uki.service

[Install]
WantedBy=timers.target
EOF"

  # Enable UKI Update Timer
  success_print "Enabling update-uki.timer..."
  arch-chroot /mnt systemctl enable update-uki.timer
}

# ======================= Mount BTRFS Subvolumes ================
mount_btrfs_subvolumes() {
 
  section_print "Mounting Btrfs subvolumes and system partitions"
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

# ======================= System Configuration ======================
setup_system() {
  section_print "System Configuration"

  # -------- Locale Selector --------
  input_print "Enter locale or type '/' to search [default: en_DK.UTF-8]: "
  read -r locale
  locale=${locale:-en_DK.UTF-8}

  if [[ "$locale" == "/" ]]; then
    less /usr/share/i18n/SUPPORTED
    input_print "Enter locale (e.g., en_US.UTF-8): "
    read -r locale
  fi

  echo "$locale UTF-8" >> /mnt/etc/locale.gen
  echo "LANG=$locale" > /mnt/etc/locale.conf
  arch-chroot /mnt locale-gen &>> "$LOGFILE"

  # -------- Keyboard Selector --------
  input_print "Enter keyboard layout or type '/' to search [default: dk]: "
  read -r keymap
  keymap=${keymap:-dk}

  if [[ "$keymap" == "/" ]]; then
    localectl list-keymaps | less
    input_print "Enter keyboard layout (e.g., us, dk, de-latin1): "
    read -r keymap
  fi

  echo "KEYMAP=$keymap" > /mnt/etc/vconsole.conf
  loadkeys "$keymap"

  # -------- Timezone & Clock (via IP detection) --------
  info_print "Setting timezone and synchronizing hardware clock (in chroot)..."
  arch-chroot /mnt /bin/bash -e <<'EOF'
set -euo pipefail
ZONE=$(curl -s http://ip-api.com/line?fields=timezone)
ln -sf "/usr/share/zoneinfo/$ZONE" /etc/localtime || echo "[!] Failed to set timezone"
hwclock --systohc || echo "[!] Failed to sync hardware clock"
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
setup_grub() {
  section_print "GRUB Bootloader Installation and Theme Setup"

  theme_url_base="https://github.com/NeonGOD78/ArchLinuxPlus/raw/main/configs/boot/grub/themes"

  info_print "Select GRUB theme resolution:"
  info_print "1) 2K (2560x1440) [default]"
  info_print "2) 1080p (1920x1080)"
  input_print "Enter choice (1 or 2) [default: 1]: "
  read -r theme_choice
  theme_choice=${theme_choice:-1}

  case "$theme_choice" in
      1)
          theme_file="arch-2K.zip"
          theme_dir="arch-2K"
          gfx_mode="2560x1440"
          ;;
      2)
          theme_file="arch-1080p.zip"
          theme_dir="arch-1080p"
          gfx_mode="1920x1080"
          ;;
      *)
          warning_print "Invalid choice, defaulting to 2K."
          theme_file="arch-2K.zip"
          theme_dir="arch-2K"
          gfx_mode="2560x1440"
          ;;
  esac

  info_print "Downloading and installing GRUB theme: $theme_dir"
  mkdir -p "/mnt/boot/grub/themes/$theme_dir"
  if ! curl -L "$theme_url_base/$theme_file" -o /tmp/theme.zip; then
      warning_print "Failed to download GRUB theme. Skipping theme installation."
  else
      bsdtar -xf /tmp/theme.zip -C "/mnt/boot/grub/themes/$theme_dir"
  fi

  # Configure GRUB settings cleanly in /etc/default/grub
  grub_cfg_file="/mnt/etc/default/grub"
  declare -A grub_vars=(
    ["GRUB_ENABLE_CRYPTODISK"]="y"
    ["GRUB_GFXMODE"]="$gfx_mode"
    ["GRUB_GFXPAYLOAD_LINUX"]="keep"
    ["GRUB_THEME"]='"/boot/grub/themes/'"$theme_dir"'/theme.txt"'
    ["GRUB_TERMINAL_OUTPUT"]="gfxterm"
  )

  info_print "Writing GRUB configuration to /etc/default/grub..."
  for key in "${!grub_vars[@]}"; do
    value="${grub_vars[$key]}"
    if grep -q "^$key=" "$grub_cfg_file"; then
      sed -i "s|^$key=.*|$key=$value|" "$grub_cfg_file"
    elif grep -q "^#\s*$key=" "$grub_cfg_file"; then
      sed -i "s|^#\s*$key=.*|$key=$value|" "$grub_cfg_file"
    else
      echo "$key=$value" >> "$grub_cfg_file"
    fi
  done

  # Enable Plymouth splash screen
  info_print "Enabling Plymouth boot splash..."

  if grep -q "^GRUB_SPLASH=" "$grub_cfg_file"; then
    sed -i 's|^GRUB_SPLASH=.*|GRUB_SPLASH="/boot/plymouth/arch-logo.png"|' "$grub_cfg_file"
  else
    echo 'GRUB_SPLASH="/boot/plymouth/arch-logo.png"' >> "$grub_cfg_file"
  fi

  # Add or modify GRUB_CMDLINE_LINUX to include quiet splash
  if grep -q '^GRUB_CMDLINE_LINUX="' "$grub_cfg_file"; then
    sed -i 's|^GRUB_CMDLINE_LINUX="\([^"]*\)"|GRUB_CMDLINE_LINUX="quiet splash \1"|' "$grub_cfg_file"
  else
    echo 'GRUB_CMDLINE_LINUX="quiet splash"' >> "$grub_cfg_file"
  fi

  # Save theme + resolution to installer config
  echo "grub_theme='$theme_dir'" >> /mnt/etc/archinstaller.conf
  echo "grub_resolution='$gfx_mode'" >> /mnt/etc/archinstaller.conf

  # Install GRUB bootloader
  info_print "Installing GRUB bootloader..."
  arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB &>> "$LOGFILE"
  if [[ $? -ne 0 ]]; then
    error_print "GRUB installation failed"
    exit 1
  fi

  # Generate grub.cfg
  info_print "Generating grub.cfg..."
  arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg &>> "$LOGFILE"
  if [[ $? -ne 0 ]]; then
    error_print "Failed to generate grub.cfg"
    exit 1
  fi

  success_print "GRUB bootloader installed and configured successfully with theme, Plymouth and Secure Boot."
}

# ======================= Sign GRUB ======================
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

    error_print "!! ALL DATA ON $DISK WILL BE IRREVERSIBLY LOST !!"
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
    arch-chroot /mnt pacman -Sy --noconfirm $network_pkg &>> "$LOGFILE" || {
        error_print "Failed to install $network_pkg"
        exit 1
    }

    info_print "Enabling network service..."
    arch-chroot /mnt bash -c $systemctl_cmd || {
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

# =================== Configure package management ===================
configure_package_management() {
    section_print "Configuring Pacman, Repositories, Makepkg, and installing Yay"

    PACMAN_CONF="/mnt/etc/pacman.conf"
    MAKEPKG_CONF="/mnt/etc/makepkg.conf"

    # ======================= Pacman.conf Tweaks =======================
    info_print "Applying eye-candy and performance tweaks to pacman."
    sed -Ei '
        s/^#Color$/Color/
        /Color/ a ILoveCandy
        s/^#ParallelDownloads.*/ParallelDownloads = 10/
        s/^#VerbosePkgLists$/VerbosePkgLists/
        s/^#CheckSpace$/CheckSpace/
    ' "$PACMAN_CONF"

    # ======================= Pacman Repositories =======================
    info_print "Enabling multilib and adding testing repositories with limited usage."
    sed -i '/#\[multilib\]/,/^#Include/ s/^#//' "$PACMAN_CONF"

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

    # ======================= makepkg.conf Tweaks =======================
    info_print "Optimizing makepkg.conf for faster and clearer builds."
    sed -i "s/^#MAKEFLAGS=.*/MAKEFLAGS=\"-j$(nproc)\"/" "$MAKEPKG_CONF"
    sed -i 's/^#*\s*BUILDENV=.*/BUILDENV=(!distcc color !ccache !check !sign)/' "$MAKEPKG_CONF"
    sed -i 's/^PKGEXT=.*/PKGEXT=".pkg.tar.zst"/' "$MAKEPKG_CONF"

    # ======================= Install Yay safely =======================
    info_print "Installing yay (AUR helper) safely..."
    arch-chroot /mnt /bin/bash -e <<'EOF'
set -e

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


EOF
    success_print "yay installed successfully with alias 'aur' in .bashrc and .zshrc"
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
  section_print "Disk Partitioning and Setup"

  input_print "Do you want to secure wipe $DISK before install? [y/N]: "
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

  # Calculate root partition size (50% of total disk)
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
  udevadm settle
  sleep 2

  # Add partition prefix (e.g., "p" for NVMe)
  if [[ "$DISK" =~ nvme ]]; then
    part_prefix="p"
  else
    part_prefix=""
  fi

  # Wait for partitions to become available
  for part in 1 2 3; do
    dev="${DISK}${part_prefix}${part}"
    until [ -b "$dev" ]; do
      warning_print "Waiting for $dev to become available..."
      sleep 1
    done
  done

  ESP="${DISK}${part_prefix}1"
  CRYPTROOT="${DISK}${part_prefix}2"
  CRYPTHOME="${DISK}${part_prefix}3"

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
      info_print "Creating user '$username' and adding to wheel group..."
      arch-chroot /mnt useradd -m -G wheel -s /bin/bash "$username"
      arch-chroot /mnt bash -c "echo '$username:$password' | chpasswd"
      success_print "User '$username' created and password set."
    else
      warning_print "Invalid username. Skipping user creation."
    fi
  else
    info_print "No username provided. Only root account will be created."
  fi

  info_print "Setting root password..."
  arch-chroot /mnt bash -c "echo 'root:$password' | chpasswd"
  success_print "Root password set."

  info_print "Ensuring sudo access for wheel group..."
  arch-chroot /mnt sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
  success_print "Sudo access enabled for wheel group."
}

# ======================= System Configuration ======================
setup_system() {
  section_print "System Configuration"

  # -------- Locale Selector --------
  input_print "Enter locale or type '/' to search [default: en_DK.UTF-8]: "
  read -r locale
  locale=${locale:-en_DK.UTF-8}

  if [[ "$locale" == "/" ]]; then
    less /usr/share/i18n/SUPPORTED
    input_print "Enter locale (e.g., en_US.UTF-8): "
    read -r locale
  fi

  echo "$locale UTF-8" >> /mnt/etc/locale.gen
  echo "LANG=$locale" > /mnt/etc/locale.conf
  arch-chroot /mnt locale-gen &>> "$LOGFILE"

  # -------- Keyboard Selector --------
  input_print "Enter keyboard layout or type '/' to search [default: dk]: "
  read -r keymap
  keymap=${keymap:-dk}

  if [[ "$keymap" == "/" ]]; then
    localectl list-keymaps | less
    input_print "Enter keyboard layout (e.g., us, dk, de-latin1): "
    read -r keymap
  fi

  echo "KEYMAP=$keymap" > /mnt/etc/vconsole.conf
  loadkeys "$keymap"

  # -------- Timezone & Clock (via IP detection) --------
  info_print "Setting timezone and synchronizing hardware clock (in chroot)..."
  arch-chroot /mnt /bin/bash -e <<'EOF'
set -euo pipefail
ZONE=$(curl -s http://ip-api.com/line?fields=timezone)
ln -sf "/usr/share/zoneinfo/$ZONE" /etc/localtime || echo "[!] Failed to set timezone"
hwclock --systohc || echo "[!] Failed to sync hardware clock"
EOF

  # -------- Hostname --------
  input_print "Enter hostname [default: archlinux]: "
  read -r hostname
  hostname=${hostname:-archlinux}
  echo "$hostname" > /mnt/etc/hostname

  # /etc/hosts
  cat <<EOF > /mnt/etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain $hostname
EOF
}


# ======================= Main Installer Flow ==============
main() {
  check_tty
  welcome_banner
  select_disk
  prepare_disk
  encrypt_partitions
  format_partitions
  mount_btrfs_subvolumes
  kernel_selector
  microcode_detector

  until install_base_system; do : ; done
  
  move_log_file
  configure_package_management
  setup_zram
  setup_system
  setup_users_and_passwords
  generate_fstab
  network_selector
  install_editor
  configure_default_shell
  setup_snapper_chroot
  setup_grub
  sign_grub_chroot
  setup_grub_btrfs_chroot
  build_uki_chroot
  setup_secureboot
  dotfiles_clone
  
  enable_system_services
  finish_installation
  show_log_if_needed
}

main

exit
