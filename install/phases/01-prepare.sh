#!/bin/bash
# phases/01-prepare.sh - Preparation and requirements check
# Part of omarchy fork installer

ui_section "Preparation"

# Check requirements
check_root
check_uefi
check_network

# Optimize mirrors for faster downloads
info "Optimizing package mirrors (this may take 30-60 seconds)..."
if pacman -Sy --noconfirm reflector &>/dev/null; then
    if reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist 2>&1 | tee -a "$LOG_FILE"; then
        success "Mirrors optimized for faster downloads"
    else
        warn "Mirror optimization failed, using default mirrors"
    fi
else
    warn "reflector not available, using default mirrors"
fi

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
