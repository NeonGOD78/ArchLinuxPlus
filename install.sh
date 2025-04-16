#!/usr/bin/env -S bash -e

set -o pipefail
# Cleaning the TTY.
clear

# Cosmetics (colours for text).
BOLD='\e[1m'
BRED='\e[91m'
BBLUE='\e[34m'  
BGREEN='\e[92m'
BYELLOW='\e[93m'
RESET='\e[0m'

# Pretty print (function).
info_print () {
    echo -e "${BOLD}${BGREEN}[ ${BYELLOW}•${BGREEN} ] $1${RESET}"
}

# Pretty print for input (function).
input_print () {
    echo -ne "${BOLD}${BYELLOW}[ ${BGREEN}•${BYELLOW} ] $1${RESET}"
}

# Alert user of bad input (function).
error_print () {
    echo -e "${BOLD}${BRED}[ ${BBLUE}•${BRED} ] $1${RESET}"
}

# Virtualization check (function).
virt_check () {
    hypervisor=$(systemd-detect-virt)
    case $hypervisor in
        kvm )   info_print "KVM has been detected, setting up guest tools."
                pacstrap /mnt qemu-guest-agent &>/dev/null
                systemctl enable qemu-guest-agent --root=/mnt &>/dev/null
                ;;
        vmware  )   info_print "VMWare Workstation/ESXi has been detected, setting up guest tools."
                    pacstrap /mnt open-vm-tools >/dev/null
                    systemctl enable vmtoolsd --root=/mnt &>/dev/null
                    systemctl enable vmware-vmblock-fuse --root=/mnt &>/dev/null
                    ;;
        oracle )    info_print "VirtualBox has been detected, setting up guest tools."
                    pacstrap /mnt virtualbox-guest-utils &>/dev/null
                    systemctl enable vboxservice --root=/mnt &>/dev/null
                    ;;
        microsoft ) info_print "Hyper-V has been detected, setting up guest tools."
                    pacstrap /mnt hyperv &>/dev/null
                    systemctl enable hv_fcopy_daemon --root=/mnt &>/dev/null
                    systemctl enable hv_kvp_daemon --root=/mnt &>/dev/null
                    systemctl enable hv_vss_daemon --root=/mnt &>/dev/null
                    ;;
    esac
}

# Selecting a kernel to install (function).
kernel_selector () {
    info_print "List of kernels:"
    info_print "1) Stable: Vanilla Linux kernel with a few specific Arch Linux patches applied"
    info_print "2) Hardened: A security-focused Linux kernel"
    info_print "3) Longterm: Long-term support (LTS) Linux kernel"
    info_print "4) Zen Kernel: A Linux kernel optimized for desktop usage"
    input_print "Please select the number of the corresponding kernel (e.g. 1): " 
    read -r kernel_choice
    case $kernel_choice in
        1 ) kernel="linux"
            return 0;;
        2 ) kernel="linux-hardened"
            return 0;;
        3 ) kernel="linux-lts"
            return 0;;
        4 ) kernel="linux-zen"
            return 0;;
        * ) error_print "You did not enter a valid selection, please try again."
            return 1
    esac
}

# Selecting a way to handle internet connection (function).
network_selector () {
    info_print "Network utilities:"
    info_print "1) NetworkManager: Universal network utility (both WiFi and Ethernet, highly recommended)"
    info_print "2) IWD: Utility to connect to networks written by Intel (WiFi-only, built-in DHCP client)"
    info_print "3) wpa_supplicant: Utility with support for WEP and WPA/WPA2 (WiFi-only, DHCPCD will be automatically installed)"
    info_print "4) dhcpcd: Basic DHCP client (Ethernet connections or VMs)"
    info_print "5) I will do this on my own (only advanced users)"
    input_print "Please select the number of the corresponding networking utility (e.g. 1): "
    read -r network_choice
    if ! ((1 <= network_choice <= 5)); then
        error_print "You did not enter a valid selection, please try again."
        return 1
    fi
    return 0
}

# Installing the chosen networking method to the system (function).
network_installer () {
    case $network_choice in
        1 ) info_print "Installing and enabling NetworkManager."          
            pacstrap /mnt networkmanager >/dev/null
            systemctl enable NetworkManager --root=/mnt &>/dev/null
            ;;
        2 ) info_print "Installing and enabling IWD."
            pacstrap /mnt iwd >/dev/null
            systemctl enable iwd --root=/mnt &>/dev/null
            ;;
        3 ) info_print "Installing and enabling wpa_supplicant and dhcpcd."
            pacstrap /mnt wpa_supplicant dhcpcd >/dev/null
            systemctl enable wpa_supplicant --root=/mnt &>/dev/null
            systemctl enable dhcpcd --root=/mnt &>/dev/null
            ;;
        4 ) info_print "Installing dhcpcd."
            pacstrap /mnt dhcpcd >/dev/null
            systemctl enable dhcpcd --root=/mnt &>/dev/null
    esac
}

lukspass_selector () {
    input_print "Please enter a password for the LUKS container (you're not going to see the password): "
    read -r -s password
    if [[ -z "$password" ]]; then
        echo
        error_print "You need to enter a password for the LUKS Container, please try again."
        return 1
    fi
    echo
    input_print "Please enter the password for the LUKS container again (you're not going to see the password): "
    read -r -s password2
    echo
    if [[ "$password" != "$password2" ]]; then
        error_print "Passwords don't match, please try again."
        return 1
    fi
    return 0
}

# Ask if the user wants to reuse the LUKS password
reuse_password() {
    input_print "Do you want to use the same password for root/user? (YES/no): "

    # Disable cursor blinking during input
    old_stty_cfg=$(stty -g)
    stty -echo -icanon
    choice=$(head -n1 </dev/tty)
    stty "$old_stty_cfg"

    echo  # Manually add a newline to separate input from next prompt

    choice=${choice:-yes}  # Default to "yes" if empty

    case "$choice" in
        y|Y|yes|YES)
            userpass="$password"
            rootpass="$password"
            ;;
        *)
            info_print "No reusable passwords."
            ;;
    esac
}

# Setting up a password for the user account (function).
userpass_selector () {
    input_print "Please enter name for a user account (enter empty to not create one): "
    read -r username
    echo  # Ensure proper formatting

    if [[ -z "$username" ]]; then
        return 0
    fi

    if [[ -n "$userpass" ]]; then
        input_print "Using previously set password for $username."
        echo
        return 0
    fi

    input_print "Please enter a password for $username (you're not going to see the password): "
    read -r -s userpass
    echo  
    if [[ -z "$userpass" ]]; then
        error_print "You need to enter a password for $username, please try again."
        return 1
    fi

    input_print "Please enter the password again (you're not going to see it): " 
    read -r -s userpass2
    echo
    if [[ "$userpass" != "$userpass2" ]]; then
        error_print "Passwords don't match, please try again."
        return 1
    fi
    return 0
}

# Setting up a password for the root account (function).
rootpass_selector () {
    if [[ -n "$rootpass" ]]; then
        input_print "Using previously set root password."
        echo
        return 0
    fi

    input_print "Please enter a password for the root user (you're not going to see it): "
    read -r -s rootpass
    echo  
    if [[ -z "$rootpass" ]]; then
        error_print "You need to enter a password for the root user, please try again."
        return 1
    fi

    input_print "Please enter the password again (you're not going to see it): " 
    read -r -s rootpass2
    echo
    if [[ "$rootpass" != "$rootpass2" ]]; then
        error_print "Passwords don't match, please try again."
        return 1
    fi
    return 0
}

# Microcode detector (function).
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

# User enters a hostname (function).
hostname_selector () {
    input_print "Please enter the hostname: "
    read -r hostname
    if [[ -z "$hostname" ]]; then
        error_print "You need to enter a hostname in order to continue."
        return 1
    fi
    return 0
}

# User chooses the locale (function).
locale_selector () {
    input_print "Please insert the locale you use (format: xx_XX. Enter empty to use en_US, or \"/\" to search locales): " locale
    read -r locale
    case "$locale" in
        '') locale="en_US.UTF-8"
            info_print "$locale will be the default locale."
            return 0;;
        '/') sed -E '/^# +|^#$/d;s/^#| *$//g;s/ .*/ (Charset:&)/' /etc/locale.gen | less -M
                clear
                return 1;;
        *)  if ! grep -q "^#\?$(sed 's/[].*[]/\\&/g' <<< "$locale") " /etc/locale.gen; then
                error_print "The specified locale doesn't exist or isn't supported."
                return 1
            fi
            return 0
    esac
}

# User chooses the console keyboard layout (function).
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

# Install the default editor (function).
install_editor () {
    info_print "Select a default text editor to install:"
    info_print "1) Nano (simple editor)"
    info_print "2) Neovim (modern alternative to Vim)"
    info_print "3) Vim (classic editor)"
    info_print "4) Micro (user-friendly terminal-based editor)"
    input_print "Please select the number of the corresponding editor (e.g. 1): "
    read -r editor_choice

    case $editor_choice in
        1 ) 
            info_print "Installing Nano and setting it as default editor in /etc/environment."
            pacstrap /mnt nano &>/dev/null
            echo "EDITOR=nano" >> /mnt/etc/environment
            echo "VISUAL=nano" >> /mnt/etc/environment
            ;;
        2 )
            info_print "Installing Neovim and setting it as default editor in /etc/environment."
            pacstrap /mnt neovim &>/dev/null
            echo "EDITOR=nvim" >> /mnt/etc/environment
            echo "VISUAL=nvim" >> /mnt/etc/environment
            ;;
        3 )
            info_print "Installing Vim and setting it as default editor in /etc/environment."
            pacstrap /mnt vim &>/dev/null
            echo "EDITOR=vim" >> /mnt/etc/environment
            echo "VISUAL=vim" >> /mnt/etc/environment
            ;;
        4 )
            info_print "Installing Micro and setting it as default editor in /etc/environment."
            pacstrap /mnt micro &>/dev/null
            echo "EDITOR=micro" >> /mnt/etc/environment
            echo "VISUAL=micro" >> /mnt/etc/environment
            ;;
        * )
            error_print "Invalid selection, using Nano as default editor."
            pacstrap /mnt nano &>/dev/null
            echo "EDITOR=nano" >> /mnt/etc/environment
            echo "VISUAL=nano" >> /mnt/etc/environment
            ;;
    esac
}

# Install yay (AUR helper)
install_yay () {
    info_print "Installing yay, an AUR helper."

    # Install base development tools and git with no output
    pacstrap /mnt base-devel &>/dev/null

    # Create a temporary user for yay installation with no output
    arch-chroot /mnt useradd -m -s /bin/bash aurbuild &>/dev/null

    # Set up sudo for the temporary user with no output
    echo "aurbuild ALL=(ALL) NOPASSWD: ALL" > /mnt/etc/sudoers.d/aurbuild &>/dev/null

    # Install yay as the non-root user with no output
    arch-chroot /mnt su - aurbuild -c 'git clone https://aur.archlinux.org/yay.git /tmp/yay && cd /tmp/yay && makepkg -si --noconfirm' &>/dev/null

    # Clean up with no output
    arch-chroot /mnt userdel -r aurbuild &>/dev/null
    rm -rf /mnt/tmp/yay &>/dev/null
    rm -rf /mnt/etc/sudoers.d/aurbuild &>/dev/null
}
# Welcome screen.
echo -ne "${BOLD}${BYELLOW}
===========================================================
    _             _     _     _            __  __     
   / \   _ __ ___| |__ | |   (_)_ __  _   _\ \/ / _   
  / _ \ | '__/ __| '_ \| |   | | '_ \| | | |\  /_| |_ 
 / ___ \| | | (__| | | | |___| | | | | |_| |/  \_   _|
/_/   \_\_|  \___|_| |_|_____|_|_| |_|\__,_/_/\_\|_|

===========================================================
${RESET}"
info_print "Welcome to ArchLinux Installer+ , a script made in order to simplify the process of installing Arch Linux."

# Setting up keyboard layout.
until keyboard_selector; do : ; done

# Choosing the target for the installation.
info_print "Available disks for the installation:"
PS3="Please select the number of the corresponding disk (e.g. 1): "
select ENTRY in $(lsblk -dpnoNAME|grep -P "/dev/sd|nvme|vd");
do
    DISK="$ENTRY"
    info_print "Arch Linux will be installed on the following disk: $DISK"
    break
done

# Setting up LUKS password.
until lukspass_selector; do : ; done

# Reuse password
until reuse_password; do : ; done

# Setting up the kernel.
until kernel_selector; do : ; done

# User choses the network.
until network_selector; do : ; done

# User choses the locale.
until locale_selector; do : ; done

# User choses the hostname.
until hostname_selector; do : ; done

# User sets up the user/root passwords.
until userpass_selector; do : ; done
until rootpass_selector; do : ; done

# Warn user about deletion of old partition scheme.
input_print "This will delete the current partition table on $DISK once installation starts. Do you agree [y/N]?: "
read -r disk_response
if ! [[ "${disk_response,,}" =~ ^(yes|y)$ ]]; then
    error_print "Quitting."
    exit
fi
info_print "Wiping $DISK."
wipefs -af "$DISK" &>/dev/null
sgdisk -Zo "$DISK" &>/dev/null

# Ask for root size
input_print "How much space should root (/) use (e.g. 100G): "
read -r root_size
if [[ -z "$root_size" ]]; then
    error_print "You must enter a size for root."; exit 1
fi

# Creating a new partition scheme.
info_print "Creating the partitions on $DISK."
parted -s "$DISK" \
    mklabel gpt \
    mkpart ESP fat32 1MiB 1025MiB \
    set 1 esp on \
    mkpart CRYPTROOT 1025MiB "$root_size" \
    mkpart CRYPTHOME "$root_size" 100%
    
ESP="/dev/disk/by-partlabel/ESP"
CRYPTROOT="/dev/disk/by-partlabel/CRYPTROOT"
CRYPTHOME="/dev/disk/by-partlabel/CRYPTHOME"

# Informing the Kernel of the changes.
info_print "Informing the Kernel about the disk changes."
partprobe "$DISK"

# Formatting the ESP as FAT32.
info_print "Formatting the EFI Partition as FAT32."
mkfs.fat -F 32 "$ESP" &>/dev/null

# Creating a LUKS Container for the root partition.
info_print "Creating LUKS Container for the root partition."
echo -n "$password" | cryptsetup luksFormat "$CRYPTROOT" -d - &>/dev/null
echo -n "$password" | cryptsetup open "$CRYPTROOT" cryptroot -d - 

# Creating LUKS Container for home partition.
info_print "Creating LUKS Container for the home partition."
echo -n "$password" | cryptsetup luksFormat "$CRYPTHOME" -d - &>/dev/null
echo -n "$password" | cryptsetup open "$CRYPTHOME" crypthome -d -

# Formatting the cryptroot Container as BTRFS.
info_print "Formatting the cryptroot LUKS container as BTRFS."
mkfs.btrfs /dev/mapper/cryptroot &>/dev/null

# Formatting the crypthome Container as BTRFS.
info_print "Formatting the crypthome LUKS container as BTRFS."
mkfs.btrfs /dev/mapper/crypthome &>/dev/null

# Opret Btrfs subvolumes på luks-root (cryptroot)
info_print "Creating BTRFS subvolumes on root partition."
mount /dev/mapper/cryptroot /mnt
for subvol in @ @snapshots @var_pkgs @var_log @srv @var_lib_portables @var_lib_machines; do
    btrfs subvolume create /mnt/$subvol
done
umount /mnt

# Opret Btrfs subvolume på luks-home (crypthome)
info_print "Creating BTRFS subvolume on home partition."
mount /dev/mapper/crypthome /mnt
btrfs subvolume create /mnt/@home
umount /mnt

# Mounting the newly created subvolumes.
info_print "Mounting the newly created subvolumes."
mountopts="ssd,noatime,compress-force=zstd:3,discard=async"

# Mount root-subvolume
mount -o "$mountopts",subvol=@ /dev/mapper/cryptroot /mnt

# Opret alle nødvendige mount points og disable CoW
nocow_dirs=(
  /mnt/var/log
  /mnt/var/cache/pacman/pkg
  /mnt/var/lib/libvirt
  /mnt/var/lib/machines
  /mnt/var/lib/portables
)

for dir in "${nocow_dirs[@]}"; do
    mkdir -p "$dir"
    chattr +C "$dir" 2>/dev/null || true
}

mkdir -p /mnt/{efi,home,root,srv,.snapshots,boot}

# Definer subvolumes til mounting (undtagen @home som er på separat luks)
subvols=(snapshots var_pkgs var_log srv root var_lib_portables var_lib_machines)
for subvol in "${subvols[@]}"; do
    mount -o "$mountopts",subvol=@"$subvol" /dev/mapper/cryptroot "/mnt/${subvol//_//}"
done

# Mount /home separat
mount -o "$mountopts",subvol=@home /dev/mapper/crypthome /mnt/home

# Ekstra mounts og rettigheder
chmod 750 /mnt/root
mount "$ESP" /mnt/efi/

# Checking the microcode to install.
microcode_detector

# Pacstrap (setting up a base system onto the new root).
info_print "Installing the base system (it may take a while)."
pacstrap -K /mnt base "$kernel" "$microcode" linux-firmware "$kernel"-headers btrfs-progs grub grub-btrfs rsync efibootmgr snapper reflector snap-pac zram-generator sudo inotify-tools zsh unzip fzf zoxide colordiff curl btop mc git systemd ukify sbctl &>/dev/null

#Setting Default Shell to zsh
info_print "Setting default shell to zsh"
sed -i 's|^SHELL=/usr/bin/bash|SHELL=/usr/bin/zsh|' /mnt/etc/default/useradd
curl -sSLo /mnt/etc/skel/.zshrc https://raw.githubusercontent.com/NeonGOD78/ArchLinuxPlus/refs/heads/main/configs/etc/skel/.zshrc
curl -sSLo /mnt/etc/zsh/zshrc https://raw.githubusercontent.com/NeonGOD78/ArchLinuxPlus/refs/heads/main/configs/etc/zsh/zshrc
mkdir -p /mnt/etc/skel/.local/bin 2>/dev/null && curl -sSLo /mnt/etc/skel/.local/bin/setup-default-zsh https://raw.githubusercontent.com/NeonGOD78/ArchLinuxPlus/refs/heads/main/configs/etc/skel/.local/bin/setup-default-zsh && chmod +x /mnt/etc/skel/.local/bin/setup-default-zsh &>/dev/null
mkdir -p /mnt/etc/skel/.cache/oh-my-posh/themes 2>/dev/null && curl -sSLo /mnt/etc/skel/.cache/oh-my-posh/themes/zen.toml https://raw.githubusercontent.com/NeonGOD78/ArchLinuxPlus/refs/heads/main/configs/etc/skel/.cache/oh-my-posh/themes/zen.toml
curl -sSLo /mnt/etc/skel/.bashrc https://raw.githubusercontent.com/NeonGOD78/ArchLinuxPlus/refs/heads/main/configs/etc/skel/.bashrc
curl -sSLo /mnt/etc/skel/.aliases https://raw.githubusercontent.com/NeonGOD78/ArchLinuxPlus/refs/heads/main/configs/etc/skel/.aliases

# Setting up the hostname.
echo "$hostname" > /mnt/etc/hostname

# Generating /etc/fstab.
info_print "Generating a new fstab."
genfstab -U /mnt >> /mnt/etc/fstab

# Configure selected locale and console keymap
sed -i "/^#$locale/s/^#//" /mnt/etc/locale.gen
echo "LANG=$locale" > /mnt/etc/locale.conf
echo "KEYMAP=$kblayout" > /mnt/etc/vconsole.conf

# Setting hosts file.
info_print "Setting hosts file."
cat > /mnt/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain   $hostname
EOF

# Virtualization check.
virt_check

# Setting up the network.
network_installer

# Install Default Editor
install_editor

# Installing Yay (AUR helper).
install_yay

# Configuring /etc/mkinitcpio.conf with correct hooks
info_print "Configuring /etc/mkinitcpio.conf."
sed -i 's/^HOOKS=.*/HOOKS=(systemd autodetect keyboard sd-vconsole modconf block sd-encrypt filesystems grub-btrfs-overlayfs)/' /mnt/etc/mkinitcpio.conf

# Setting up LUKS2 encryption in GRUB
info_print "Setting up GRUB config."

UUID_ROOT=$(blkid -s UUID -o value "$CRYPTROOT")
UUID_HOME=$(blkid -s UUID -o value "$CRYPTHOME")

ROOT_MAPPER="/dev/mapper/cryptroot"

# Erstat hele linjen med luks parametre og root-mountpoint
sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet rd.luks.name=$UUID_ROOT=cryptroot rd.luks.name=$UUID_HOME=crypthome root=$ROOT_MAPPER rootflags=subvol=@\"|" /mnt/etc/default/grub

# Configuring the system.
info_print "Configuring the system (timezone, system clock, initramfs, Snapper, GRUB)."
arch-chroot /mnt /bin/bash -e <<EOF

    # Setting up timezone.
    ln -sf /usr/share/zoneinfo/$(curl -s http://ip-api.com/line?fields=timezone) /etc/localtime &>/dev/null

    # Setting up clock.
    hwclock --systohc

    # Generating locales.
    locale-gen &>/dev/null

    # Generating a new initramfs.
    mkinitcpio -P &>/dev/null

    # Snapper configuration.
    umount /.snapshots
    rm -r /.snapshots
    snapper --no-dbus -c root create-config /
    btrfs subvolume delete /.snapshots &>/dev/null
    mkdir /.snapshots
    mount -a &>/dev/null
    chmod 750 /.snapshots

    # Installing GRUB.
    grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB &>/dev/null

    # Enable Automatic Grub snapper menu
    sed -i '/#GRUB_BTRFS_GRUB_DIRNAME=/s|#GRUB_BTRFS_GRUB_DIRNAME=.*|GRUB_BTRFS_GRUB_DIRNAME="/boot/grub"|' /etc/default/grub-btrfs/config

    # Enable custom grub-btrfs template for UKI snapshots
    sed -i 's|^#USE_CUSTOM_CONFIG=.*|USE_CUSTOM_CONFIG="true"|' /etc/default/grub-btrfs/config

    UUID_ROOT=\$(blkid -s UUID -o value /dev/disk/by-partlabel/CRYPTROOT)

    cat > /etc/grub.d/42_grub-btrfs-custom <<GRUBCUSTOM
#!/bin/bash
. /usr/share/grub/grub-mkconfig_lib

snapshot="\$1"
title="Arch Linux (UKI) Snapshot: \${snapshot##*/}"

cat <<GRUB_ENTRY
menuentry '\${title}' {
    search --no-floppy --file --set=root /EFI/Linux/arch.efi
    linuxefi /EFI/Linux/arch.efi
    options rootflags=subvol=\${snapshot#/mnt} rd.luks.name=\$UUID_ROOT=cryptroot root=/dev/mapper/cryptroot quiet loglevel=3
}
GRUB_ENTRY
GRUBCUSTOM

    chmod +x /etc/grub.d/42_grub-btrfs-custom

# Fallback GRUB entry
info_print "Adding fallback GRUB menuentry."
cat > /mnt/etc/grub.d/41_fallback <<EOF
#!/bin/bash
cat <<GRUBENTRY
menuentry "Arch Linux (Fallback Kernel)" {
    search --no-floppy --file --set=root /boot/vmlinuz-linux
    linux /boot/vmlinuz-linux root=/dev/mapper/cryptroot rd.luks.name=$(blkid -s UUID -o value /dev/disk/by-partlabel/CRYPTROOT)=cryptroot rootflags=subvol=@ quiet loglevel=3
    initrd /boot/initramfs-linux.img
}
GRUBENTRY
EOF

chmod +x /mnt/etc/grub.d/41_fallback

    # Build UKI image and log output
    ukify build \
      --linux /boot/vmlinuz-linux \
      --initrd /boot/initramfs-linux.img \
      --cmdline "rd.luks.name=$UUID_ROOT=cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw quiet loglevel=3" \
      --output /efi/EFI/Linux/arch.efi >> /var/log/ukify.log 2>&1 || echo "Initial UKI build failed. See /var/log/ukify.log"

    # Build fallback UKI image and log output
    ukify build \
      --linux /boot/vmlinuz-linux \
      --initrd /boot/initramfs-linux-fallback.img \
      --cmdline "rd.luks.name=$UUID_ROOT=cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw quiet loglevel=3" \
      --output /efi/EFI/Linux/arch-fallback.efi >> /var/log/ukify.log 2>&1 || echo "Fallback UKI build failed. See /var/log/ukify.log"

    # Creating grub config file.
    grub-mkconfig -o /boot/grub/grub.cfg &>/dev/null

EOF

# Setting root password.
info_print "Setting root password."
echo "root:$rootpass" | arch-chroot /mnt chpasswd
arch-chroot /mnt usermod -s /usr/bin/zsh "root"

# Setting user password.
if [[ -n "$username" ]]; then
    echo "%wheel ALL=(ALL:ALL) ALL" > /mnt/etc/sudoers.d/wheel
    info_print "Adding the user $username to the system with root privilege."
    arch-chroot /mnt useradd -m -G wheel -s /usr/bin/zsh "$username"
    info_print "Setting user password for $username."
    echo "$username:$userpass" | arch-chroot /mnt chpasswd
fi

# Install zinit
info_print "Adding zinit to the system."
mkdir -p /mnt/root/.local/share/zinit &>/dev/null
arch-chroot /mnt git clone https://github.com/zdharma-continuum/zinit.git /root/.local/share/zinit/zinit.git &>/dev/null
if [[ -n "$username" ]]; then
    mkdir -p /mnt/home/"$username"/.local/share/zinit &>/dev/null
    arch-chroot /mnt git clone https://github.com/zdharma-continuum/zinit.git /home/"$username"/.local/share/zinit/zinit.git &>/dev/null
    arch-chroot /mnt chown -R $username:$username /home/$username &>/dev/null
fi

# UKI Backup folder
info_print "Creating EFI backup folder at /.efibackup"
mkdir -p /mnt/.efibackup

# UKI rebuild hook with integrated backup
info_print "Creating UKI rebuild hook and backup script."
mkdir -p /mnt/etc/pacman.d/hooks
cat > /mnt/etc/pacman.d/hooks/95-ukify.hook <<EOF
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

cat > /mnt/etc/systemd/system/update-uki.timer <<EOF
[Unit]
Description=Run update-uki daily

[Timer]
OnBootSec=5min
OnUnitActiveSec=1d

[Install]
WantedBy=timers.target
EOF


mkdir -p /mnt/usr/local/bin
cat > /mnt/usr/local/bin/update-uki <<'EOF'
#!/bin/bash
set -e

UKI_OUTPUT="/efi/EFI/Linux/arch.efi"
KERNEL="/boot/vmlinuz-linux"
INITRD="/boot/initramfs-linux.img"
BACKUP_DIR="/.efibackup"

UUID_ROOT=$(blkid -s UUID -o value /dev/disk/by-partlabel/CRYPTROOT)

CMDLINE="rd.luks.name=${UUID_ROOT}=cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ quiet loglevel=3"

# Regenerate UKI
ukify build \
  --linux "$KERNEL" \
  --initrd "$INITRD" \
  --cmdline "$CMDLINE" \
  --output "$UKI_OUTPUT"

# Backup current UKI
mkdir -p "$BACKUP_DIR"
cp "$UKI_OUTPUT" "$BACKUP_DIR/arch.efi.bak"
EOF

chmod +x /mnt/usr/local/bin/update-uki

# UKI regeneration hook with logging
info_print "Creating pacman hook for UKI regeneration with logging."
mkdir -p /mnt/etc/pacman.d/hooks

cat > /mnt/etc/pacman.d/hooks/90-ukify.hook <<EOF
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
Exec = /bin/bash -c '/usr/bin/ukify build \
  --linux /boot/vmlinuz-linux \
  --initrd /boot/initramfs-linux.img \
  --cmdline "rd.luks.name=\$(blkid -s UUID -o value /dev/disk/by-partlabel/CRYPTROOT)=cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw quiet loglevel=3" \
  --output /efi/EFI/Linux/arch.efi >> /var/log/ukify.log 2>&1 || echo "UKI build failed. Check /var/log/ukify.log"'
EOF

# ZRAM configuration.
info_print "Configuring ZRAM."
cat > /mnt/etc/systemd/zram-generator.conf <<EOF
[zram0]
zram-size = min(ram, 8192)
compression-algorithm = zstd
EOF

# Pacman eye-candy features.
info_print "Enabling colours, animations, and parallel downloads for pacman."
sed -Ei 's/^#(Color)$/\1\nILoveCandy/;s/^#(ParallelDownloads).*/\1 = 10/' /mnt/etc/pacman.conf

# Enabling various services.
info_print "Enabling Reflector, automatic snapshots, BTRFS scrubbing, Grub Snapper menu and systemd-oomd."
services=(reflector.timer update-uki.timer snapper-timeline.timer snapper-cleanup.timer btrfs-scrub@-.timer btrfs-scrub@home.timer btrfs-scrub@var-log.timer btrfs-scrub@\\x2esnapshots.timer grub-btrfsd.service systemd-oomd)
for service in "${services[@]}"; do
    systemctl enable "$service" --root=/mnt &>/dev/null
done

# Finishing up.
info_print "Done, you may now wish to reboot (further changes can be done by chrooting into /mnt)."
info_print "Verifying LUKS devices before reboot..."
ls /dev/mapper | grep -E 'cryptroot|crypthome' || error_print "Warning: LUKS devices not active"
exit
