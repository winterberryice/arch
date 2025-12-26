#!/bin/bash
# phases/01-prepare.sh - Preparation and requirements check
# Part of omarchy fork installer

ui_section "Preparation"

# Check requirements
check_root
check_uefi
check_network

# Update system clock
info "Updating system clock..."
timedatectl set-ntp true
sleep 2

# Detect hardware
detect_all_hardware

# Show configuration
ui_section "Installation Configuration"
echo "Timezone:  $TIMEZONE"
echo "Locale:    $LOCALE"
echo "Hostname:  $HOSTNAME"
echo "Username:  $USERNAME"
echo ""

info "Preparation complete"
