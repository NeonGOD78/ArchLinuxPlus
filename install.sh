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
  printf "\r${DARKGRAY}[${CYAN}Info${DARKGRAY}]${RESET} ${LIGHTGRAY}%s${RESET}\n" "$1"
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
  else
    startup_warn "No locale to save. Skipping locale.conf setup."
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
    input_print "Do you want to install dotfiles for $USERNAME? [y/N]"
    read_from_tty -r install_dotfiles_choice
    install_dotfiles_choice="${install_dotfiles_choice,,}"

    if [[ "$install_dotfiles_choice" =~ ^(y|yes)$ ]]; then
      input_print "Enter GitHub URL for dotfiles repository (default: none)"
      read_from_tty -r dotfiles_repo

      if [[ -n "$dotfiles_repo" ]]; then
        INSTALL_DOTFILES=true
        DOTFILES_REPO="$dotfiles_repo"
        startup_ok "Dotfiles will be installed from '$DOTFILES_REPO'."
      else
        warning_print "No URL entered. Skipping dotfiles installation."
        INSTALL_DOTFILES=false
      fi
    else
      INSTALL_DOTFILES=false
      info_print "Skipping dotfiles installation."
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

# ================== Install Dotfiles ==================

install_dotfiles() {
  if [[ "$INSTALL_DOTFILES" == true && -n "$DOTFILES_REPO" && -n "$USERNAME" ]]; then
    section_header "Dotfiles Installation"

    info_print "Cloning dotfiles repository for user '$USERNAME'."

    # Clone into /home/username/.dotfiles
    arch-chroot /mnt /bin/bash -c "
      git clone '$DOTFILES_REPO' /home/$USERNAME/.dotfiles &&
      cd /home/$USERNAME/.dotfiles &&
      stow */
    " || {
      warning_print "Failed to clone and install dotfiles for '$USERNAME'."
      return 1
    }

    # Ensure correct ownership
    arch-chroot /mnt /bin/bash -c "
      chown -R $USERNAME:$USERNAME /home/$USERNAME/.dotfiles
    "

    success_print "Dotfiles installed successfully for '$USERNAME'."
  else
    info_print "Skipping dotfiles installation."
  fi
}

# ================== Create Users ==================

create_users() {
  section_header "User and Root Setup"

  # Set root password
  info_print "Setting root password."
  echo "root:$ROOT_PASSWORD" | arch-chroot /mnt chpasswd
  startup_ok "Root password set."

  # Create user if USERNAME is set
  if [[ -n "$USERNAME" ]]; then
    info_print "Creating user '$USERNAME'."

    # Create user and add to wheel group
    arch-chroot /mnt useradd -m -G wheel -s /bin/bash "$USERNAME" || {
      error_print "Failed to create user '$USERNAME'."
      exit 1
    }

    # Set user password
    echo "$USERNAME:$USER_PASSWORD" | arch-chroot /mnt chpasswd

    startup_ok "User '$USERNAME' created and password set."
  else
    info_print "No user created. Only root account available."
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

  mount /dev/mapper/cryptroot /mnt

  # Altid disse på root
  btrfs subvolume create /mnt/@
  btrfs subvolume create /mnt/@var
  btrfs subvolume create /mnt/@srv
  btrfs subvolume create /mnt/@log
  btrfs subvolume create /mnt/@cache
  btrfs subvolume create /mnt/@tmp
  btrfs subvolume create /mnt/@portables
  btrfs subvolume create /mnt/@machines
  btrfs subvolume create /mnt/@snapshots

  # Håndter home afhængigt af setup
  if [[ "$SEPARATE_HOME" == true ]]; then
    mkdir -p /mnt/home
    mount /dev/mapper/crypthome /mnt/home
    btrfs subvolume create /mnt/home/@home
    umount /mnt/home
  else
    btrfs subvolume create /mnt/@home
  fi

  umount /mnt
  startup_ok "Btrfs subvolumes created successfully."
}

# ================== Mount Subvolumes ==================

mount_subvolumes() {
  section_header "Mounting Filesystems"

  # Mount root subvolume
  mount -o noatime,compress=zstd,subvol=@ /dev/mapper/cryptroot /mnt

  # Create necessary directories manually
  mkdir -p /mnt/efi
  mkdir -p /mnt/home
  mkdir -p /mnt/var
  mkdir -p /mnt/var/log
  mkdir -p /mnt/var/cache
  mkdir -p /mnt/var/tmp
  mkdir -p /mnt/var/lib
  mkdir -p /mnt/var/lib/portables
  mkdir -p /mnt/var/lib/machines
  mkdir -p /mnt/srv
  mkdir -p /mnt/.snapshots

  # Mount EFI partition
  mount "$EFI_PARTITION" /mnt/efi

  # Mount home
  if [[ "$SEPARATE_HOME" == true ]]; then
    mount -o noatime,compress=zstd,subvol=@home /dev/mapper/crypthome /mnt/home
  else
    mount -o noatime,compress=zstd,subvol=@home /dev/mapper/cryptroot /mnt/home
  fi

  # Mount the rest
  mount -o noatime,compress=zstd,subvol=@var /dev/mapper/cryptroot /mnt/var
  mount -o noatime,compress=zstd,subvol=@srv /dev/mapper/cryptroot /mnt/srv
  mount -o noatime,compress=zstd,subvol=@log /dev/mapper/cryptroot /mnt/var/log
  mount -o noatime,compress=zstd,subvol=@cache /dev/mapper/cryptroot /mnt/var/cache
  mount -o noatime,compress=zstd,subvol=@tmp /dev/mapper/cryptroot /mnt/var/tmp
  mount -o noatime,compress=zstd,subvol=@portables /dev/mapper/cryptroot /mnt/var/lib/portables
  mount -o noatime,compress=zstd,subvol=@machines /dev/mapper/cryptroot /mnt/var/lib/machines
  mount -o noatime,compress=zstd,subvol=@snapshots /dev/mapper/cryptroot /mnt/.snapshots

  startup_ok "Filesystems mounted successfully."
}

# ================== Setup NoCOW Attributes ==================

nocow_setup() {
  section_header "Applying NoCOW Attributes"

  for path in /mnt/var/log /mnt/var/cache /mnt/var/tmp /mnt/var/lib/portables /mnt/var/lib/machines; do
    if [[ -d "$path" ]]; then
      chattr +C "$path" || warning_print "Failed to set NoCOW on $path"
    else
      warning_print "Directory $path not found, skipping NoCOW."
    fi
  done

  startup_ok "NoCOW attributes applied where possible."
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
  
  # move_logfile_to_mnt
  # save_keymap_config
  # save_locale_config
  # create_users
  # install_dotfiles
}

# ==================== Start Script ====================

main
