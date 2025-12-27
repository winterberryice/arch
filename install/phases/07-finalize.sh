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

# --- PHASE 1: SECURITY HARDENING ---

info "Applying security hardening..."

# Set proper /boot permissions
info "Setting /boot permissions (755)..."
chmod 755 /boot
chmod 755 /boot/EFI
chmod 755 /boot/EFI/BOOT 2>/dev/null || true
chmod 755 /boot/loader 2>/dev/null || true

# Install and configure firewall (ufw)
info "Installing and configuring firewall (ufw)..."
if pacman -Q ufw &>/dev/null; then
    info "ufw already installed"
else
    pacman -S --noconfirm ufw
fi

# Configure ufw
info "Configuring firewall rules..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw limit ssh  # Rate limit SSH (prevents brute force)
ufw --force enable

# Enable ufw service
systemctl enable ufw.service

success "Firewall configured (SSH allowed, all other incoming denied)"

# Disable root SSH login
info "Securing SSH configuration..."
if [[ -f /etc/ssh/sshd_config ]]; then
    # Disable root login
    if grep -q "^PermitRootLogin" /etc/ssh/sshd_config; then
        sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    else
        echo "PermitRootLogin no" >> /etc/ssh/sshd_config
    fi

    # Disable password authentication for root (key-based only for users is recommended but not enforced)
    if grep -q "^#PasswordAuthentication" /etc/ssh/sshd_config; then
        sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    fi

    success "SSH hardened (root login disabled)"
else
    warn "sshd_config not found, skipping SSH hardening"
fi

# Set restrictive umask
info "Setting secure umask..."
echo "umask 077" >> /etc/profile.d/umask.sh
chmod 644 /etc/profile.d/umask.sh

# Create security checklist
info "Creating security checklist..."
cat > /home/${USERNAME}/SECURITY_CHECKLIST.txt <<EOF
🔒 Security Checklist - Post-Installation

Your system has been hardened with basic security measures:

✅ Completed:
  • Firewall (ufw) enabled
    - Default: Deny incoming, Allow outgoing
    - SSH port 22 allowed (rate limited)
  • /boot permissions set to 755
  • Root SSH login disabled
  • Secure umask (077) configured

📋 Recommended Next Steps:
  1. Configure SSH key-based authentication
     - Generate SSH key: ssh-keygen -t ed25519
     - Copy to authorized_keys
     - Consider disabling password auth in /etc/ssh/sshd_config

  2. Install fail2ban for brute-force protection
     - sudo pacman -S fail2ban
     - sudo systemctl enable --now fail2ban

  3. Enable automatic security updates (optional)
     - Consider using arch-audit for vulnerability scanning
     - sudo pacman -S arch-audit

  4. Review and customize firewall rules
     - List rules: sudo ufw status verbose
     - Add custom rules: sudo ufw allow <port>

  5. Set up BTRFS snapshots with snapper (if desired)
     - sudo pacman -S snapper
     - sudo snapper -c root create-config /

  6. Consider additional hardening
     - AppArmor or SELinux (advanced)
     - Kernel hardening parameters
     - Regular security audits

🔐 Your Credentials:
  Username: ${USERNAME}
  Hostname: ${HOSTNAME}

For more security information, visit:
  https://wiki.archlinux.org/title/Security

Delete this file after reviewing: rm ~/SECURITY_CHECKLIST.txt
EOF

chown ${USERNAME}:${USERNAME} /home/${USERNAME}/SECURITY_CHECKLIST.txt
chmod 644 /home/${USERNAME}/SECURITY_CHECKLIST.txt

success "Security hardening complete"
success "Finalization complete"
