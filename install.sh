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

LOGFILE="/var/log/archinstall.log"

# ==================== Basic Helpers ====================

# Safe reading function
read_from_tty() {
  IFS= read "$@"
}

# Logging
log_msg() {
  printf "%s\n" "$1" >> "$LOGFILE"
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
  local color="${2:-$DARKGRAY}"
  local width

  width=$(tput cols 2>/dev/null || echo 80)

  printf "${color}"
  printf "%${width}s" "" | tr " " "$char"
  printf "${RESET}\n"
}

startup_print() {
  printf "${DARKGRAY}[      ]${RESET} ${LIGHTGRAY}%s${RESET}" "$1"
}

startup_ok() {
  printf "\r${DARKGRAY}[${GREEN}  OK  ${DARKGRAY}]${RESET} ${LIGHTGRAY}%s${RESET}\n" "$1"
  log_msg "[ OK ] $1"
}

startup_fail() {
  printf "\r${DARKGRAY}[${RED} FAIL ${DARKGRAY}]${RESET} ${LIGHTGRAY}%s${RESET}\n" "$1"
  log_msg "[FAIL] $1"
}

startup_warn() {
  printf "\r${DARKGRAY}[${YELLOW} WARN ${DARKGRAY}]${RESET} ${LIGHTGRAY}%s${RESET}\n" "$1"
  log_msg "[WARN] $1"
}

input_print() {
  printf "${DARKGRAY}[ ?  ]${RESET} ${LIGHTGRAY}%s: ${RESET}" "$1"
}

info_print() {
  printf "${DARKGRAY}[ i  ]${RESET} ${LIGHTGRAY}%s${RESET}\n" "$1"
  log_msg "[INFO] $1"
}

warning_print() {
  printf "${DARKGRAY}[${YELLOW}!${DARKGRAY}]${RESET} ${LIGHTGRAY}%s${RESET}\n" "$1"
  log_msg "[WARN] $1"
}

error_print() {
  printf "${DARKGRAY}[${RED}✖${DARKGRAY}]${RESET} ${LIGHTGRAY}%s${RESET}\n" "$1"
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
}

# ==================== Keymap Setup ====================

setup_keymap() {
  section_header "Keyboard Layout Setup"

  local search_term
  local available_keymaps
  available_keymaps=$(localectl list-keymaps 2>/dev/null)

  if [[ -z "$available_keymaps" ]]; then
    startup_warn "Could not fetch keymap list. Falling back to manual input."
  else
    info_print "You can search for a keymap (example: us, dk, de-latin1, fr, etc.)"
    input_print "Enter search term for keymaps or leave empty to see common:"
    read_from_tty -r search_term
    echo

    if [[ -n "$search_term" ]]; then
      printf "${LIGHTGRAY}Available keymaps matching '${search_term}':\n${RESET}"
      echo "$available_keymaps" | grep -i --color=never "$search_term" || startup_warn "No matching keymaps found."
    else
      printf "${LIGHTGRAY}Common keymaps:\n${RESET}"
      echo -e "us\ndk\nde-latin1\nfr\nes\nit\nno\nse"
    fi
  fi

  echo
  input_print "Enter your desired keymap [default: dk]"
  read_from_tty -r KEYMAP

  if [[ -z "$KEYMAP" ]]; then
    KEYMAP="dk"
    info_print "No keymap entered. Defaulting to 'dk'."
  fi

  if loadkeys "$KEYMAP" 2>/dev/null; then
    startup_ok "Keymap '$KEYMAP' loaded successfully."
  else
    startup_fail "Failed to load keymap '$KEYMAP'. Falling back to 'dk'."
    loadkeys dk
    KEYMAP="dk"
  fi
}

# ==================== Save Keymap to System ====================

save_keymap_config() {
  section_header "Saving Keyboard Layout"

  if [[ -n "$KEYMAP" ]]; then
    echo "KEYMAP=$KEYMAP" > /mnt/etc/vconsole.conf
    startup_ok "Saved keymap '$KEYMAP' to /mnt/etc/vconsole.conf."
  else
    startup_warn "No keymap to save. Skipping vconsole.conf setup."
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
    success_print "You selected: $DISK"
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
      success_print "Disk $DISK confirmed and ready for partitioning."
      break
    else
      warning_print "Disk not confirmed. Returning to selection."
      echo
    fi
  done
}

# ==================== Password Prompt Helper ====================

get_valid_password() {
  local prompt="$1"
  local pass1 pass2

  while true; do
    input_print "$prompt"
    stty -echo
    read_from_tty -r pass1
    stty echo
    echo

    if [[ -z "$pass1" ]]; then
      warning_print "Password cannot be empty."
      continue
    fi

    input_print "Confirm $prompt"
    stty -echo
    read_from_tty -r pass2
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

# ==================== Gather Passwords ====================

gather_passwords() {
  section_header "Password Configuration"

  info_print "You can reuse the same password for both LUKS and system login."

  input_print "Do you want to reuse the same password? [Y/n]"
  read_from_tty -r reuse_choice

  if [[ "${reuse_choice,,}" =~ ^(n|no)$ ]]; then
    # Forskellige passwords
    LUKS_PASSWORD=$(get_valid_password "Enter LUKS encryption password")
    SYSTEM_PASSWORD=$(get_valid_password "Enter system login password")
    success_print "Passwords set individually."
  else
    # Samme password til begge
    LUKS_PASSWORD=$(get_valid_password "Enter password for both LUKS and system login")
    SYSTEM_PASSWORD="$LUKS_PASSWORD"
    success_print "Same password will be used for LUKS and system login."
  fi
}

# ==================== Main ====================

main() {
  banner_archlinuxplus
  log_start
  setup_keymap
  select_disk
  gather_passwords
  
  # move_logfile_to_mnt
  # save_keymap_config
}

# ==================== Start Script ====================

main
