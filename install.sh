# !/bin/bash

# ==================================
# Project: hyprhub
# Author: grid
# Description: Hyprland configuration installer
# ==================================

set -e

PROJECT="hyprhub"
VERSION="1.0"

BACKUP="$HOME/.config-backup-$PROJECT-$(date +%F-%H%M)"
LOG="$HOME/.local/share/$PROJECT/install.log"


PACKAGES=(
    hyprland
    waybar
    kitty
    rofi-wayland
    cava
    wlogout
    anyrun
    waypaper
    swaync
    pipewire
    wireplumber
    polkit
    xdg-desktop-portal-hyprland
    qt5-wayland
    qt6-wayland
    gtk3
    gtk4
)


CONFIGS=(
    hypr
    waybar
    kitty
    rofi
    anyrun
    cava
    wlogout
    waypaper
    gtk-3.0
    gtk-4.0
)


mkdir -p "$(dirname "$LOG")"


echo "=================================="
echo "        hyprhub installer"
echo "        Author: grid"
echo "        Version: $VERSION"
echo "=================================="
echo


echo "1) O'zbekcha"
echo "2) English"
echo

read -p "Language: " LANG


case $LANG in

1)
INSTALL="hyprhub o'rnatilsinmi?"
CANCEL="Bekor qilindi"
MISSING="Yetishmayotgan paketlar"
INSTALLING="Paketlar o'rnatilmoqda"
BACKUP="Backup qilinmoqda"
CONFIG="Config o'rnatilmoqda"
DONE="Tayyor!"
# ;

2)
INSTALL="Install hyprhub?"
CANCEL="Cancelled"
MISSING="Missing packages"
INSTALLING="Installing packages"
BACKUP="Creating backup"
CONFIG="Installing configs"
DONE="Finished!"
# ;

*)
echo "Wrong choice"
exit 1
# ;

esac



echo

read -p "$INSTALL [Y/n]: " ANSWER


case $ANSWER in

n|N)
echo "$CANCEL"
exit 0
# ;

esac



echo
echo "[1/6] System check"


if [ -f /etc/arch-release ]; then

echo "✓ Arch Linux"

else

echo "This installer supports Arch Linux only"
exit 1

fi



echo
echo "[2/6] Dependency check"


MISSING_PACKAGES=()


for pkg in "${PACKAGES[@]}"; do

if pacman -Q "$pkg" >/dev/null 2>&1; then

echo "✓ $pkg"

else

echo "✗ $pkg"
MISSING_PACKAGES+=("$pkg")

fi

done



if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then


echo
echo "$MISSING"

printf '%s\n' "${MISSING_PACKAGES[@]}"


echo

read -p "Install missing packages? [Y/n]: " INSTALL_PACKAGES


case $INSTALL_PACKAGES in

n|N)
echo "Continue without packages"
# ;

*)
sudo pacman -S --needed "${MISSING_PACKAGES[@]}"
# ;

esac


fi




echo
echo "[3/6] $BACKUP"


mkdir -p "$BACKUP"


for cfg in "${CONFIGS[@]}"; do

if [ -d "$HOME/.config/$cfg" ]; then

cp -r "$HOME/.config/$cfg" "$BACKUP/"
echo "Backup: $cfg"

fi

done




echo
echo "[4/6] $CONFIG"


mkdir -p "$HOME/.config"


for cfg in "${CONFIGS[@]}"; do


if [ -d "$cfg" ]; then

rm -rf "$HOME/.config/$cfg"

cp -r "$cfg" "$HOME/.config/"


echo "Installed: $cfg"

fi


done




echo
echo "[5/6] Installing scripts"


mkdir -p "$HOME/.local/bin"


if [ -d bin ]; then

cp -r bin/* "$HOME/.local/bin/"

chmod +x "$HOME/.local/bin/"*

echo "Scripts installed"

fi




echo
echo "[6/6] Final check"


if grep -R "/home/" \
# exclude-dir=.git \
# exclude=install.sh \
. >/dev/null 2>&1

then

echo "WARNING: hardcoded path found"

else

echo "Paths OK"

fi



if command -v hyprctl >/dev/null 2>&1; then

hyprctl reload || true

echo "Hyprland reloaded"

fi



echo "$(date) finished" >> "$LOG"



echo
echo "=================================="
echo "$DONE"
echo
echo "Backup:"
echo "$BACKUP"
echo "=================================="
