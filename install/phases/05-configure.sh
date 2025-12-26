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

# Check if NVIDIA (need special modules)
HAS_NVIDIA=$(cat /tmp/arch-install/has_nvidia 2>/dev/null || echo "false")

if [[ "$HAS_NVIDIA" == "true" ]]; then
    info "Adding NVIDIA modules to mkinitcpio..."
    sed -i 's/^MODULES=.*/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
fi

# Update hooks (no encrypt for Phase 0)
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)/' /etc/mkinitcpio.conf

# Rebuild initramfs
info "Building initramfs..."
mkinitcpio -P

# Enable services
info "Enabling system services..."
systemctl enable NetworkManager.service
systemctl enable cosmic-greeter.service

# Enable PipeWire for user
info "Enabling PipeWire audio for $USERNAME..."
sudo -u "$USERNAME" systemctl --user enable pipewire.service
sudo -u "$USERNAME" systemctl --user enable pipewire-pulse.service
sudo -u "$USERNAME" systemctl --user enable wireplumber.service

success "System configuration complete"
