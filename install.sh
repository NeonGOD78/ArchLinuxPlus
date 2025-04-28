#!/usr/bin/env bash

# ==================== Colors ====================
RESET='\e[0m'
BOLD='\e[1m'
DARKGRAY='\e[90m'
LIGHTGRAY='\e[37m'
RED='\e[91m'
GREEN='\e[92m'
YELLOW='\e[93m'

# ==================== Startup Style Print Helpers ====================

startup_print() {
  printf "${DARKGRAY}[      ]${RESET} ${LIGHTGRAY}%s${RESET}" "$1"
}

startup_ok() {
  printf "\r${DARKGRAY}[${GREEN}  OK  ${DARKGRAY}]${RESET} ${LIGHTGRAY}%s${RESET}\n" "$1"
}

startup_fail() {
  printf "\r${DARKGRAY}[${RED} FAIL ${DARKGRAY}]${RESET} ${LIGHTGRAY}%s${RESET}\n" "$1"
}

startup_warn() {
  printf "\r${DARKGRAY}[${YELLOW} WARN ${DARKGRAY}]${RESET} ${LIGHTGRAY}%s${RESET}\n" "$1"
}


# ==================== Section Header Helper ====================

section_header() {
  local title="$1"
  local char="${2:--}"   # Standard "-" hvis ikke andet
  local color="${3:-$DARKGRAY}"  # Standard mørkegrå
  local width padding

  width=$(tput cols 2>/dev/null || echo 80)  # Terminal bredde

  # Top line
  printf "${color}"
  printf "%${width}s" "" | tr " " "$char"
  printf "${RESET}\n"

  # Centered title
  padding=$(( (width - ${#title}) / 2 ))
  printf "${color}%*s%s\n" "$padding" "" "$title"
  
  # Bottom line
  printf "%${width}s" "" | tr " " "$char"
  printf "${RESET}\n"
}
