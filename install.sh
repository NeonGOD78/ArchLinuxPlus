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

# ==================== Simuleret Opstart ====================

sleep 0.5
startup_print "Wiping disk..."
sleep 1
startup_ok "Wiping disk..."

sleep 0.5
startup_print "Partitioning disk..."
sleep 1
startup_fail "Partitioning disk..."

sleep 0.5
startup_print "Encrypting root partition..."
sleep 1
startup_ok "Encrypting root partition..."

sleep 0.5
startup_print "Formatting filesystem..."
sleep 1
startup_warn "Formatting filesystem..."

sleep 0.5
startup_print "Mounting filesystems..."
sleep 1
startup_ok "Mounting filesystems..."
