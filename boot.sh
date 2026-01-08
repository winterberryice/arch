#!/bin/bash
# Wintarch Installer Bootstrap
# Usage: curl -fsSL https://raw.githubusercontent.com/YOUR_USER/arch/master/boot.sh | bash
#
# Environment variables:
#   WINTARCH_REPO - GitHub repo (default: YOUR_USER/arch)
#   WINTARCH_REF  - Branch/tag to use (default: master)

set -e

# ASCII art logo
logo='
 █     █░ ██▓ ███▄    █ ▄▄▄█████▓ ▄▄▄       ██▀███   ▄████▄   ██░ ██
▓█░ █ ░█░▓██▒ ██ ▀█   █ ▓  ██▒ ▓▒▒████▄    ▓██ ▒ ██▒▒██▀ ▀█  ▓██░ ██▒
▒█░ █ ░█ ▒██▒▓██  ▀█ ██▒▒ ▓██░ ▒░▒██  ▀█▄  ▓██ ░▄█ ▒▒▓█    ▄ ▒██▀▀██░
░█░ █ ░█ ░██░▓██▒  ▐▌██▒░ ▓██▓ ░ ░██▄▄▄▄██ ▒██▀▀█▄  ▒▓▓▄ ▄██▒░▓█ ░██
░░██▒██▓ ░██░▒██░   ▓██░  ▒██▒ ░  ▓█   ▓██▒░██▓ ▒██▒▒ ▓███▀ ░░▓█▒░██▓
░ ▓░▒ ▒  ░▓  ░ ▒░   ▒ ▒   ▒ ░░    ▒▒   ▓▒█░░ ▒▓ ░▒▓░░ ░▒ ▒  ░ ▒ ░░▒░▒
  ▒ ░ ░   ▒ ░░ ░░   ░ ▒░    ░      ▒   ▒▒ ░  ░▒ ░ ▒░  ░  ▒    ▒ ░▒░ ░
  ░   ░   ▒ ░   ░   ░ ░   ░        ░   ▒     ░░   ░ ░         ░  ░░ ░
    ░     ░           ░                ░  ░   ░     ░ ░       ░  ░  ░
                                                    ░
              Arch Linux COSMIC Edition Installer
'

clear
echo -e "\e[36m$logo\e[0m"
echo ""

# Install git if needed
echo ":: Installing git..."
sudo pacman -Sy --noconfirm --needed git

# Configuration
WINTARCH_REPO="${WINTARCH_REPO:-winterberryice/arch}"
WINTARCH_REF="${WINTARCH_REF:-master}"
INSTALL_DIR="/tmp/wintarch-installer"

# Clone repository
echo ""
echo ":: Cloning wintarch from https://github.com/${WINTARCH_REPO}..."
rm -rf "$INSTALL_DIR"
git clone "https://github.com/${WINTARCH_REPO}.git" "$INSTALL_DIR"

# Switch branch if specified
if [[ "$WINTARCH_REF" != "master" ]]; then
    echo ":: Using branch/tag: $WINTARCH_REF"
    cd "$INSTALL_DIR"
    git fetch origin "$WINTARCH_REF" && git checkout "$WINTARCH_REF"
fi

# Run installer
echo ""
echo ":: Starting installation..."
cd "$INSTALL_DIR"
bash ./install/install.sh
