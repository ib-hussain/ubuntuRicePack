#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-common.sh"

require_user_session
# find a line in the pacman.conf like "#IgnorePkg = " and replace with contents of installation/pacman.conf
sudo sed -i '/^#IgnorePkg = /c\IgnorePkg = linux-lts linux-lts-headers linux-firmware mesa xf86-video-nouveau nvidia-lts nvidia-utils lib32-nvidia-utils gdm gnome-shell mutter xorg-server' /etc/pacman.conf || log "Warning: Could not find #IgnorePkg line in /etc/pacman.conf"
sudo pacman -S --needed gnome-keyring evolution-data-server at-spi2-core xdg-desktop-portal xdg-desktop-portal-gnome

sudo echo "#GDM configuration storage "          | sudo  tee     /etc/gdm/custom.conf
sudo echo "  "                                   |  sudo  tee -a  /etc/gdm/custom.conf
sudo echo "[daemon] "                            |  sudo  tee -a  /etc/gdm/custom.conf
sudo echo "WaylandEnable=false "                 |  sudo  tee -a  /etc/gdm/custom.conf
sudo echo "  "                                   |  sudo  tee -a  /etc/gdm/custom.conf
sudo echo "[security] "                          |  sudo  tee -a  /etc/gdm/custom.conf
sudo echo "  "                                   |  sudo  tee -a  /etc/gdm/custom.conf
sudo echo "[debug] "                             | sudo   tee -a  /etc/gdm/custom.conf
sudo echo "#Uncomment line to turn on debugging "| sudo   tee -a  /etc/gdm/custom.conf
sudo echo "#Enable=true "                        |  sudo  tee -a  /etc/gdm/custom.conf

log "Added the packages for no upgrade to /etc/pacman.conf"

git config --global user.name "Ibrahim Hussain"
git config --global user.email "ibrahimbeaconarion@gmail.com"
git config --global init.defaultBranch main
git config core.editor "nano"
git config --global merge.tool vscode
git config --global mergetool.vscode.cmd "code --wait $MERGED"
git config --global push.default simple
# git config --global pull.rebase true
# git config --global pull.merge true