#!/bin/bash
# Wintarch Installer Bootstrap
# Usage: curl -fsSL https://raw.githubusercontent.com/winterberryice/arch/master/boot.sh | bash
#
# Environment variables:
#   WINTARCH_REPO - GitHub repo (default: winterberryice/arch)
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

# Optimize mirrors with reflector (retry up to 3 times)
echo ":: Optimizing mirrors..."
for i in 1 2 3; do
    if reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist; then
        echo "   Mirrors updated successfully"
        break
    else
        if [[ $i -lt 3 ]]; then
            echo "   Attempt $i failed, retrying in 2s..."
            sleep 2
        else
            echo "   Mirror optimization failed, using defaults"
        fi
    fi
done

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
