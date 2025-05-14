#!/bin/bash
# ===================== debug_mount.sh =====================
set -euo pipefail

echo "Opening LUKS volumes..."

cryptsetup open /dev/nvme1n1p3 cryptroot
cryptsetup open /dev/nvme1n1p4 crypthome

echo "Mounting root (@) subvolume..."
mount -o noatime,compress=zstd,subvol=@ /dev/mapper/cryptroot /mnt

echo "Mounting EFI partition..."
mount /dev/nvme1n1p1 /mnt/efi

echo "Mounting separate /home..."
mount -o noatime,compress=zstd,subvol=@home /dev/mapper/crypthome /mnt/home

echo "Mounting /var and subvolumes..."
mount -o noatime,compress=zstd,subvol=@var /dev/mapper/cryptroot /mnt/var
mkdir -p /mnt/var/log /mnt/var/cache /mnt/var/tmp /mnt/var/lib/portables /mnt/var/lib/machines
mount -o noatime,compress=zstd,subvol=@log /dev/mapper/cryptroot /mnt/var/log
mount -o noatime,compress=zstd,subvol=@cache /dev/mapper/cryptroot /mnt/var/cache
mount -o noatime,compress=zstd,subvol=@tmp /dev/mapper/cryptroot /mnt/var/tmp
mount -o noatime,compress=zstd,subvol=@portables /dev/mapper/cryptroot /mnt/var/lib/portables
mount -o noatime,compress=zstd,subvol=@machines /dev/mapper/cryptroot /mnt/var/lib/machines

echo "Mounting /srv..."
mkdir -p /mnt/srv
mount -o noatime,compress=zstd,subvol=@srv /dev/mapper/cryptroot /mnt/srv

echo "All filesystems mounted successfully under /mnt."
