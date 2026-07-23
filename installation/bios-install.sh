#!/bin/bash

# ==========================================================
# ARCH LINUX INSTALLATION SCRIPT
# Alternative: Legacy BIOS/MBR
# Python: 3.12.7 via pyenv
# Hostname: worker2
# User: ibrahim with passwordless sudo
# ==========================================================

set -euo pipefail

# ==========================================================
# USER CONFIGURATION
# ==========================================================

DISK="/dev/sda"
INSTALL_MODE="bios"

KERNEL_CHOICE="linux-lts"
GPU_PROFILE="nouveau"

USER_NAME="ibrahim"
HOST_NAME="worker2"
TIMEZONE="Asia/Karachi"
LOCALE="en_US.UTF-8"
PYTHON_VERSION="3.12.7"

# BIOS/MBR partitions
BIOS_SWAP_PART="${DISK}1"
BIOS_ROOT_PART="${DISK}2"

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

if [[ "$INSTALL_MODE" == "bios" ]]; then
    echo "Legacy BIOS/MBR mode selected."
    echo "Open cfdisk and create a DOS/MBR partition table:"
    echo "  ${BIOS_SWAP_PART} = 4G-8G Linux swap"
    echo "  ${BIOS_ROOT_PART} = remaining Linux filesystem"
    echo "Mark ${BIOS_ROOT_PART} as bootable."
    cfdisk "$DISK"

    mkswap "$BIOS_SWAP_PART"
    swapon "$BIOS_SWAP_PART"
    mkfs.ext4 "$BIOS_ROOT_PART"

    mount "$BIOS_ROOT_PART" /mnt

else
    echo "Invalid INSTALL_MODE. Use 'uefi' or 'bios'."
    exit 1
fi

# ==========================================================
# BASE SYSTEM
# ==========================================================

    pacstrap /mnt base "$KERNEL_CHOICE" linux-firmware
else
    echo "Invalid KERNEL_CHOICE."
    exit 1
fi

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt 
# ==========================================================
# FINISH
# ==========================================================

# umount -R /mnt

echo "Installation complete."
echo "Now chroot."

# reboot
