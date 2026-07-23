#!/bin/bash

# ==========================================================
# ARCH LINUX INSTALLATION SCRIPT
# Default boot mode: UEFI/GPT
# Python: 3.12.7 via pyenv
# Hostname: ibLaptop
# User: ibrahim with passwordless sudo
# ==========================================================

set -euo pipefail

# ==========================================================
# USER CONFIGURATION
# ==========================================================

DISK="/dev/sda"
INSTALL_MODE="uefi"
KERNEL_CHOICE="linux-lts"
GPU_PROFILE="standard"
USER_NAME="ibrahim"
HOST_NAME="ibLaptop"
TIMEZONE="Asia/Karachi"
LOCALE="en_US.UTF-8"
PYTHON_VERSION="3.12.7"
# UEFI/GPT partitions
EFI_PART="${DISK}1"
SWAP_PART="${DISK}2"
ROOT_PART="${DISK}3"

# ==========================================================
# NETWORK IN LIVE ISO
# ==========================================================

echo "Connect Wi-Fi manually using iwctl if not already connected."
echo "Example:"
echo "  iwctl"
echo "  station wlan0 get-networks"
echo "  station wlan0 connect YOUR_WIFI_NAME"
echo "  exit"
echo

ping -c 4 archlinux.org

# ==========================================================
# SYNC LIVE ENVIRONMENT KEYRING
# ==========================================================

pacman -Sy --noconfirm archlinux-keyring

# ==========================================================
# PARTITIONING
# ==========================================================

if [[ "$INSTALL_MODE" == "uefi" ]]; then
    echo "UEFI/GPT mode selected."
    echo "Open cfdisk and create:"
    echo "  ${EFI_PART}  = 512M-1G EFI System"
    echo "  ${SWAP_PART} = 4G-8G Linux swap"
    echo "  ${ROOT_PART} = remaining Linux filesystem"
    cfdisk "$DISK"

    mkfs.fat -F32 "$EFI_PART"
    mkswap "$SWAP_PART"
    swapon "$SWAP_PART"
    mkfs.ext4 "$ROOT_PART"

    mount "$ROOT_PART" /mnt
    mkdir -p /mnt/boot
    mount "$EFI_PART" /mnt/boot

else
    echo "Invalid INSTALL_MODE. Use 'uefi' or 'bios'."
    exit 1
fi

# ==========================================================
# BASE SYSTEM
# ==========================================================

pacstrap /mnt base "$KERNEL_CHOICE" linux-firmware
genfstab -U /mnt >> /mnt/etc/fstab

# arch-chroot /mnt
# ==========================================================
# FINISH
# ==========================================================

# umount -R /mnt

echo "Installation complete."
echo "Now chroot."

# reboot
