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
    # Try reflector with retries (network can be flaky)
    local max_attempts=3
    local attempt=1
    local success_flag=false

    while [[ $attempt -le $max_attempts ]]; do
        if [[ $attempt -gt 1 ]]; then
            info "Retry attempt $attempt/$max_attempts..."
            sleep 2
        fi

        if reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist 2>&1 | tee -a "$LOG_FILE"; then
            success_flag=true
            break
        fi

        ((attempt++))
    done

    if [[ "$success_flag" == true ]]; then
        success "Mirrors optimized for faster downloads"
    else
        warn "Mirror optimization failed after $max_attempts attempts, using default mirrors"
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
