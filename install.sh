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

input_print() {
  printf "${DARKGRAY}[ ?  ]${RESET} ${LIGHTGRAY}%s: ${RESET}" "$1"
}

# ==================== Line Drawing Helper ====================

draw_line() {
  local char="${1:--}"   # Brug "-" som standard hvis intet angivet
  local color="${2:-$DARKGRAY}" # Brug mørkegrå hvis ingen farve angivet
  local width

  width=$(tput cols 2>/dev/null || echo 80)  # Hvis tput fejler, default til 80

  printf "${color}"
  printf "%${width}s" "" | tr " " "$char"
  printf "${RESET}\n"
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
