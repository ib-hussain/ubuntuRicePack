#!/bin/bash
set -euo pipefail
# ==========================================================
# Ubuntu INSTALLATION SCRIPT
# User: ibrahim with passwordless sudo
# USER CONFIGURATION
# ==========================================================
USER_NAME="ibrahim"
HOST_NAME="ibLaptop"
TIMEZONE="Asia/Karachi"
LOCALE="en_US.UTF-8"
PYTHON_VERSION="3.12.7"
# ==========================================================
# PARTITIONING
# ==========================================================

if [[ "$INSTALL_MODE" == "uefi" ]]; then
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

arch-chroot /mnt
# TIMEZONE AND CLOCK
ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
hwclock --systohc
# LOCALE GENERATION
sed -i "s/^#${LOCALE} UTF-8/${LOCALE} UTF-8/" /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf
# HOSTNAME
echo "$HOST_NAME" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOST_NAME}.localdomain ${HOST_NAME}
EOF
# ROOT PASSWORD
echo "Set root password:"
passwd
# ESSENTIAL SYSTEM TOOLS
apt install -y sudo nano git base-devel intel-ucode
# USER SETUP
useradd -m -G wheel,video,audio,storage,optical,input "$USER_NAME"
echo "Set password for ${USER_NAME}:"
passwd "$USER_NAME"
# Full admin access through passwordless sudo.
# This is safer than making ibrahim UID 0.
cat > "/etc/sudoers.d/${USER_NAME}" <<EOF
${USER_NAME} ALL=(ALL:ALL) NOPASSWD: ALL
EOF
chmod 440 "/etc/sudoers.d/${USER_NAME}"
# ==========================================================
# BOOTLOADER
echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub
echo 'GRUB_COLOR_NORMAL="light-blue/black"' >> /etc/default/grub
echo 'GRUB_COLOR_HIGHLIGHT="light-cyan/blue"' >> /etc/default/grub
sed -i 's/^GRUB_TIMEOUT=5/GRUB_TIMEOUT=3/' /etc/default/grub || true
echo 'GRUB_INIT_TUNE="480 440 1"' >> /etc/default/grub
echo 'GRUB_BACKGROUND="/boot/grub/bg.png"' >> /etc/default/grub
echo 'GRUB_SAVEDEFAULT="true"' >> /etc/default/grub
sed -i 's/^GRUB_DEFAULT=0/GRUB_DEFAULT=saved/' /etc/default/grub || true

# ==========================================================
# PYENV + PYTHON 3.12.7
# Dependencies separated for clarity
# ==========================================================

apt install -y pyenv openssl zlib xz bzip2 libffi readline sqlite tk ncurses curl

su - "$USER_NAME" -c "PYENV_ROOT=\"\$HOME/.pyenv\" pyenv install -s ${PYTHON_VERSION}"
su - "$USER_NAME" -c "PYENV_ROOT=\"\$HOME/.pyenv\" pyenv global ${PYTHON_VERSION}"
su - "$USER_NAME" -c "PYENV_ROOT=\"\$HOME/.pyenv\" pyenv rehash"
su - "$USER_NAME" -c "PYENV_ROOT=\"\$HOME/.pyenv\" pyenv exec python --version"

exit
umount -R /mnt
echo "Installation complete."

# reboot
