#!/bin/bash
# phases/04-install.sh - Base system installation (pacstrap)
# Part of omarchy fork installer

ui_section "Base System Installation"

# Load hardware detection results
MICROCODE=$(load_state "microcode")
GPU_PACKAGES_STR=$(load_state "gpu_packages")
read -ra GPU_PACKAGES <<< "$GPU_PACKAGES_STR"

# Build package list
info "Building package list..."

BASE_PACKAGES=(
    base
    linux
    linux-firmware
    btrfs-progs
    networkmanager
    sudo
    vim
    git
)

# Add microcode
if [[ -n "$MICROCODE" ]]; then
    BASE_PACKAGES+=("$MICROCODE")
    info "Added microcode: $MICROCODE"
fi

# Add GPU drivers
if [[ ${#GPU_PACKAGES[@]} -gt 0 ]]; then
    BASE_PACKAGES+=("${GPU_PACKAGES[@]}")
    info "Added GPU drivers: ${GPU_PACKAGES[*]}"
fi

# Desktop environment packages
DESKTOP_PACKAGES=(
    cosmic-epoch
    cosmic-greeter
    pipewire
    pipewire-pulse
    pipewire-alsa
    pipewire-jack
    wireplumber
)

# Combine all packages
ALL_PACKAGES=("${BASE_PACKAGES[@]}" "${DESKTOP_PACKAGES[@]}")

# Display package summary
info "Installing ${#ALL_PACKAGES[@]} packages..."
echo "Base packages: ${#BASE_PACKAGES[@]}"
echo "Desktop packages: ${#DESKTOP_PACKAGES[@]}"
echo ""

# Update pacman mirrors for speed (optional, can be slow)
# info "Updating mirrorlist..."
# reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# Run pacstrap
info "Running pacstrap (this may take 10-20 minutes)..."
if ! pacstrap -K /mnt "${ALL_PACKAGES[@]}"; then
    error "pacstrap failed"
    exit 1
fi

success "Base system installed"

# Generate fstab
info "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Verify fstab
info "Generated fstab:"
cat /mnt/etc/fstab

success "Base installation complete"
