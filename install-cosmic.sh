#!/bin/bash
# install-cosmic.sh - Install COSMIC desktop from AUR
# Run this after base system installation completes
# Usage: bash install-cosmic.sh

set -e

echo "========================================="
echo "COSMIC Desktop Installation"
echo "========================================="
echo ""
echo "This will install:"
echo "  - yay (AUR helper)"
echo "  - cosmic-session (COSMIC desktop)"
echo "  - cosmic-greeter (display manager)"
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

# Install base-devel if not already installed
echo "Installing base-devel..."
sudo pacman -S --needed base-devel git

# Install yay
if ! command -v yay &>/dev/null; then
    echo "Installing yay AUR helper..."
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ..
    rm -rf yay
fi

# Install COSMIC
echo "Installing COSMIC (this will take 10-30 minutes)..."
echo "Note: cosmic-applets needs 8GB+ RAM to build"

# Set environment for building (reduce memory usage)
export MOLD_JOBS=1
export CARGO_TARGET_DIR=/tmp/cosmic-build

# Install cosmic-session (includes most components)
yay -S --needed cosmic-session

# Enable cosmic-greeter
echo "Enabling COSMIC greeter..."
sudo systemctl enable cosmic-greeter.service

echo ""
echo "========================================="
echo "✅ COSMIC Installation Complete!"
echo "========================================="
echo ""
echo "Reboot to use COSMIC desktop"
echo ""
