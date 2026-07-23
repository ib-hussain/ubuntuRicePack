#!/bin/bash
# ==========================================================
# CHROOT CONFIGURATION
# ==========================================================
# arch-chroot /mnt
set -euo pipefail
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
# TIMEZONE AND CLOCK
# ==========================================================

ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
hwclock --systohc

# ==========================================================
# LOCALE GENERATION
# ==========================================================

sed -i "s/^#${LOCALE} UTF-8/${LOCALE} UTF-8/" /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf

# ==========================================================
# HOSTNAME
# ==========================================================

echo "$HOST_NAME" > /etc/hostname

cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOST_NAME}.localdomain ${HOST_NAME}
EOF

# ==========================================================
# ROOT PASSWORD
# ==========================================================

echo "Set root password:"
passwd

# ==========================================================
# ESSENTIAL SYSTEM TOOLS
# Separate package groups to avoid random bulk installs
# ==========================================================

pacman -S --needed --noconfirm sudo nano
pacman -S --needed --noconfirm git base-devel
pacman -S --needed --noconfirm intel-ucode

# ==========================================================
# USER SETUP
# ==========================================================

useradd -m -G wheel,video,audio,storage,optical,input "$USER_NAME"

echo "Set password for ${USER_NAME}:"
passwd "$USER_NAME"

# Full admin access through passwordless sudo.
# This is safer than making ibrahim UID 0.
cat > "/etc/sudoers.d/${USER_NAME}" <<EOF
${USER_NAME} ALL=(ALL:ALL) NOPASSWD: ALL
EOF

chmod 440 "/etc/sudoers.d/${USER_NAME}"

# Convenience aliases so common admin commands do not require typing sudo.
cat >> "/home/${USER_NAME}/.bashrc" <<'EOF'

# Admin shortcuts
alias root='sudo -i'
alias pacman='sudo pacman'
alias systemctl='sudo systemctl'
alias journalctl='sudo journalctl'
alias reboot='sudo reboot'
alias poweroff='sudo poweroff'
alias update='sudo pacman -Syu'
alias install='sudo pacman -S'
alias remove='sudo pacman -Rns'
alias cls='clear'
alias turnoff='sudo poweroff'
alias install-y='sudo pacman -S --needed --noconfirm'
EOF

chown "$USER_NAME:$USER_NAME" "/home/${USER_NAME}/.bashrc"

# ==========================================================
# BOOTLOADER
# ==========================================================
pacman -S --needed --noconfirm grub efibootmgr os-prober

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ArchLinux

echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub
echo 'GRUB_COLOR_NORMAL="light-blue/black"' >> /etc/default/grub
echo 'GRUB_COLOR_HIGHLIGHT="light-cyan/blue"' >> /etc/default/grub
sed -i 's/^GRUB_TIMEOUT=5/GRUB_TIMEOUT=3/' /etc/default/grub || true
echo 'GRUB_INIT_TUNE="480 440 1"' >> /etc/default/grub
echo 'GRUB_BACKGROUND="/boot/grub/bg.png"' >> /etc/default/grub
echo 'GRUB_SAVEDEFAULT="true"' >> /etc/default/grub
sed -i 's/^GRUB_DEFAULT=0/GRUB_DEFAULT=saved/' /etc/default/grub || true

grub-mkconfig -o /boot/grub/grub.cfg


# ==========================================================
# NETWORK
# ==========================================================

pacman -S --needed --noconfirm networkmanager xf86-video-nouveau mesa
systemctl enable NetworkManager

# ==========================================================
# PYENV + PYTHON 3.12.7
# Dependencies separated for clarity
# ==========================================================

pacman -S --needed --noconfirm pyenv

# Build dependencies needed by CPython through pyenv
pacman -S --needed --noconfirm openssl zlib xz bzip2 libffi readline sqlite tk ncurses curl

cat >> "/home/${USER_NAME}/.bashrc" <<'EOF'

# pyenv configuration
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv >/dev/null 2>&1; then
    eval "$(pyenv init - bash)"
fi
EOF

cat > "/home/${USER_NAME}/.bash_profile" <<'EOF'
[[ -f ~/.bashrc ]] && . ~/.bashrc
EOF

chown "$USER_NAME:$USER_NAME" "/home/${USER_NAME}/.bashrc" "/home/${USER_NAME}/.bash_profile"

su - "$USER_NAME" -c "PYENV_ROOT=\"\$HOME/.pyenv\" pyenv install -s ${PYTHON_VERSION}"
su - "$USER_NAME" -c "PYENV_ROOT=\"\$HOME/.pyenv\" pyenv global ${PYTHON_VERSION}"
su - "$USER_NAME" -c "PYENV_ROOT=\"\$HOME/.pyenv\" pyenv rehash"
su - "$USER_NAME" -c "PYENV_ROOT=\"\$HOME/.pyenv\" pyenv exec python --version"

# ==========================================================
# Arch Display Install
# ==========================================================
su - "$USER_NAME" -c "cd ~ && rm -rf archRicePack && git clone https://github.com/ib-hussain/archRicePack"
cd "/home/${USER_NAME}/archRicePack"
chmod +x install-rice.sh scripts/*.sh
bash install-rice.sh --chroot --target-user "$USER_NAME"

exit