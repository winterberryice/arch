#!/bin/bash
# lib/ui.sh - User interface functions
# Part of omarchy fork installer
# Phase 0: Simple output functions (no gum yet)

ui_header() {
    echo ""
    echo "========================================="
    echo "$*"
    echo "========================================="
    echo ""
}

ui_section() {
    echo ""
    echo "--- $* ---"
    echo ""
}

ui_info() {
    echo -e "\033[0;34mℹ\033[0m $*"
}

ui_success() {
    echo -e "\033[0;32m✅\033[0m $*"
}

ui_warn() {
    echo -e "\033[0;33m⚠\033[0m $*"
}

ui_error() {
    echo -e "\033[0;31m❌\033[0m $*"
}

ui_progress() {
    local current=$1
    local total=$2
    local description=$3

    echo -e "\033[1;36m[$current/$total]\033[0m $description"
}

show_welcome() {
    ui_header "Arch Linux Installer (omarchy fork)"
    echo "Phase 0 MVP - QEMU Testing"
    echo ""
    echo "Features:"
    echo "  • Automated installation (no prompts)"
    echo "  • BTRFS with subvolumes"
    echo "  • systemd-boot"
    echo "  • COSMIC desktop"
    echo "  • Hardware auto-detection"
    echo ""
    echo "⚠  WARNING: This will WIPE the first detected disk!"
    echo ""
    sleep 3
}

show_success_message() {
    ui_header "Installation Complete!"
    echo ""
    echo "Your system has been installed successfully."
    echo ""
    echo "Default credentials (CHANGE ON FIRST LOGIN):"
    echo "  Username: $USERNAME"
    echo "  Password: $USER_PASSWORD"
    echo "  Root password: $ROOT_PASSWORD"
    echo ""
    echo "Next steps:"
    echo "  1. Type 'reboot' to restart"
    echo "  2. Remove installation media"
    echo "  3. Change default passwords immediately"
    echo ""
    success "Installation complete!"
}
