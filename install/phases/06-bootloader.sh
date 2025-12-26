#!/bin/bash
# phases/06-bootloader.sh - systemd-boot installation (runs in chroot)
# Part of omarchy fork installer
# Based on docs/004-systemd-boot.md

ui_section "Bootloader Installation (chroot)"

# Install systemd-boot
info "Installing systemd-boot..."
bootctl install

# Create loader configuration
info "Creating loader configuration..."
cat > /boot/loader/loader.conf <<EOF
default  arch.conf
timeout  3
console-mode max
editor   no
EOF

# Get partition UUID
BTRFS_PARTITION=$(cat /tmp/arch-install/btrfs_partition)
PARTUUID=$(blkid -s PARTUUID -o value "$BTRFS_PARTITION")

if [[ -z "$PARTUUID" ]]; then
    warn "Could not get PARTUUID, using device path"
    ROOT_PARAM="root=${BTRFS_PARTITION}"
else
    ROOT_PARAM="root=PARTUUID=${PARTUUID}"
fi

# Detect microcode
MICROCODE=$(cat /tmp/arch-install/microcode 2>/dev/null || echo "")

# Build kernel parameters
KERNEL_PARAMS="${ROOT_PARAM} rootflags=subvol=@ rw"

# Add NVIDIA parameters if needed
HAS_NVIDIA=$(cat /tmp/arch-install/has_nvidia 2>/dev/null || echo "false")
if [[ "$HAS_NVIDIA" == "true" ]]; then
    KERNEL_PARAMS="${KERNEL_PARAMS} nvidia_drm.modeset=1"
    info "Added NVIDIA kernel parameters"
fi

# Create main boot entry
info "Creating main boot entry..."
cat > /boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux
EOF

# Add microcode if available
if [[ -n "$MICROCODE" ]]; then
    echo "initrd  /${MICROCODE}.img" >> /boot/loader/entries/arch.conf
    info "Added microcode: $MICROCODE"
fi

# Add main initramfs
cat >> /boot/loader/entries/arch.conf <<EOF
initrd  /initramfs-linux.img
options ${KERNEL_PARAMS}
EOF

# Create fallback boot entry
info "Creating fallback boot entry..."
cat > /boot/loader/entries/arch-fallback.conf <<EOF
title   Arch Linux (Fallback)
linux   /vmlinuz-linux
EOF

if [[ -n "$MICROCODE" ]]; then
    echo "initrd  /${MICROCODE}.img" >> /boot/loader/entries/arch-fallback.conf
fi

cat >> /boot/loader/entries/arch-fallback.conf <<EOF
initrd  /initramfs-linux-fallback.img
options ${KERNEL_PARAMS}
EOF

# Show boot entries
info "Boot entries created:"
cat /boot/loader/entries/arch.conf
echo ""

# Verify bootloader status
info "Bootloader status:"
bootctl status || true

success "systemd-boot installed successfully"
