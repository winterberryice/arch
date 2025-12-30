#!/bin/bash
# phases/05-configure.sh - System configuration (runs in chroot)
# Part of omarchy fork installer

ui_section "System Configuration (chroot)"

# Timezone
info "Setting timezone to $TIMEZONE..."
ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
hwclock --systohc
timedatectl set-ntp true

# Locale
info "Configuring locale ($LOCALE)..."
sed -i "s/^#${LOCALE}/${LOCALE}/" /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf

# Keyboard
info "Configuring keyboard layout ($KEYBOARD)..."
echo "KEYMAP=${KEYBOARD}" > /etc/vconsole.conf

# Hostname
info "Setting hostname to $HOSTNAME..."
echo "$HOSTNAME" > /etc/hostname

# Create hosts file
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

# Set root password
info "Setting root password..."
echo "root:${ROOT_PASSWORD}" | chpasswd

# Create user
info "Creating user $USERNAME..."
useradd -m -G wheel,audio,video,storage,optical,power -s /bin/bash "$USERNAME"
echo "${USERNAME}:${USER_PASSWORD}" | chpasswd

# Configure sudo
info "Configuring sudo for wheel group..."
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
chmod 0440 /etc/sudoers.d/wheel

# Configure mkinitcpio
info "Configuring mkinitcpio..."

# Check if NVIDIA (passed as env var from outside chroot)
# HAS_NVIDIA is already set as an environment variable

if [[ "$HAS_NVIDIA" == "true" ]]; then
    info "Adding NVIDIA modules to mkinitcpio..."
    sed -i 's/^MODULES=.*/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
fi

# Update hooks (add encrypt and btrfs-overlayfs hooks)
if [[ "$ENABLE_ENCRYPTION" == "true" ]]; then
    info "Adding encrypt and btrfs-overlayfs hooks for LUKS + snapshots..."
    # Hooks order: base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck btrfs-overlayfs
    # keyboard/keymap MUST come before encrypt (to type password)
    # encrypt MUST come before filesystems (to unlock before mount)
    # btrfs-overlayfs MUST come after filesystems (for snapshot support)
    sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck btrfs-overlayfs)/' /etc/mkinitcpio.conf
else
    info "Adding btrfs-overlayfs hook for snapshot support..."
    sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck btrfs-overlayfs)/' /etc/mkinitcpio.conf
fi

# Rebuild initramfs
info "Building initramfs..."
mkinitcpio -P

# Enable services
info "Enabling system services..."
systemctl enable NetworkManager.service
systemctl enable cosmic-greeter.service

# Note: PipeWire user services will auto-start on first login via systemd user presets
# No need to manually enable during installation (would fail in chroot anyway)

success "System configuration complete"
