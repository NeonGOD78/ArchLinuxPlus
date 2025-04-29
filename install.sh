#!/usr/bin/env bash

# ==================== Colors ====================

RESET='\e[0m'
BOLD='\e[1m'
DARKGRAY='\e[90m'
LIGHTGRAY='\e[37m'
RED='\e[91m'
GREEN='\e[92m'
YELLOW='\e[93m'
CYAN='\e[96m'

# ==================== Global Variables ====================

SCRIPT_VERSION="v1.0"
LOGFILE="/var/log/archinstall.log"
DEBUG=false

# ==================== Basic Helpers ====================

# Safe reading function
read_from_tty() {
  IFS= read "$@"
}

# Logging
log_msg() {
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] $1" >> "$LOGFILE"
}

log_start() {
  echo "========== ArchLinuxPlus Install Log ==========" > "$LOGFILE"
  echo "Started on: $(date)" >> "$LOGFILE"
  echo "===============================================" >> "$LOGFILE"
  echo "" >> "$LOGFILE"
}

move_logfile_to_mnt() {
  if [[ -f "$LOGFILE" ]]; then
    mkdir -p /mnt/var/log
    mv "$LOGFILE" /mnt/var/log/
    LOGFILE="/mnt/var/log/archinstall.log"
    startup_ok "Logfile moved to $LOGFILE."
  else
    startup_warn "Original logfile not found. Skipping move."
  fi
}

# Printing functions

draw_line() {
  local char="${1:--}"
  local width
  width=$(tput cols 2>/dev/null || echo 80)

  printf "${DARKGRAY}"
  printf "%${width}s" "" | tr " " "$char"
  printf "${RESET}\n"
}

# ==================== Startup Print Functions ====================

startup_print() {
  printf "${DARKGRAY}[      ]${RESET} ${LIGHTGRAY}%s${RESET}" "$1"
}

startup_ok() {
  printf "\r${DARKGRAY}[${GREEN} OK ${DARKGRAY}]${RESET} ${LIGHTGRAY}%s${RESET}\n" "$1"
  log_msg "[ OK ] $1"
}

startup_fail() {
  printf "\r${DARKGRAY}[${RED}FAIL${DARKGRAY}]${RESET} ${LIGHTGRAY}%s${RESET}\n" "$1"
  log_msg "[FAIL] $1"
}

startup_warn() {
  printf "\r${DARKGRAY}[${YELLOW}WARN${DARKGRAY}]${RESET} ${LIGHTGRAY}%s${RESET}\n" "$1"
  log_msg "[WARN] $1"
}

input_print() {
  printf "${DARKGRAY}[ ${YELLOW}¿? ${DARKGRAY}]${RESET} ${LIGHTGRAY}%s: ${RESET}" "$1"
}

info_print() {
  printf "\r${DARKGRAY}[${CYAN}INFO${DARKGRAY}]${RESET} ${LIGHTGRAY}%s${RESET}\n" "$1"
  log_msg "[INFO] $1"
}

warning_print() {
  printf "\r${DARKGRAY}[ ${YELLOW}!! ${DARKGRAY}]${RESET} ${LIGHTGRAY}%s${RESET}\n" "$1"
  log_msg "[WARN] $1"
}

error_print() {
  printf "\r${DARKGRAY}[ ${RED}!! ${DARKGRAY}]${RESET} ${LIGHTGRAY}%s${RESET}\n" "$1"
  log_msg "[ERR ] $1"
}

section_header() {
  local title="$1"
  local char="${2:--}"
  local color="${3:-$DARKGRAY}"
  local width padding

  width=$(tput cols 2>/dev/null || echo 80)

  printf "${color}"
  printf "%${width}s" "" | tr " " "$char"
  printf "${RESET}\n"

  padding=$(( (width - ${#title}) / 2 ))
  printf "${color}%*s%s\n" "$padding" "" "$title"
  
  printf "%${width}s" "" | tr " " "$char"
  printf "${RESET}\n"
}

# ==================== Banner ====================

banner_archlinuxplus() {
  clear
  draw_line "-"
  
  printf "${CYAN}"
  printf "    _             _     _     _            __  __\n"
  printf "   / \\   _ __ ___| |__ | |   (_)_ __  _   _\\ \\/ / _\n"
  printf "  / _ \\ | '__/ __| '_ \\| |   | | '_ \\| | | |\\  /_| |_\n"
  printf " / ___ \\| | | (__| | | | |___| | | | | |_| |/  \\_   _|\n"
  printf "/_/   \\_\\_|  \\___|_| |_|_____|_|_| |_|\\__,_/_/\\_\\|_|\n"
  printf "${RESET}\n"

  draw_line "-"
  
  printf "${LIGHTGRAY}ArchLinux+ an Advanced Arch Installer (${SCRIPT_VERSION})${RESET}\n"
  printf "${DARKGRAY}github.com/NeonGOD78/ArchLinuxPlus${RESET}\n\n"
}

# ==================== Keymap Setup ====================

setup_keymap() {
  section_header "Keyboard Layout Setup"

  local keymap search_choice search_term available_keymaps

  input_print "Press [S] to search keymaps or [Enter] to input manually"
  read_from_tty -r search_choice

  if [[ "${search_choice,,}" == "s" ]]; then
    # Bruger ønsker at søge
    available_keymaps=$(localectl list-keymaps 2>/dev/null)

    if [[ -z "$available_keymaps" ]]; then
      startup_warn "Could not fetch keymap list. Falling back to manual input."
    else
      input_print "Enter search term for keymaps (leave empty to show all)"
      read_from_tty -r search_term

      if [[ -n "$search_term" ]]; then
        printf "${LIGHTGRAY}Available keymaps matching '${search_term}':\n${RESET}"
        echo "$available_keymaps" | grep -i --color=never "$search_term" || startup_warn "No matching keymaps found."
      else
        printf "${LIGHTGRAY}Available keymaps:\n${RESET}"
        echo "$available_keymaps"
      fi
    fi

    echo
  fi

  while true; do
    input_print "Enter your desired keymap [default: dk]"
    read_from_tty -r keymap

    if [[ -z "$keymap" ]]; then
      keymap="dk"
      info_print "No keymap entered. Defaulting to 'dk'."
    fi

    if loadkeys "$keymap" 2>/dev/null; then
      KEYMAP="$keymap"
      startup_ok "Keymap '$KEYMAP' loaded successfully."
      break
    else
      startup_fail "Failed to load keymap '$keymap'. Please try again."
      echo
    fi
  done
}

# ================== Keymap and Locale Setup ==================

setup_keymap_and_locale() {
  section_header "Keyboard Layout and Locale Setup"

  # Keymap Selection
  while true; do
    input_print "Enter desired keymap (type part to search, default: dk)"
    read_from_tty -r keymap_input

    if [[ -z "$keymap_input" ]]; then
      KEYMAP="dk"
      info_print "Defaulting keymap to 'dk'."
      break
    fi

    mapfile -t keymaps < <(localectl list-keymaps | grep -i "$keymap_input")

    if (( ${#keymaps[@]} == 0 )); then
      warning_print "No matching keymaps found. Please try again."
    elif (( ${#keymaps[@]} == 1 )); then
      KEYMAP="${keymaps[0]}"
      startup_ok "Keymap set to '$KEYMAP'."
      break
    else
      info_print "Multiple matches found:"
      for i in "${!keymaps[@]}"; do
        echo "  $((i+1))) ${keymaps[$i]}"
      done

      input_print "Enter number to select keymap"
      read_from_tty -r km_select

      if [[ "$km_select" =~ ^[0-9]+$ ]] && (( km_select >= 1 && km_select <= ${#keymaps[@]} )); then
        KEYMAP="${keymaps[$((km_select-1))]}"
        startup_ok "Keymap set to '$KEYMAP'."
        break
      else
        warning_print "Invalid selection. Try again."
      fi
    fi
  done

  # Load keymap immediately
  loadkeys "$KEYMAP" || warning_print "Failed to load keymap '$KEYMAP'. Continuing anyway."

  # Locale Selection
  while true; do
    input_print "Enter desired system locale (type part to search, default: en_DK.UTF-8)"
    read_from_tty -r locale_input

    if [[ -z "$locale_input" ]]; then
      LOCALE="en_DK.UTF-8"
      info_print "Defaulting locale to 'en_DK.UTF-8'."
      break
    fi

    mapfile -t locales < <(awk '/UTF-8/ {print $1}' /etc/locale.gen | grep -i "$locale_input")

    if (( ${#locales[@]} == 0 )); then
      warning_print "No matching locales found. Please try again."
    elif (( ${#locales[@]} == 1 )); then
      LOCALE="${locales[0]}"
      startup_ok "Locale set to '$LOCALE'."
      break
    else
      info_print "Multiple matches found:"
      for i in "${!locales[@]}"; do
        echo "  $((i+1))) ${locales[$i]}"
      done

      input_print "Enter number to select locale"
      read_from_tty -r loc_select

      if [[ "$loc_select" =~ ^[0-9]+$ ]] && (( loc_select >= 1 && loc_select <= ${#locales[@]} )); then
        LOCALE="${locales[$((loc_select-1))]}"
        startup_ok "Locale set to '$LOCALE'."
        break
      else
        warning_print "Invalid selection. Try again."
      fi
    fi
  done
}

# ================== Save Keymap Config ==================

save_keymap_config() {
  section_header "Saving Keyboard Layout"

  if [[ -n "$KEYMAP" ]]; then
    echo "KEYMAP=$KEYMAP" > /mnt/etc/vconsole.conf
    startup_ok "Saved keymap '$KEYMAP' to /mnt/etc/vconsole.conf."
  else
    startup_warn "No keymap to save. Skipping vconsole.conf setup."
  fi
}

# ================== Save Locale Config ==================

save_locale_config() {
  section_header "Saving Locale Setup"

  if [[ -n "$LOCALE" ]]; then
    echo "LANG=$LOCALE" > /mnt/etc/locale.conf
    startup_ok "Saved locale '$LOCALE' to /mnt/etc/locale.conf."

    if grep -q "^#${LOCALE}" /mnt/etc/locale.gen; then
      sed -i "s/^#${LOCALE}/${LOCALE}/" /mnt/etc/locale.gen
      startup_ok "Uncommented $LOCALE in /mnt/etc/locale.gen."
    else
      startup_warn "$LOCALE not found in /mnt/etc/locale.gen. Skipping sed."
    fi

    arch-chroot /mnt locale-gen >> "$LOGFILE" 2>&1
    if [[ $? -eq 0 ]]; then
      startup_ok "Locale generated successfully in chroot."
    else
      startup_error "Failed to generate locale inside chroot."
      exit 1
    fi
  else
    startup_warn "No locale to save. Skipping locale.conf and generation."
  fi
}

# ==================== Disk Selection ====================

select_disk() {
  section_header "Disk Selection"

  while true; do
    # Find alle fysiske diske (ingen loop, rom, boot)
    mapfile -t disks < <(lsblk -dpno NAME,SIZE,MODEL | grep -Ev "boot|rpmb|loop")

    if [[ "${#disks[@]}" -eq 0 ]]; then
      error_print "No suitable block devices found. Exiting."
      exit 1
    fi

    echo
    info_print "Detected available disks:"
    for i in "${!disks[@]}"; do
      printf "  %d) %s\n" "$((i+1))" "${disks[$i]}"
    done
    echo

    input_print "Select the number of the disk to install Arch on (or press Enter to cancel)"
    read_from_tty -r disk_index

    if [[ -z "$disk_index" ]]; then
      error_print "Disk selection cancelled by user. Exiting."
      exit 1
    fi

    if ! [[ "$disk_index" =~ ^[0-9]+$ ]] || (( disk_index < 1 || disk_index > ${#disks[@]} )); then
      warning_print "Invalid selection. Please try again."
      continue
    fi

    DISK=$(awk '{print $1}' <<< "${disks[$((disk_index-1))]}")

    echo
    startup_ok "You selected: $DISK"
    echo

    info_print "Partition layout for $DISK:"
    echo
    lsblk -p -e7 -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINT,LABEL,UUID "$DISK"
    echo

    error_print "!! ALL DATA ON $DISK WILL BE IRREVERSIBLY LOST !!"
    echo
    input_print "Are you sure you want to proceed with $DISK? [y/N]"
    read_from_tty -r confirm

    if [[ "${confirm,,}" == "y" ]]; then
      startup_ok "Disk $DISK confirmed and ready for partitioning."
      break
    else
      warning_print "Disk not confirmed. Returning to selection."
      echo
    fi
  done
}

# ================== Partition Layout Choice ==================

partition_layout_choice() {
  section_header "Partition Layout Setup"

  # Ask if user wants secure wipe
  input_print "Do you want to perform a full secure wipe of the disk? (very slow) [y/N]"
  read_from_tty -r wipe_choice
  wipe_choice="${wipe_choice,,}"

  if [[ "$wipe_choice" =~ ^(y|yes)$ ]]; then
    SECURE_WIPE=true
    warning_print "Secure wipe selected. This can take a LONG time!"
  else
    SECURE_WIPE=false
    info_print "Normal wipe selected (quick erase of partition table only)."
  fi

  echo

  # Ask about separate /home
  input_print "Do you want to create a separate encrypted /home partition? [Y/n]"
  read_from_tty -r separate_home_choice
  separate_home_choice="${separate_home_choice,,}"  # to lowercase

  if [[ "$separate_home_choice" =~ ^(n|no)$ ]]; then
    SEPARATE_HOME=false
    info_print "Will use single encrypted root partition (no separate /home)."
  else
    SEPARATE_HOME=true
    info_print "Will create a separate encrypted /home partition."

    # Find total disk size in GB (assumes DISK variable already set)
    local total_size_gb
    total_size_gb=$(lsblk -dnbo SIZE "$DISK" | awk '{print int($1/1024/1024/1024)}')
    local default_root_size=$(( total_size_gb / 2 ))

    while true; do
      input_print "Enter size for root partition in GB (default: ${default_root_size}GB)"
      read_from_tty -r root_size_input

      if [[ -z "$root_size_input" ]]; then
        ROOT_SIZE_GB="$default_root_size"
        info_print "Defaulting root partition size to ${ROOT_SIZE_GB}GB."
        break
      elif [[ "$root_size_input" =~ ^[0-9]+$ ]] && (( root_size_input >= 10 && root_size_input < total_size_gb )); then
        ROOT_SIZE_GB="$root_size_input"
        startup_ok "Root partition size set to ${ROOT_SIZE_GB}GB."
        break
      else
        warning_print "Invalid input. Please enter a number between 10 and $((total_size_gb-1))."
      fi
    done
  fi
}

# ================== Password, User and Dotfiles Setup ==================

password_and_user_setup() {
  section_header "Password and User Setup"

  # Step 1: Ask for LUKS password
  while true; do
    input_print "Enter LUKS password"
    stty -echo
    read_from_tty -r luks_pass1
    stty echo
    echo
    input_print "Confirm LUKS password"
    stty -echo
    read_from_tty -r luks_pass2
    stty echo
    echo

    if [[ "$luks_pass1" != "$luks_pass2" ]]; then
      warning_print "Passwords do not match. Please try again."
    elif [[ -z "$luks_pass1" ]]; then
      warning_print "Password cannot be empty. Please try again."
    else
      LUKS_PASSWORD="$luks_pass1"
      startup_ok "LUKS password set successfully."
      break
    fi
  done

  # Step 2: Ask for username
  input_print "Enter desired username (leave empty for root only)"
  read_from_tty -r USERNAME

  if [[ -z "$USERNAME" ]]; then
    info_print "No username entered. System will only have root account."
  else
    startup_ok "Username set to '$USERNAME'."
  fi

  # Step 3: Ask if we reuse LUKS password
  input_print "Reuse LUKS password for root and user accounts? [Y/n]"
  read_from_tty -r reuse_choice
  reuse_choice="${reuse_choice,,}"

  if [[ "$reuse_choice" =~ ^(n|no)$ ]]; then
    # Step 4: Ask separately for passwords

    # Root password
    while true; do
      input_print "Enter root password"
      stty -echo
      read_from_tty -r root_pass1
      stty echo
      echo
      input_print "Confirm root password"
      stty -echo
      read_from_tty -r root_pass2
      stty echo
      echo

      if [[ "$root_pass1" != "$root_pass2" ]]; then
        warning_print "Passwords do not match. Please try again."
      elif [[ -z "$root_pass1" ]]; then
        warning_print "Password cannot be empty. Please try again."
      else
        ROOT_PASSWORD="$root_pass1"
        startup_ok "Root password set successfully."
        break
      fi
    done

    # User password (only if username is set)
    if [[ -n "$USERNAME" ]]; then
      while true; do
        input_print "Enter user password for $USERNAME"
        stty -echo
        read_from_tty -r user_pass1
        stty echo
        echo
        input_print "Confirm user password for $USERNAME"
        stty -echo
        read_from_tty -r user_pass2
        stty echo
        echo

        if [[ "$user_pass1" != "$user_pass2" ]]; then
          warning_print "Passwords do not match. Please try again."
        elif [[ -z "$user_pass1" ]]; then
          warning_print "Password cannot be empty. Please try again."
        else
          USER_PASSWORD="$user_pass1"
          startup_ok "User password for '$USERNAME' set successfully."
          break
        fi
      done
    fi

  else
    ROOT_PASSWORD="$LUKS_PASSWORD"
    if [[ -n "$USERNAME" ]]; then
      USER_PASSWORD="$LUKS_PASSWORD"
    fi
    info_print "Reusing LUKS password for all accounts."
  fi

# Step 5: Ask about dotfiles (only if username is set)
if [[ -n "$USERNAME" ]]; then
  RESTORE_DOTFILES="no"

  input_print "Do you want to restore dotfiles for $USERNAME? [y/N]"
  read_from_tty -r install_dotfiles_choice
  install_dotfiles_choice="${install_dotfiles_choice,,}"

  if [[ "$install_dotfiles_choice" =~ ^(y|yes)$ ]]; then
    input_print "Enter Git URL for dotfiles repository (e.g. https://github.com/user/dotfiles)"
    read_from_tty -r dotfiles_repo

    if [[ -n "$dotfiles_repo" ]]; then
      RESTORE_DOTFILES="yes"
      DOTFILES_REPO="$dotfiles_repo"
      startup_ok "Dotfiles will be restored from '$DOTFILES_REPO'."
    else
      warning_print "No URL entered. Skipping dotfiles restore."
      RESTORE_DOTFILES="no"
    fi
  else
    info_print "Skipping dotfiles restore."
  fi
fi
}

# ================== Network Selector ==================

network_selector() {
  section_header "Network System Selection"

  info_print "Available Network Options:"
  echo
  echo "  1) NetworkManager  - Universal utility (WiFi + Ethernet, recommended for desktop)"
  echo "  2) IWD              - Simple Wi-Fi only (by Intel, built-in DHCP)"
  echo "  3) wpa_supplicant   - Wi-Fi only (requires dhcpcd separately)"
  echo "  4) dhcpcd           - Basic DHCP client (Ethernet or VMs)"
  echo "  5) None             - (Manual setup later - for advanced users)"
  echo

  while true; do
    input_print "Select your networking utility [1-5] (default: 1)"
    read_from_tty -r network_choice

    # Default to 1 if empty
    network_choice="${network_choice:-1}"

    case "$network_choice" in
      1)
        NETWORK_PKGS="networkmanager"
        NETWORK_ENABLE="systemctl enable NetworkManager"
        startup_ok "Selected NetworkManager."
        break
        ;;
      2)
        NETWORK_PKGS="iwd"
        NETWORK_ENABLE="systemctl enable iwd"
        startup_ok "Selected iwd."
        break
        ;;
      3)
        NETWORK_PKGS="wpa_supplicant dhcpcd"
        NETWORK_ENABLE="systemctl enable wpa_supplicant dhcpcd"
        startup_ok "Selected wpa_supplicant + dhcpcd."
        break
        ;;
      4)
        NETWORK_PKGS="dhcpcd"
        NETWORK_ENABLE="systemctl enable dhcpcd"
        startup_ok "Selected dhcpcd."
        break
        ;;
      5)
        NETWORK_PKGS=""
        NETWORK_ENABLE=""
        startup_warn "Skipping network setup as requested."
        break
        ;;
      *)
        warning_print "Invalid choice. Please select a number between 1 and 5."
        ;;
    esac
  done
}

# ================== Hostname Setup ==================

setup_hostname() {
  section_header "Hostname Setup"

  input_print "Enter desired hostname for your system (default: archlinux)"
  read_from_tty -r hostname_input

  if [[ -z "$hostname_input" ]]; then
    HOSTNAME="archlinux"
    info_print "Defaulting hostname to 'archlinux'."
  else
    HOSTNAME="$hostname_input"
    startup_ok "Hostname set to '$HOSTNAME'."
  fi
}

# ================== Create Users ==================

create_users() {
  section_header "User and Root Setup"

  # === Default shell system-wide ===
  info_print "Setting default shell to zsh system-wide..."
  sed -i 's|^SHELL=/bin/bash|SHELL=/bin/zsh|' /mnt/etc/default/useradd
  startup_ok "Default shell changed to zsh for new users."

  # === Populate /etc/skel before creating users ===
  info_print "Downloading default user files to /etc/skel..."

  curl -sSLo /mnt/etc/skel/.zshrc https://raw.githubusercontent.com/NeonGOD78/ArchLinuxPlus/refs/heads/main/configs/etc/skel/.zshrc
  curl -sSLo /mnt/etc/skel/.bashrc https://raw.githubusercontent.com/NeonGOD78/ArchLinuxPlus/refs/heads/main/configs/etc/skel/.bashrc
  curl -sSLo /mnt/etc/skel/.aliases https://raw.githubusercontent.com/NeonGOD78/ArchLinuxPlus/refs/heads/main/configs/etc/skel/.aliases

  mkdir -p /mnt/etc/skel/.local/bin
  curl -sSLo /mnt/etc/skel/.local/bin/setup-default-zsh https://raw.githubusercontent.com/NeonGOD78/ArchLinuxPlus/refs/heads/main/configs/etc/skel/.local/bin/setup-default-zsh
  chmod +x /mnt/etc/skel/.local/bin/setup-default-zsh

  mkdir -p /mnt/etc/skel/.cache/oh-my-posh/themes
  curl -sSLo /mnt/etc/skel/.cache/oh-my-posh/themes/zen.toml https://raw.githubusercontent.com/NeonGOD78/ArchLinuxPlus/refs/heads/main/configs/etc/skel/.cache/oh-my-posh/themes/zen.toml

  startup_ok "Default user config files downloaded to /etc/skel."

  # === Root password ===
  if [[ -n "$ROOT_PASSWORD" ]]; then
    info_print "Setting root password."
    echo "root:$ROOT_PASSWORD" | arch-chroot /mnt chpasswd >> "$LOGFILE" 2>&1
    startup_ok "Root password set."

    info_print "Setting root shell to zsh..."
    arch-chroot /mnt chsh -s /bin/zsh root >> "$LOGFILE" 2>&1

    info_print "Copying skel files to root..."
    arch-chroot /mnt cp -a /etc/skel/. /root/
    arch-chroot /mnt chown -R root:root /root/
    startup_ok "Root environment configured."
  else
    startup_error "ROOT_PASSWORD is empty. Skipping root setup."
  fi

  # === Create user ===
  if [[ -n "$USERNAME" ]]; then
    info_print "Creating user '$USERNAME'..."
    arch-chroot /mnt useradd -m -G wheel -s /bin/zsh "$USERNAME" >> "$LOGFILE" 2>&1 || {
      error_print "Failed to create user '$USERNAME'."
      exit 1
    }

    if [[ -n "$USER_PASSWORD" ]]; then
      echo "$USERNAME:$USER_PASSWORD" | arch-chroot /mnt chpasswd >> "$LOGFILE" 2>&1
      startup_ok "User '$USERNAME' created and password set."
    else
      startup_warn "USER_PASSWORD is empty. User created without password."
    fi
  else
    info_print "No user created. Only root account available."
  fi

  # === Optional: Restore dotfiles ===
  if [[ "$RESTORE_DOTFILES" == "yes" && -n "$DOTFILES_REPO" ]]; then
    info_print "Cloning dotfiles and applying with stow..."

    arch-chroot /mnt /bin/bash -c "
      sudo -u $USERNAME git clone --depth=1 '$DOTFILES_REPO' /home/$USERNAME/.dotfiles &&
      cd /home/$USERNAME/.dotfiles &&
      sudo -u $USERNAME stow */"
      
    startup_ok "Dotfiles restored using stow."
  else
    info_print "Dotfile restore skipped."
  fi
}

# ================== Kernel Selection ==================

kernel_selector() {
  section_header "Kernel Selection"

  info_print "Available Kernels:"
  echo
  echo "  1) Stable   - Vanilla Linux kernel with Arch Linux patches (recommended)"
  echo "  2) Zen      - Optimized for desktop usage (low latency)"
  echo "  3) Hardened - Security-focused Linux kernel"
  echo "  4) LTS      - Long-term support Linux kernel"
  echo

  while true; do
    input_print "Select your preferred kernel [1-4] (default: 1)"
    read_from_tty -r kernel_choice

    # Default to 1 if empty
    kernel_choice="${kernel_choice:-1}"

    case "$kernel_choice" in
      1)
        KERNEL_PACKAGE="linux"
        startup_ok "Selected Stable kernel (linux)."
        break
        ;;
      2)
        KERNEL_PACKAGE="linux-zen"
        startup_ok "Selected Zen kernel (linux-zen)."
        break
        ;;
      3)
        KERNEL_PACKAGE="linux-hardened"
        startup_ok "Selected Hardened kernel (linux-hardened)."
        break
        ;;
      4)
        KERNEL_PACKAGE="linux-lts"
        startup_ok "Selected LTS kernel (linux-lts)."
        break
        ;;
      *)
        warning_print "Invalid selection. Please choose 1-4."
        ;;
    esac
  done
}

# ================== Editor Selection ==================

editor_selector() {
  section_header "Editor Selection"

  info_print "Select a default text editor:"
  echo
  echo "  1) Nano   - Simple and beginner-friendly (recommended)"
  echo "  2) Neovim - Modern Vim with Lua integration"
  echo "  3) Vim    - Classic and powerful editor"
  echo "  4) Micro  - Simple, easy-to-use terminal editor"
  echo

  while true; do
    input_print "Select your preferred editor [1-4] (default: 1)"
    read_from_tty -r editor_choice

    # Default to 1 if empty
    editor_choice="${editor_choice:-1}"

    case "$editor_choice" in
      1)
        EDITOR_PACKAGE="nano"
        EDITOR_BIN="nano"
        startup_ok "Selected Nano as default editor."
        break
        ;;
      2)
        EDITOR_PACKAGE="neovim"
        EDITOR_BIN="nvim"
        startup_ok "Selected Neovim as default editor."
        break
        ;;
      3)
        EDITOR_PACKAGE="vim"
        EDITOR_BIN="vim"
        startup_ok "Selected Vim as default editor."
        break
        ;;
      4)
        EDITOR_PACKAGE="micro"
        EDITOR_BIN="micro"
        startup_ok "Selected Micro as default editor."
        break
        ;;
      *)
        warning_print "Invalid selection. Please select 1-4."
        ;;
    esac
  done
}

# ================== Confirm Installation ==================

confirm_installation() {
  section_header "Review Your Choices"

  echo
  info_print "Disk:          $DISK"
  
  if [[ "$SECURE_WIPE" == true ]]; then
    info_print "Wipe Method:   Secure Full Wipe (slow)"
  else
    info_print "Wipe Method:   Quick Partition Table Zap"
  fi

  if [[ "$SEPARATE_HOME" == true ]]; then
    info_print "Partitioning:  Separate root and home (root size: ${ROOT_SIZE_GB}GB)"
  else
    info_print "Partitioning:  Single root partition (no separate /home)"
  fi

  info_print "Keymap:        $KEYMAP"
  info_print "Locale:        $LOCALE"
  
  if [[ -n "$USERNAME" ]]; then
    info_print "Username:      $USERNAME"
  else
    info_print "Username:      (root only)"
  fi

  if [[ -n "$NETWORK_PKGS" ]]; then
    info_print "Network:       $NETWORK_PKGS"
  else
    info_print "Network:       (manual setup)"
  fi

  info_print "Hostname:      $HOSTNAME"
  info_print "Kernel:        $KERNEL_PACKAGE"
  info_print "Editor:        $EDITOR_PACKAGE"

  if [[ "$INSTALL_DOTFILES" == true ]]; then
    info_print "Dotfiles:      Yes (Repo: $DOTFILES_REPO)"
  else
    info_print "Dotfiles:      No"
  fi

  echo
  warning_print "WARNING: This will ERASE all data on $DISK!"

  echo
  input_print "Do you want to proceed? [y/N]"
  read_from_tty -r final_confirm
  final_confirm="${final_confirm,,}"

  if [[ "$final_confirm" =~ ^(y|yes)$ ]]; then
    startup_ok "Installation confirmed. Proceeding..."
  else
    error_print "Installation aborted by user."
    exit 1
  fi
}

# ================== Wipe Disk ==================

wipe_disk() {
  section_header "Disk Wipe"

  if [[ "$SECURE_WIPE" == true ]]; then
    warning_print "Securely wiping $DISK. This may take a long time..."
    dd if=/dev/urandom of="$DISK" bs=1M status=progress &>> "$LOGFILE" || {
      error_print "Secure wipe failed!"
      exit 1
    }
  else
    info_print "Quickly zapping partition table on $DISK."
    sgdisk --zap-all "$DISK" &>> "$LOGFILE" || {
      error_print "Quick wipe failed!"
      exit 1
    }
  fi
  startup_ok "Disk wipe completed."
}

# ================== Partition Disk ==================

partition_disk() {
  section_header "Disk Partitioning"

  info_print "Creating GPT partition layout on $DISK."

  parted --script "$DISK" mklabel gpt &>> "$LOGFILE"

  parted --script "$DISK" \
    mkpart primary fat32 1MiB 513MiB \
    set 1 esp on \
    mkpart primary 513MiB 100% &>> "$LOGFILE"

  partprobe "$DISK"
  sleep 2

  if [[ "$DISK" == *"nvme"* ]]; then
    EFI_PARTITION="${DISK}p1"
    ROOT_PARTITION="${DISK}p2"
    HOME_PARTITION="${DISK}p3"
  else
    EFI_PARTITION="${DISK}1"
    ROOT_PARTITION="${DISK}2"
    HOME_PARTITION="${DISK}3"
  fi

  if [[ "$SEPARATE_HOME" == true ]]; then
    info_print "Splitting root and home partitions."

    parted --script "$DISK" \
      rm 2 \
      mkpart primary 513MiB $((513 + ROOT_SIZE_GB * 1024))MiB \
      mkpart primary $((513 + ROOT_SIZE_GB * 1024))MiB 100% &>> "$LOGFILE"

    partprobe "$DISK"
    sleep 2

    if [[ "$DISK" == *"nvme"* ]]; then
      ROOT_PARTITION="${DISK}p2"
      HOME_PARTITION="${DISK}p3"
    else
      ROOT_PARTITION="${DISK}2"
      HOME_PARTITION="${DISK}3"
    fi
  fi

  startup_ok "Disk partitioning completed."
}

# ================== Wipe Existing LUKS Headers ==================

wipe_existing_luks_if_any() {
  section_header "Wiping Existing LUKS Headers (if any)"

  local partitions_to_check=("$ROOT_PARTITION")

  if [[ "$SEPARATE_HOME" == true ]]; then
    partitions_to_check+=("$HOME_PARTITION")
  fi

  for part in "${partitions_to_check[@]}"; do
    if cryptsetup isLuks "$part" &>/dev/null; then
      warning_print "Found LUKS header on $part. Wiping..."
      cryptsetup luksErase "$part" &>> "$LOGFILE" || {
        error_print "Failed to wipe LUKS header on $part."
        exit 1
      }
      success_print "LUKS header wiped from $part."
    else
      info_print "No LUKS header on $part. Continuing."
    fi
  done
}

# ================== Encrypt Partitions ==================

encrypt_partitions() {
  section_header "Encrypting Partitions with LUKS2"

  # Encrypt root
  info_print "Encrypting root partition: $ROOT_PARTITION"
  echo -n "$LUKS_PASSWORD" | cryptsetup luksFormat "$ROOT_PARTITION" -q --type luks2 &>> "$LOGFILE" || {
    error_print "Failed to format root partition with LUKS."
    exit 1
  }
  echo -n "$LUKS_PASSWORD" | cryptsetup open "$ROOT_PARTITION" cryptroot &>> "$LOGFILE" || {
    error_print "Failed to open LUKS root partition."
    exit 1
  }
  startup_ok "Root partition encrypted and opened."

  # Encrypt home (if separate home selected)
  if [[ "$SEPARATE_HOME" == true ]]; then
    info_print "Encrypting home partition: $HOME_PARTITION"
    echo -n "$LUKS_PASSWORD" | cryptsetup luksFormat "$HOME_PARTITION" -q --type luks2 &>> "$LOGFILE" || {
      error_print "Failed to format home partition with LUKS."
      exit 1
    }
    echo -n "$LUKS_PASSWORD" | cryptsetup open "$HOME_PARTITION" crypthome &>> "$LOGFILE" || {
      error_print "Failed to open LUKS home partition."
      exit 1
    }
    startup_ok "Home partition encrypted and opened."
  fi
}

# ================== Format Btrfs ==================

format_btrfs() {
  section_header "Formatting Partitions with Btrfs"

  mkfs.fat -F32 "$EFI_PARTITION" &>> "$LOGFILE" || {
    error_print "Failed to format EFI partition."
    exit 1
  }
  startup_ok "Formatted EFI partition as FAT32."

  mkfs.btrfs -f /dev/mapper/cryptroot &>> "$LOGFILE" || {
    error_print "Failed to format root partition as Btrfs."
    exit 1
  }
  startup_ok "Formatted root partition as Btrfs."

  if [[ "$SEPARATE_HOME" == true ]]; then
    mkfs.btrfs -f /dev/mapper/crypthome &>> "$LOGFILE" || {
      error_print "Failed to format home partition as Btrfs."
      exit 1
    }
    startup_ok "Formatted home partition as Btrfs."
  fi
}

# ================== Create Btrfs Subvolumes ==================

create_btrfs_subvolumes() {
  section_header "Creating Btrfs Subvolumes"

  # Mount root volume first
  mount /dev/mapper/cryptroot /mnt || {
    startup_fail "Failed to mount /dev/mapper/cryptroot to /mnt"
    exit 1
  }

  local subvolumes=(
    "@"
    "@var"
    "@srv"
    "@log"
    "@cache"
    "@tmp"
    "@portables"
    "@machines"
    "@snapshots"
  )

  for subvol in "${subvolumes[@]}"; do
    if btrfs subvolume create "/mnt/$subvol" &>/dev/null; then
      startup_ok "Created subvolume /mnt/$subvol"
    else
      warning_print "Failed to create subvolume /mnt/$subvol"
    fi
  done

  # If separate home, mount crypthome temporarily and create @home
  if [[ "$SEPARATE_HOME" == true ]]; then
    mkdir -p /mnt/home
    mount /dev/mapper/crypthome /mnt/home || {
      startup_fail "Failed to mount /dev/mapper/crypthome to /mnt/home"
      exit 1
    }

    if btrfs subvolume create /mnt/home/@home &>/dev/null; then
      startup_ok "Created subvolume /mnt/home/@home (separate crypthome)"
    else
      warning_print "Failed to create subvolume /mnt/home/@home"
    fi

    umount /mnt/home
  else
    # Single encrypted root – create @home directly on root
    if btrfs subvolume create /mnt/@home &>/dev/null; then
      startup_ok "Created subvolume /mnt/@home"
    else
      warning_print "Failed to create subvolume /mnt/@home"
    fi
  fi

  umount /mnt

  startup_ok "All Btrfs subvolumes created successfully."
}


# ================== Mount Subvolumes ==================

mount_subvolumes() {
  section_header "Mounting Filesystems"

  # Step 1: Mount root
  if mount -o noatime,compress=zstd,subvol=@ /dev/mapper/cryptroot /mnt; then
    startup_ok "Mounted /mnt (root @)"
  else
    startup_fail "Failed to mount /mnt (root @)"
    exit 1
  fi

  # Step 2: Create early directories
  mkdir -p /mnt/efi /mnt/var /mnt/srv /mnt/home /mnt/.snapshots

  # Step 3: Mount initial subvolumes
  if mount "$EFI_PARTITION" /mnt/efi; then
    startup_ok "Mounted EFI partition to /mnt/efi"
  else
    startup_fail "Failed to mount EFI partition"
    exit 1
  fi

  if [[ "$SEPARATE_HOME" == true ]]; then
    if mount -o noatime,compress=zstd,subvol=@home /dev/mapper/crypthome /mnt/home; then
      startup_ok "Mounted separate home partition to /mnt/home"
    else
      startup_fail "Failed to mount separate home partition"
      exit 1
    fi
  else
    if mount -o noatime,compress=zstd,subvol=@home /dev/mapper/cryptroot /mnt/home; then
      startup_ok "Mounted home subvolume from root to /mnt/home"
    else
      startup_fail "Failed to mount home subvolume"
      exit 1
    fi
  fi

  if mount -o noatime,compress=zstd,subvol=@var /dev/mapper/cryptroot /mnt/var; then
    startup_ok "Mounted /var subvolume"
  else
    startup_fail "Failed to mount /var"
    exit 1
  fi

  # NOW after /mnt/var exists:
  mkdir -p /mnt/var/log /mnt/var/cache /mnt/var/tmp /mnt/var/lib/portables /mnt/var/lib/machines

  if mount -o noatime,compress=zstd,subvol=@log /dev/mapper/cryptroot /mnt/var/log; then
    startup_ok "Mounted /var/log subvolume"
  else
    startup_fail "Failed to mount /var/log"
    exit 1
  fi

  if mount -o noatime,compress=zstd,subvol=@cache /dev/mapper/cryptroot /mnt/var/cache; then
    startup_ok "Mounted /var/cache subvolume"
  else
    startup_fail "Failed to mount /var/cache"
    exit 1
  fi

  if mount -o noatime,compress=zstd,subvol=@tmp /dev/mapper/cryptroot /mnt/var/tmp; then
    startup_ok "Mounted /var/tmp subvolume"
  else
    startup_fail "Failed to mount /var/tmp"
    exit 1
  fi

  if mount -o noatime,compress=zstd,subvol=@portables /dev/mapper/cryptroot /mnt/var/lib/portables; then
    startup_ok "Mounted /var/lib/portables subvolume"
  else
    startup_fail "Failed to mount /var/lib/portables"
    exit 1
  fi

  if mount -o noatime,compress=zstd,subvol=@machines /dev/mapper/cryptroot /mnt/var/lib/machines; then
    startup_ok "Mounted /var/lib/machines subvolume"
  else
    startup_fail "Failed to mount /var/lib/machines"
    exit 1
  fi

  if mount -o noatime,compress=zstd,subvol=@srv /dev/mapper/cryptroot /mnt/srv; then
    startup_ok "Mounted /srv subvolume"
  else
    startup_fail "Failed to mount /srv"
    exit 1
  fi

  if mount -o noatime,compress=zstd,subvol=@snapshots /dev/mapper/cryptroot /mnt/.snapshots; then
    startup_ok "Mounted /.snapshots subvolume"
  else
    startup_fail "Failed to mount /.snapshots"
    exit 1
  fi

  startup_ok "All filesystems mounted successfully."
}

# ================== Setup NoCOW Attributes ==================

nocow_setup() {
  section_header "Applying NoCOW Attributes"

  local nocow_paths=(
    "/mnt/var/log"
    "/mnt/var/cache"
    "/mnt/var/tmp"
    "/mnt/var/lib/portables"
    "/mnt/var/lib/machines"
  )

  for path in "${nocow_paths[@]}"; do
    if [[ -d "$path" ]]; then
      chattr +C "$path" &>/dev/null
      if [[ $? -eq 0 ]]; then
        startup_ok "NoCOW attribute applied to $path."
      else
        warning_print "Failed to apply NoCOW to $path."
      fi
    else
      warning_print "Directory $path does not exist, skipping NoCOW."
    fi
  done
}

# ================== Version Display ==================

print_version() {
  echo -e "ArchLinux+ Installer ${SCRIPT_VERSION}"
  echo -e "Maintained by: github.com/NeonGOD78/ArchLinuxPlus"
}

# ================== Help Display ==================

print_help() {
  echo -e ""
  echo -e "ArchLinux+ Installer ${SCRIPT_VERSION}"
  echo -e "Maintained by: github.com/NeonGOD78/ArchLinuxPlus"
  echo -e ""
  echo -e "Usage: bash install.sh [option]"
  echo -e ""
  echo -e "Available Options:"
  echo -e "  --version        Show script version and exit"
  echo -e "  --help           Show this help message and exit"
  echo -e ""
}

# ================== Debug Print Helper ==================

debug_print() {
  if [[ "$DEBUG" == true ]]; then
    printf "${DARKGRAY}[DEBUG]${RESET} ${LIGHTGRAY}%s${RESET}\n" "$1"
    echo "[DEBUG] $1" >> "$LOGFILE"
  fi
}

# =================== Base System Installation ===================
install_base_system() {
    info_print "Installing base system with pacstrap..."

    local base_packages=(
        base "$kernel" "$microcode" linux-firmware "$kernel"-headers
        btrfs-progs grub grub-btrfs rsync efibootmgr snapper reflector snap-pac
        zram-generator sudo inotify-tools zsh unzip fzf zoxide colordiff curl
        btop mc git systemd ukify openssl sbsigntools sbctl base-devel
        "$network_package"
    )

    if pacstrap -K /mnt "${base_packages[@]}"; then
        success_print "Base system installed successfully."
    else
        error_print "Base system installation failed!"
        exit 1
    fi
}

# ======================= Generate fstab ========================
gen_fstab() {
    info_print "Generating /etc/fstab..."

    if genfstab -U /mnt >> /mnt/etc/fstab 2>> "$LOGFILE"; then
        if [[ -s /mnt/etc/fstab ]]; then
            success_print "/etc/fstab generated successfully."
        else
            error_print "fstab file is empty. Something went wrong."
            exit 1
        fi
    else
        error_print "Failed to generate /etc/fstab. See logfile for details."
        exit 1
    fi
}

# ======================= Save Hostname ========================

save_hostname_config() {
  section_header "Writing hostname and hosts file"

  if [[ -n "$HOSTNAME" ]]; then
    echo "$HOSTNAME" > /mnt/etc/hostname
    startup_ok "Saved hostname '$HOSTNAME' to /mnt/etc/hostname."

    cat > /mnt/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOF

    startup_ok "/etc/hosts configured with hostname '$HOSTNAME'."
  else
    startup_error "Hostname variable is empty. Cannot configure hostname."
    exit 1
  fi
}

# ======================= Set Timezone ========================

set_timezone() {
  section_header "Timezone & Clock Configuration"

  info_print "Detecting timezone via ip-api.com..."
  ZONE=$(curl -s http://ip-api.com/line?fields=timezone)

  if [[ -z "$ZONE" ]]; then
    startup_error "Failed to detect timezone. Defaulting to UTC."
    ZONE="UTC"
  else
    startup_ok "Detected timezone: $ZONE"
  fi

  ln -sf "/usr/share/zoneinfo/$ZONE" /mnt/etc/localtime 2>> "$LOGFILE"
  if [[ $? -eq 0 ]]; then
    startup_ok "Timezone set to $ZONE."
  else
    startup_error "Failed to set timezone. See log for details."
    exit 1
  fi

  arch-chroot /mnt hwclock --systohc >> "$LOGFILE" 2>&1
  if [[ $? -eq 0 ]]; then
    startup_ok "Hardware clock synchronized."
  else
    startup_error "Failed to synchronize hardware clock. See log."
    exit 1
  fi
}

# ======================= Setup Initramfs ========================

setup_initramfs() {
  section_header "Initramfs & Systemd Hooks Setup"

  info_print "Configuring mkinitcpio for systemd boot hooks..."

  sed -i 's/^HOOKS=.*/HOOKS=(base systemd autodetect keyboard sd-vconsole sd-encrypt modconf block filesystems fsck)/' /mnt/etc/mkinitcpio.conf
  startup_ok "Updated mkinitcpio hooks to systemd style."

  info_print "Generating initramfs for all kernels..."
  arch-chroot /mnt mkinitcpio -P >> "$LOGFILE" 2>&1

  if [[ $? -eq 0 ]]; then
    startup_ok "Initramfs generated successfully."
  else
    startup_error "Initramfs generation failed. Check log."
    exit 1
  fi
}

# ======================= Setup UKI Build ========================

setup_uki_build() {
  section_header "Unified Kernel Image (UKI) Build"

  local kernel_path="/boot/vmlinuz-$kernel"
  local initramfs_path="/boot/initramfs-$kernel.img"
  local microcode_path="/boot/$microcode.img"
  local cmdline_path="/etc/kernel/cmdline"
  local output_path="/efi/EFI/Linux/arch.efi"

  # Check if all necessary components exist
  info_print "Checking for necessary files..."
  for file in "$kernel_path" "$initramfs_path" "$microcode_path" "$cmdline_path"; do
    if [[ ! -f "/mnt$file" ]]; then
      startup_error "Missing required file: $file"
      exit 1
    fi
  done
  startup_ok "All required files found."

  # Create /efi/EFI/Linux if missing
  arch-chroot /mnt mkdir -p /efi/EFI/Linux

  # Generate UKI
  info_print "Building UKI with ukify..."
  arch-chroot /mnt ukify \
    build \
    --kernel "$kernel_path" \
    --initrd "$microcode_path" \
    --initrd "$initramfs_path" \
    --cmdline-file "$cmdline_path" \
    --output "$output_path" \
    --os-release /usr/lib/os-release \
    --splash /usr/share/systemd/bootctl/splash-arch.bmp >> "$LOGFILE" 2>&1

  if [[ $? -eq 0 ]]; then
    startup_ok "UKI built and placed at $output_path"
  else
    startup_error "Failed to build UKI."
    exit 1
  fi

  # Sign the UKI
  info_print "Signing UKI with Secure Boot keys..."
  arch-chroot /mnt sbsign \
    --key /etc/secureboot/keys/db.key \
    --cert /etc/secureboot/keys/db.crt \
    --output "$output_path" \
    "$output_path" >> "$LOGFILE" 2>&1

  if [[ $? -eq 0 ]]; then
    startup_ok "UKI signed successfully."
  else
    startup_error "Failed to sign UKI."
    exit 1
  fi
}

# ======================= Setup Secureboot Structure ========================

setup_secureboot_structure() {
  section_header "Secure Boot Key Generation"

  local keydir="/mnt/etc/secureboot/keys"
  arch-chroot /mnt mkdir -p "$keydir"

  info_print "Generating Secure Boot keys (PK, KEK, db)..."

  # Generate Platform Key (PK)
  arch-chroot /mnt openssl req -new -x509 -newkey rsa:4096 \
    -subj "/CN=Platform Key/" \
    -keyout "$keydir/PK.key" -out "$keydir/PK.crt" \
    -days 3650 -nodes -sha256 >> "$LOGFILE" 2>&1

  # Generate Key Exchange Key (KEK)
  arch-chroot /mnt openssl req -new -x509 -newkey rsa:4096 \
    -subj "/CN=Key Exchange Key/" \
    -keyout "$keydir/KEK.key" -out "$keydir/KEK.crt" \
    -days 3650 -nodes -sha256 >> "$LOGFILE" 2>&1

  # Generate Signature Database Key (db)
  arch-chroot /mnt openssl req -new -x509 -newkey rsa:4096 \
    -subj "/CN=Signature Database/" \
    -keyout "$keydir/db.key" -out "$keydir/db.crt" \
    -days 3650 -nodes -sha256 >> "$LOGFILE" 2>&1

  startup_ok "Secure Boot keys generated and stored in $keydir."
}

# ==================== Setup cmdline file ====================

setup_cmdline_file() {
  section_header "Generating Kernel Command Line"

  local cmdline_path="/mnt/etc/kernel/cmdline"
  local root_uuid

  # Find UUID for root partition
  root_uuid=$(blkid -s UUID -o value "$ROOT_PARTITION")
  if [[ -z "$root_uuid" ]]; then
    startup_error "Unable to determine UUID for root partition."
    exit 1
  fi

  # Create cmdline file
  echo "root=UUID=$root_uuid rw quiet splash loglevel=3" > "$cmdline_path"

  startup_ok "Kernel command line written to $cmdline_path."
}

# ==================== Setup GRUB Bootloader ====================

setup_grub_bootloader() {
  section_header "GRUB Bootloader Setup"

  info_print "Installing GRUB to EFI system..."

  arch-chroot /mnt grub-install \
    --target=x86_64-efi \
    --efi-directory=/efi \
    --bootloader-id=GRUB \
    --recheck \
    --no-nvram >> "$LOGFILE" 2>&1

  if [[ $? -eq 0 ]]; then
    startup_ok "GRUB installed to EFI system partition."
  else
    startup_error "GRUB installation failed."
    exit 1
  fi

  # Set up grub-btrfs if installed
  if arch-chroot /mnt command -v grub-btrfsd &>/dev/null; then
    info_print "Setting up grub-btrfs snapshot integration..."
    arch-chroot /mnt systemctl enable grub-btrfsd.service >> "$LOGFILE" 2>&1
    startup_ok "grub-btrfs enabled."
  fi

  # Create custom UKI GRUB entry
  local grub_custom="/mnt/etc/grub.d/40_custom"

  info_print "Creating GRUB entry for signed UKI..."

  cat <<EOF > "$grub_custom"
menuentry 'Arch Linux (UKI)' {
    search --no-floppy --file --set=root /EFI/Linux/arch.efi
    chainloader /EFI/Linux/arch.efi
}
EOF

  chmod +x "$grub_custom"
  startup_ok "Custom GRUB UKI entry written to 40_custom."

  # Generate grub.cfg
  info_print "Generating GRUB config..."
  arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg >> "$LOGFILE" 2>&1

  if [[ $? -eq 0 ]]; then
    startup_ok "GRUB configuration generated."
  else
    startup_error "Failed to generate grub.cfg."
    exit 1
  fi
}

# ==================== Setup UKI pacman hook ====================

setup_uki_pacman_hook() {
  section_header "UKI Auto-Update Pacman Hook Setup"

  local hook_dir="/mnt/etc/pacman.d/hooks"
  local hook_file="$hook_dir/99-ukify.hook"
  local script_file="/mnt/usr/local/bin/rebuild-uki"

  info_print "Installing UKI auto-update pacman hook..."

  # Create hook directory if missing
  arch-chroot /mnt mkdir -p "$hook_dir"
  arch-chroot /mnt mkdir -p "$(dirname "$script_file")"

  # Write wrapper script
  cat <<'EOS' > "$script_file"
#!/bin/bash
set -euo pipefail

ukify build \
  --kernel /boot/vmlinuz-linux \
  --initrd /boot/amd-ucode.img \
  --initrd /boot/initramfs-linux.img \
  --cmdline-file /etc/kernel/cmdline \
  --output /efi/EFI/Linux/arch.efi \
  --os-release /usr/lib/os-release \
  --splash /usr/share/systemd/bootctl/splash-arch.bmp

sbsign --key /etc/secureboot/keys/db.key \
       --cert /etc/secureboot/keys/db.crt \
       --output /efi/EFI/Linux/arch.efi \
       /efi/EFI/Linux/arch.efi
EOS

  arch-chroot /mnt chmod +x "$script_file"

  # Create pacman hook
  cat <<EOF > "$hook_file"
[Trigger]
Type = Path
Operation = Install
Operation = Upgrade
Target = linux
Target = linux-firmware
Target = amd-ucode

[Action]
Description = Rebuilding and signing Unified Kernel Image (UKI)...
When = PostTransaction
Exec = /usr/local/bin/rebuild-uki
EOF

  startup_ok "UKI pacman hook and rebuild script installed."
}

# ==================== Setup GRUB pacman hook ====================

setup_grub_pacman_hook() {
  section_header "GRUB Secure Boot Pacman Hook Setup"

  local hook_dir="/mnt/etc/pacman.d/hooks"
  local hook_file="$hook_dir/99-grub-sign.hook"
  local script_file="/mnt/usr/local/bin/resign-grub"

  info_print "Installing GRUB re-sign pacman hook..."

  # Create directories if missing
  arch-chroot /mnt mkdir -p "$hook_dir"
  arch-chroot /mnt mkdir -p "$(dirname "$script_file")"

  # Write resign script
  cat <<'EOS' > "$script_file"
#!/bin/bash
set -euo pipefail

sbsign --key /etc/secureboot/keys/db.key \
       --cert /etc/secureboot/keys/db.crt \
       --output /efi/EFI/GRUB/grubx64.efi \
       /efi/EFI/GRUB/grubx64.efi
EOS

  arch-chroot /mnt chmod +x "$script_file"

  # Create pacman hook
  cat <<EOF > "$hook_file"
[Trigger]
Type = Package
Operation = Install
Operation = Upgrade
Target = grub

[Action]
Description = Re-signing GRUB EFI binary for Secure Boot...
When = PostTransaction
Exec = /usr/local/bin/resign-grub
EOF

  startup_ok "GRUB pacman hook and re-sign script installed."
}

# ==================== Main ====================

main() {
  # Help functions
  if [[ "$1" == "--debug" ]]; then
    DEBUG=true
    info_print "Debug mode enabled."
  fi

  if [[ "$1" == "--version" ]]; then
    print_version
    exit 0
  fi

  if [[ "$1" == "--help" ]]; then
    print_help
    exit 0
  fi
  
  # User Input
  banner_archlinuxplus
  log_start
  setup_keymap_and_locale
  select_disk
  partition_layout_choice
  password_and_user_setup
  network_selector
  setup_hostname
  kernel_selector
  editor_selector
  confirm_installation

  # Disk setup
  wipe_disk
  partition_disk
  wipe_existing_luks_if_any
  encrypt_partitions
  format_btrfs
  create_btrfs_subvolumes
  mount_subvolumes
  nocow_setup

  # Base System
  install_base_system
  move_logfile_to_mnt
  gen_fstab
  save_keymap_config
  save_locale_config
  save_hostname_config
  set_timezone
  create_users

  # Secureboot
  setup_secureboot_structure
  setup_cmdline_file
  setup_initramfs
  setup_uki_build
  setup_grub_bootloader
  setup_uki_pacman_hook
  setup_grub_pacman_hook


  
}

# ==================== Start Script ====================

main
