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
PURPLE='\e[95m'

# ==================== Print Helpers ====================

draw_line() {
  local char="${1:--}"   # Standard "-" hvis ikke andet angivet
  local color="${2:-$DARKGRAY}"  # Standard mørkegrå
  local width

  width=$(tput cols 2>/dev/null || echo 80)

  printf "${color}"
  printf "%${width}s" "" | tr " " "$char"
  printf "${RESET}\n"
}

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

# ==================== Main ====================

main() {
  banner_archlinuxplus

  # Here you continue with your script, eg:
  # check_tty
  # partition_disks
  # encrypt_partitions
  # setup_filesystem
  # etc...
}

# ==================== Start Script ====================

main
