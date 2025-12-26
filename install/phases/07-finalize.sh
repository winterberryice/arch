#!/bin/bash
# phases/07-finalize.sh - Final setup (runs in chroot)
# Part of omarchy fork installer

ui_section "Finalization (chroot)"

# Configure zram
info "Setting up zram..."
cat > /etc/systemd/zram-generator.conf <<EOF
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF

# Create swapfile on @swap subvolume
info "Creating swapfile (16GB)..."

# Ensure @swap is mounted at /swap
if [[ ! -d /swap ]]; then
    warn "/swap directory not found, creating..."
    mkdir -p /swap
fi

# Create swapfile
dd if=/dev/zero of=/swap/swapfile bs=1M count=16384 status=progress
chmod 600 /swap/swapfile
mkswap /swap/swapfile

# Add to fstab
if ! grep -q "/swap/swapfile" /etc/fstab; then
    echo "/swap/swapfile none swap defaults 0 0" >> /etc/fstab
    info "Added swapfile to fstab"
fi

# Note: Don't activate swap in chroot, will activate on first boot

# Create initial BTRFS snapshots (optional, requires snapper)
if command -v snapper &>/dev/null; then
    info "Setting up snapper..."
    snapper -c root create-config /
    snapper -c home create-config /home
    snapper -c root create -d "Fresh install - Phase 0"
    snapper -c home create -d "Fresh install - Phase 0"
    info "Created initial snapshots"
else
    warn "snapper not installed, skipping snapshot creation"
    info "Install snapper later with: sudo pacman -S snapper"
fi

# Create warning file about default passwords
info "Creating password warning file..."
cat > /home/${USERNAME}/CHANGE_PASSWORDS.txt <<EOF
⚠️  IMPORTANT - CHANGE DEFAULT PASSWORDS ⚠️

This system was installed with default passwords for testing.
YOU MUST CHANGE THEM IMMEDIATELY!

Current credentials:
  Username: ${USERNAME}
  Password: ${USER_PASSWORD}
  Root password: ${ROOT_PASSWORD}

To change passwords:
  1. Change user password: passwd
  2. Change root password: sudo passwd root
  3. Delete this file: rm ~/CHANGE_PASSWORDS.txt

DO NOT use this system in production without changing passwords!
EOF

chown ${USERNAME}:${USERNAME} /home/${USERNAME}/CHANGE_PASSWORDS.txt

success "Finalization complete"
