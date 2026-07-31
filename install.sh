#!/usr/bin/env bash
#
# ==================================
# Project: hyprhub
# Author: grid
# Description: Hyprland configuration installer
# ==================================

set -euo pipefail

# ---------- Meta ----------
PROJECT="hyprhub"
VERSION="1.1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

TIMESTAMP="$(date +%F-%H%M)"
BACKUP_DIR="$HOME/.config-backup-$PROJECT-$TIMESTAMP"
LOG_FILE="$HOME/.local/share/$PROJECT/install.log"

# ---------- Colors ----------
if [ -t 1 ]; then
    C_RESET=$'\e[0m'; C_BOLD=$'\e[1m'
    C_GREEN=$'\e[32m'; C_RED=$'\e[31m'; C_YELLOW=$'\e[33m'; C_CYAN=$'\e[36m'
else
    C_RESET=""; C_BOLD=""; C_GREEN=""; C_RED=""; C_YELLOW=""; C_CYAN=""
fi

ok()   { echo "${C_GREEN}✓${C_RESET} $*"; }
err()  { echo "${C_RED}✗${C_RESET} $*"; }
warn() { echo "${C_YELLOW}!${C_RESET} $*"; }
info() { echo "${C_CYAN}➜${C_RESET} $*"; }

# ---------- CLI flags ----------
AUTO_YES=0
INSTALL_MODE=""   # copy | symlink
UI_LANG=""        # uz | en

for arg in "$@"; do
    case "$arg" in
        -y|--yes) AUTO_YES=1 ;;
        --copy) INSTALL_MODE="copy" ;;
        --symlink) INSTALL_MODE="symlink" ;;
        --lang=uz) UI_LANG="uz" ;;
        --lang=en) UI_LANG="en" ;;
        -h|--help)
            echo "Usage: ./install.sh [-y|--yes] [--copy|--symlink] [--lang=uz|en]"
            exit 0
            ;;
        *)
            warn "Noma'lum flag / Unknown flag: $arg"
            ;;
    esac
done

# Non-interactiv rejim uchun defaultlar
if [ "$AUTO_YES" -eq 1 ]; then
    [ -z "$UI_LANG" ] && UI_LANG="en"
    [ -z "$INSTALL_MODE" ] && INSTALL_MODE="copy"
fi

trap 'err "Xatolik / Error: $LINENO-qatorda. Chiqilyapti / Aborting."' ERR

# ---------- Confirm helper ----------
confirm() {
    local prompt="$1"
    [ "$AUTO_YES" -eq 1 ] && return 0
    local reply
    read -rp "$prompt [Y/n]: " reply
    case "$reply" in
        n|N) return 1 ;;
        *) return 0 ;;
    esac
}

# ---------- Translations ----------
declare -A T_UZ=(
    [install]="hyprhub o'rnatilsinmi?"
    [cancel]="Bekor qilindi"
    [missing]="Yetishmayotgan paketlar"
    [installing]="Ular o'rnatilsinmi?"
    [backup]="Backup qilinmoqda"
    [config]="Config fayllar o'rnatilmoqda"
    [scripts]="Skriptlar o'rnatilmoqda"
    [themes]="Temalar o'rnatilmoqda"
    [done]="Tayyor!"
    [mode_q]="O'rnatish usuli"
    [arch_ok]="Arch Linux aniqlandi"
    [arch_fail]="Bu skript faqat Arch Linux uchun ishlaydi"
    [no_aur]="AUR helper (yay/paru) topilmadi. Quyidagi paketlarni qo'lda o'rnating:"
    [reload]="Hyprland qayta yuklandi"
    [path_warn]="OGOHLANTIRISH: hardcoded /home/ yo'li topildi (quyida)"
    [path_ok]="Yo'llar OK"
    [no_backup]="Backup qilish uchun mavjud config topilmadi"
    [no_scripts]="O'rnatish uchun skript topilmadi"
    [no_themes]="O'rnatish uchun tema topilmadi"
)
declare -A T_EN=(
    [install]="Install hyprhub?"
    [cancel]="Cancelled"
    [missing]="Missing packages"
    [installing]="Install them?"
    [backup]="Creating backup"
    [config]="Installing configs"
    [scripts]="Installing scripts"
    [themes]="Installing themes"
    [done]="Finished!"
    [mode_q]="Install mode"
    [arch_ok]="Arch Linux detected"
    [arch_fail]="This installer supports Arch Linux only"
    [no_aur]="No AUR helper (yay/paru) found. Install these manually:"
    [reload]="Hyprland reloaded"
    [path_warn]="WARNING: hardcoded /home/ path found (below)"
    [path_ok]="Paths OK"
    [no_backup]="No existing configs found to back up"
    [no_scripts]="No scripts found to install"
    [no_themes]="No themes found to install"
)

t() {
    if [ "$UI_LANG" = "uz" ]; then echo "${T_UZ[$1]}"; else echo "${T_EN[$1]}"; fi
}

# ---------- Packages (folder tarkibingga mos) ----------
PACKAGES=(
    hyprland waybar kitty rofi-wayland cava wlogout anyrun waypaper swaync
    pipewire wireplumber polkit xdg-desktop-portal-hyprland
    qt5-wayland qt6-wayland gtk3 gtk4
)

# Bular ~/.config ga o'rnatilmaydigan repo papkalari
EXCLUDE_DIRS=(scripts themes screenshots .git .github)

SCRIPTS_DIR="scripts"
THEMES_DIR="themes"

mkdir -p "$(dirname "$LOG_FILE")"

echo "${C_BOLD}=================================="
echo "        hyprhub installer"
echo "        Author: grid"
echo "        Version: $VERSION"
echo "==================================${C_RESET}"
echo

if [ -z "$UI_LANG" ]; then
    echo "1) O'zbekcha"
    echo "2) English"
    echo
    read -rp "Language: " lang_choice
    case "$lang_choice" in
        1) UI_LANG="uz" ;;
        2) UI_LANG="en" ;;
        *) echo "Wrong choice"; exit 1 ;;
    esac
fi

echo
if ! confirm "$(t install)"; then
    echo "$(t cancel)"
    exit 0
fi

echo
echo "[1/7] System check"
if [ -f /etc/arch-release ]; then
    ok "$(t arch_ok)"
else
    err "$(t arch_fail)"
    exit 1
fi

# ---------- Install mode: copy vs symlink ----------
echo
if [ -z "$INSTALL_MODE" ]; then
    read -rp "$(t mode_q) [c=copy / s=symlink] (default: c): " mode_choice
    case "$mode_choice" in
        s|S) INSTALL_MODE="symlink" ;;
        *) INSTALL_MODE="copy" ;;
    esac
fi
info "Install mode: $INSTALL_MODE"

# ---------- Dependency check ----------
echo
echo "[2/7] Dependency check"

AUR_HELPER=""
for h in yay paru trizen pikaur; do
    if command -v "$h" >/dev/null 2>&1; then
        AUR_HELPER="$h"
        break
    fi
done
[ -n "$AUR_HELPER" ] && info "AUR helper: $AUR_HELPER"

MISSING_OFFICIAL=()
MISSING_AUR=()

for pkg in "${PACKAGES[@]}"; do
    if pacman -Q "$pkg" >/dev/null 2>&1; then
        ok "$pkg"
    elif pacman -Si "$pkg" >/dev/null 2>&1; then
        err "$pkg"
        MISSING_OFFICIAL+=("$pkg")
    else
        warn "$pkg (AUR)"
        MISSING_AUR+=("$pkg")
    fi
done

if [ ${#MISSING_OFFICIAL[@]} -gt 0 ] || [ ${#MISSING_AUR[@]} -gt 0 ]; then
    echo
    echo "$(t missing):"
    [ ${#MISSING_OFFICIAL[@]} -gt 0 ] && printf '  %s\n' "${MISSING_OFFICIAL[@]}"
    [ ${#MISSING_AUR[@]} -gt 0 ] && printf '  %s (AUR)\n' "${MISSING_AUR[@]}"
    echo

    if confirm "$(t installing)"; then
        if [ ${#MISSING_OFFICIAL[@]} -gt 0 ]; then
            sudo pacman -S --needed "${MISSING_OFFICIAL[@]}"
        fi
        if [ ${#MISSING_AUR[@]} -gt 0 ]; then
            if [ -n "$AUR_HELPER" ]; then
                "$AUR_HELPER" -S --needed "${MISSING_AUR[@]}"
            else
                warn "$(t no_aur)"
                printf '  %s\n' "${MISSING_AUR[@]}"
            fi
        fi
    else
        warn "Continue without installing packages"
    fi
fi

# ---------- Config papkalarni avtomatik aniqlash ----------
CONFIGS=()
for entry in */; do
    d="${entry%/}"
    skip=0
    for ex in "${EXCLUDE_DIRS[@]}"; do
        [ "$d" = "$ex" ] && skip=1 && break
    done
    [ "$skip" -eq 0 ] && CONFIGS+=("$d")
done

# ---------- Backup ----------
echo
echo "[3/7] $(t backup)"
mkdir -p "$BACKUP_DIR"
backed_up=0
for cfg in "${CONFIGS[@]}"; do
    if [ -e "$HOME/.config/$cfg" ]; then
        cp -rL "$HOME/.config/$cfg" "$BACKUP_DIR/"
        ok "Backup: $cfg"
        backed_up=1
    fi
done
[ "$backed_up" -eq 0 ] && info "$(t no_backup)"

# ---------- Config o'rnatish ----------
echo
echo "[4/7] $(t config)"
mkdir -p "$HOME/.config"
for cfg in "${CONFIGS[@]}"; do
    rm -rf "$HOME/.config/$cfg"
    if [ "$INSTALL_MODE" = "symlink" ]; then
        ln -s "$SCRIPT_DIR/$cfg" "$HOME/.config/$cfg"
    else
        cp -r "$cfg" "$HOME/.config/"
    fi
    ok "Installed: $cfg"
done

# ---------- Scripts ----------
echo
echo "[5/7] $(t scripts)"
mkdir -p "$HOME/.local/bin"
if [ -d "$SCRIPTS_DIR" ] && [ -n "$(ls -A "$SCRIPTS_DIR" 2>/dev/null)" ]; then
    cp -r "$SCRIPTS_DIR/." "$HOME/.local/bin/"
    find "$HOME/.local/bin" -maxdepth 1 -type f -exec chmod +x {} \;
    ok "Scripts -> ~/.local/bin"
else
    info "$(t no_scripts)"
fi

# ---------- Themes ----------
echo
echo "[6/7] $(t themes)"
THEMES_TARGET="$HOME/.local/share/$PROJECT/themes"
if [ -d "$THEMES_DIR" ] && [ -n "$(ls -A "$THEMES_DIR" 2>/dev/null)" ]; then
    mkdir -p "$THEMES_TARGET"
    cp -r "$THEMES_DIR/." "$THEMES_TARGET/"
    ok "Themes -> $THEMES_TARGET"
else
    info "$(t no_themes)"
fi

# ---------- Final check ----------
echo
echo "[7/7] Final check"
if grep -R "/home/" \
    --binary-files=without-match \
    --exclude-dir=.git \
    --exclude=install.sh \
    "$SCRIPT_DIR" >/dev/null 2>&1
then
    warn "$(t path_warn)"
    grep -RIl "/home/" --exclude-dir=.git --exclude=install.sh "$SCRIPT_DIR" || true
else
    ok "$(t path_ok)"
fi

if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    hyprctl reload >/dev/null 2>&1 || true
    ok "$(t reload)"
fi

echo "$(date '+%F %T') - install finished (mode=$INSTALL_MODE, lang=$UI_LANG)" >> "$LOG_FILE"

echo
echo "${C_BOLD}=================================="
echo "$(t done)"
echo
echo "Backup: $BACKUP_DIR"
echo "Log:    $LOG_FILE"
echo "==================================${C_RESET}"#!/usr/bin/env bash
#
# ==================================
# Project: hyprhub
# Author: grid
# Description: Hyprland configuration installer
# ==================================

set -euo pipefail

# ---------- Meta ----------
PROJECT="hyprhub"
VERSION="1.1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

TIMESTAMP="$(date +%F-%H%M)"
BACKUP_DIR="$HOME/.config-backup-$PROJECT-$TIMESTAMP"
LOG_FILE="$HOME/.local/share/$PROJECT/install.log"

# ---------- Colors ----------
if [ -t 1 ]; then
    C_RESET=$'\e[0m'; C_BOLD=$'\e[1m'
    C_GREEN=$'\e[32m'; C_RED=$'\e[31m'; C_YELLOW=$'\e[33m'; C_CYAN=$'\e[36m'
else
    C_RESET=""; C_BOLD=""; C_GREEN=""; C_RED=""; C_YELLOW=""; C_CYAN=""
fi

ok()   { echo "${C_GREEN}✓${C_RESET} $*"; }
err()  { echo "${C_RED}✗${C_RESET} $*"; }
warn() { echo "${C_YELLOW}!${C_RESET} $*"; }
info() { echo "${C_CYAN}➜${C_RESET} $*"; }

# ---------- CLI flags ----------
AUTO_YES=0
INSTALL_MODE=""   # copy | symlink
UI_LANG=""        # uz | en

for arg in "$@"; do
    case "$arg" in
        -y|--yes) AUTO_YES=1 ;;
        --copy) INSTALL_MODE="copy" ;;
        --symlink) INSTALL_MODE="symlink" ;;
        --lang=uz) UI_LANG="uz" ;;
        --lang=en) UI_LANG="en" ;;
        -h|--help)
            echo "Usage: ./install.sh [-y|--yes] [--copy|--symlink] [--lang=uz|en]"
            exit 0
            ;;
        *)
            warn "Noma'lum flag / Unknown flag: $arg"
            ;;
    esac
done

# Non-interactiv rejim uchun defaultlar
if [ "$AUTO_YES" -eq 1 ]; then
    [ -z "$UI_LANG" ] && UI_LANG="en"
    [ -z "$INSTALL_MODE" ] && INSTALL_MODE="copy"
fi

trap 'err "Xatolik / Error: $LINENO-qatorda. Chiqilyapti / Aborting."' ERR

# ---------- Confirm helper ----------
confirm() {
    local prompt="$1"
    [ "$AUTO_YES" -eq 1 ] && return 0
    local reply
    read -rp "$prompt [Y/n]: " reply
    case "$reply" in
        n|N) return 1 ;;
        *) return 0 ;;
    esac
}

# ---------- Translations ----------
declare -A T_UZ=(
    [install]="hyprhub o'rnatilsinmi?"
    [cancel]="Bekor qilindi"
    [missing]="Yetishmayotgan paketlar"
    [installing]="Ular o'rnatilsinmi?"
    [backup]="Backup qilinmoqda"
    [config]="Config fayllar o'rnatilmoqda"
    [scripts]="Skriptlar o'rnatilmoqda"
    [themes]="Temalar o'rnatilmoqda"
    [done]="Tayyor!"
    [mode_q]="O'rnatish usuli"
    [arch_ok]="Arch Linux aniqlandi"
    [arch_fail]="Bu skript faqat Arch Linux uchun ishlaydi"
    [no_aur]="AUR helper (yay/paru) topilmadi. Quyidagi paketlarni qo'lda o'rnating:"
    [reload]="Hyprland qayta yuklandi"
    [path_warn]="OGOHLANTIRISH: hardcoded /home/ yo'li topildi (quyida)"
    [path_ok]="Yo'llar OK"
    [no_backup]="Backup qilish uchun mavjud config topilmadi"
    [no_scripts]="O'rnatish uchun skript topilmadi"
    [no_themes]="O'rnatish uchun tema topilmadi"
)
declare -A T_EN=(
    [install]="Install hyprhub?"
    [cancel]="Cancelled"
    [missing]="Missing packages"
    [installing]="Install them?"
    [backup]="Creating backup"
    [config]="Installing configs"
    [scripts]="Installing scripts"
    [themes]="Installing themes"
    [done]="Finished!"
    [mode_q]="Install mode"
    [arch_ok]="Arch Linux detected"
    [arch_fail]="This installer supports Arch Linux only"
    [no_aur]="No AUR helper (yay/paru) found. Install these manually:"
    [reload]="Hyprland reloaded"
    [path_warn]="WARNING: hardcoded /home/ path found (below)"
    [path_ok]="Paths OK"
    [no_backup]="No existing configs found to back up"
    [no_scripts]="No scripts found to install"
    [no_themes]="No themes found to install"
)

t() {
    if [ "$UI_LANG" = "uz" ]; then echo "${T_UZ[$1]}"; else echo "${T_EN[$1]}"; fi
}

# ---------- Packages (folder tarkibingga mos) ----------
PACKAGES=(
    hyprland waybar kitty rofi-wayland cava wlogout anyrun waypaper swaync
    pipewire wireplumber polkit xdg-desktop-portal-hyprland
    qt5-wayland qt6-wayland gtk3 gtk4
)

# Bular ~/.config ga o'rnatilmaydigan repo papkalari
EXCLUDE_DIRS=(scripts themes screenshots .git .github)

SCRIPTS_DIR="scripts"
THEMES_DIR="themes"

mkdir -p "$(dirname "$LOG_FILE")"

echo "${C_BOLD}=================================="
echo "        hyprhub installer"
echo "        Author: grid"
echo "        Version: $VERSION"
echo "==================================${C_RESET}"
echo

if [ -z "$UI_LANG" ]; then
    echo "1) O'zbekcha"
    echo "2) English"
    echo
    read -rp "Language: " lang_choice
    case "$lang_choice" in
        1) UI_LANG="uz" ;;
        2) UI_LANG="en" ;;
        *) echo "Wrong choice"; exit 1 ;;
    esac
fi

echo
if ! confirm "$(t install)"; then
    echo "$(t cancel)"
    exit 0
fi

echo
echo "[1/7] System check"
if [ -f /etc/arch-release ]; then
    ok "$(t arch_ok)"
else
    err "$(t arch_fail)"
    exit 1
fi

# ---------- Install mode: copy vs symlink ----------
echo
if [ -z "$INSTALL_MODE" ]; then
    read -rp "$(t mode_q) [c=copy / s=symlink] (default: c): " mode_choice
    case "$mode_choice" in
        s|S) INSTALL_MODE="symlink" ;;
        *) INSTALL_MODE="copy" ;;
    esac
fi
info "Install mode: $INSTALL_MODE"

# ---------- Dependency check ----------
echo
echo "[2/7] Dependency check"

AUR_HELPER=""
for h in yay paru trizen pikaur; do
    if command -v "$h" >/dev/null 2>&1; then
        AUR_HELPER="$h"
        break
    fi
done
[ -n "$AUR_HELPER" ] && info "AUR helper: $AUR_HELPER"

MISSING_OFFICIAL=()
MISSING_AUR=()

for pkg in "${PACKAGES[@]}"; do
    if pacman -Q "$pkg" >/dev/null 2>&1; then
        ok "$pkg"
    elif pacman -Si "$pkg" >/dev/null 2>&1; then
        err "$pkg"
        MISSING_OFFICIAL+=("$pkg")
    else
        warn "$pkg (AUR)"
        MISSING_AUR+=("$pkg")
    fi
done

if [ ${#MISSING_OFFICIAL[@]} -gt 0 ] || [ ${#MISSING_AUR[@]} -gt 0 ]; then
    echo
    echo "$(t missing):"
    [ ${#MISSING_OFFICIAL[@]} -gt 0 ] && printf '  %s\n' "${MISSING_OFFICIAL[@]}"
    [ ${#MISSING_AUR[@]} -gt 0 ] && printf '  %s (AUR)\n' "${MISSING_AUR[@]}"
    echo

    if confirm "$(t installing)"; then
        if [ ${#MISSING_OFFICIAL[@]} -gt 0 ]; then
            sudo pacman -S --needed "${MISSING_OFFICIAL[@]}"
        fi
        if [ ${#MISSING_AUR[@]} -gt 0 ]; then
            if [ -n "$AUR_HELPER" ]; then
                "$AUR_HELPER" -S --needed "${MISSING_AUR[@]}"
            else
                warn "$(t no_aur)"
                printf '  %s\n' "${MISSING_AUR[@]}"
            fi
        fi
    else
        warn "Continue without installing packages"
    fi
fi

# ---------- Config papkalarni avtomatik aniqlash ----------
CONFIGS=()
for entry in */; do
    d="${entry%/}"
    skip=0
    for ex in "${EXCLUDE_DIRS[@]}"; do
        [ "$d" = "$ex" ] && skip=1 && break
    done
    [ "$skip" -eq 0 ] && CONFIGS+=("$d")
done

# ---------- Backup ----------
echo
echo "[3/7] $(t backup)"
mkdir -p "$BACKUP_DIR"
backed_up=0
for cfg in "${CONFIGS[@]}"; do
    if [ -e "$HOME/.config/$cfg" ]; then
        cp -rL "$HOME/.config/$cfg" "$BACKUP_DIR/"
        ok "Backup: $cfg"
        backed_up=1
    fi
done
[ "$backed_up" -eq 0 ] && info "$(t no_backup)"

# ---------- Config o'rnatish ----------
echo
echo "[4/7] $(t config)"
mkdir -p "$HOME/.config"
for cfg in "${CONFIGS[@]}"; do
    rm -rf "$HOME/.config/$cfg"
    if [ "$INSTALL_MODE" = "symlink" ]; then
        ln -s "$SCRIPT_DIR/$cfg" "$HOME/.config/$cfg"
    else
        cp -r "$cfg" "$HOME/.config/"
    fi
    ok "Installed: $cfg"
done

# ---------- Scripts ----------
echo
echo "[5/7] $(t scripts)"
mkdir -p "$HOME/.local/bin"
if [ -d "$SCRIPTS_DIR" ] && [ -n "$(ls -A "$SCRIPTS_DIR" 2>/dev/null)" ]; then
    cp -r "$SCRIPTS_DIR/." "$HOME/.local/bin/"
    find "$HOME/.local/bin" -maxdepth 1 -type f -exec chmod +x {} \;
    ok "Scripts -> ~/.local/bin"
else
    info "$(t no_scripts)"
fi

# ---------- Themes ----------
echo
echo "[6/7] $(t themes)"
THEMES_TARGET="$HOME/.local/share/$PROJECT/themes"
if [ -d "$THEMES_DIR" ] && [ -n "$(ls -A "$THEMES_DIR" 2>/dev/null)" ]; then
    mkdir -p "$THEMES_TARGET"
    cp -r "$THEMES_DIR/." "$THEMES_TARGET/"
    ok "Themes -> $THEMES_TARGET"
else
    info "$(t no_themes)"
fi

# ---------- Final check ----------
echo
echo "[7/7] Final check"
if grep -R "/home/" \
    --binary-files=without-match \
    --exclude-dir=.git \
    --exclude=install.sh \
    "$SCRIPT_DIR" >/dev/null 2>&1
then
    warn "$(t path_warn)"
    grep -RIl "/home/" --exclude-dir=.git --exclude=install.sh "$SCRIPT_DIR" || true
else
    ok "$(t path_ok)"
fi

if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    hyprctl reload >/dev/null 2>&1 || true
    ok "$(t reload)"
fi

echo "$(date '+%F %T') - install finished (mode=$INSTALL_MODE, lang=$UI_LANG)" >> "$LOG_FILE"

echo
echo "${C_BOLD}=================================="
echo "$(t done)"
echo
echo "Backup: $BACKUP_DIR"
echo "Log:    $LOG_FILE"
echo "==================================${C_RESET}"
