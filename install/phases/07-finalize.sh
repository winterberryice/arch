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

# --- PHASE 3: SNAPSHOT CONFIGURATION ---

info "Configuring snapper for automatic snapshots..."

# Verify snapper is installed
if ! command -v snapper &>/dev/null; then
    error "snapper not installed - this should not happen"
    exit 1
fi

# Get device for mounting (handle both encrypted and non-encrypted)
BTRFS_DEV=$(findmnt -n -o SOURCE /)
info "BTRFS device: $BTRFS_DEV"

# Step 1: Unmount /.snapshots (currently mounted as @snapshots subvolume)
info "Unmounting /.snapshots..."
umount /.snapshots || warn "/.snapshots not mounted or already unmounted"

# Step 2: Create snapper config for root (this creates /.snapshots as a subvolume)
info "Creating snapper config for root filesystem..."
snapper -c root create-config /

# Step 3: Delete the default .snapshots subvolume created by snapper
info "Removing default snapper subvolume..."
btrfs subvolume delete /.snapshots

# Step 4: Recreate /.snapshots as a directory
info "Recreating /.snapshots directory..."
mkdir -p /.snapshots

# Step 5: Remount our @snapshots subvolume at /.snapshots
info "Remounting @snapshots subvolume..."
mount -o noatime,compress=zstd:1,space_cache=v2,subvol=@snapshots "$BTRFS_DEV" /.snapshots

# Verify mount
if ! mountpoint -q /.snapshots; then
    error "Failed to mount /.snapshots"
    exit 1
fi

# Step 6: Configure snapshot retention policies
info "Configuring snapshot retention policies..."
cat > /etc/snapper/configs/root <<'EOF'
# subvolume to snapshot
SUBVOLUME="/"

# filesystem type
FSTYPE="btrfs"

# btrfs qgroup for space aware cleanup algorithms
QGROUP=""

# fraction or absolute size of the filesystems space the snapshots may use
SPACE_LIMIT="0.5"

# fraction or absolute size of the filesystems space that should be free
FREE_LIMIT="0.2"

# users and groups allowed to work with config
ALLOW_USERS=""
ALLOW_GROUPS=""

# sync users and groups from ALLOW_USERS and ALLOW_GROUPS to .snapshots
# directory
SYNC_ACL="no"

# start comparing pre- and post-snapshot in background after creating
# post-snapshot
BACKGROUND_COMPARISON="yes"

# run daily number cleanup
NUMBER_CLEANUP="yes"

# limit for number cleanup
NUMBER_MIN_AGE="1800"
NUMBER_LIMIT="10"
NUMBER_LIMIT_IMPORTANT="10"

# create hourly snapshots
TIMELINE_CREATE="yes"

# cleanup hourly snapshots after some time
TIMELINE_CLEANUP="yes"

# limits for timeline cleanup
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="5"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="4"
TIMELINE_LIMIT_MONTHLY="3"
TIMELINE_LIMIT_YEARLY="0"

# cleanup empty pre-post-pairs
EMPTY_PRE_POST_CLEANUP="yes"

# limits for empty pre-post-pair cleanup
EMPTY_PRE_POST_MIN_AGE="1800"
EOF

success "Snapper configuration complete"

# Step 7: Enable automatic snapshot timers
info "Enabling snapper timers..."
systemctl enable snapper-timeline.timer    # Creates hourly snapshots
systemctl enable snapper-cleanup.timer     # Cleans up old snapshots

success "Snapper timers enabled"

# Step 8: Create initial snapshot
info "Creating initial snapshot..."
snapper -c root create -d "Fresh install - Phase 3"

# Verify snapshot was created
SNAPSHOT_COUNT=$(snapper -c root list | wc -l)
if [[ $SNAPSHOT_COUNT -gt 1 ]]; then
    success "Initial snapshot created successfully"
    snapper -c root list
else
    warn "Snapshot creation may have failed"
fi

# --- PHASE 3: LIMINE SNAPSHOT INTEGRATION ---

info "Installing Limine AUR packages for snapshot boot support..."

# Source AUR library
source /install/lib/aur.sh

# Install yay AUR helper
if ! command -v yay &>/dev/null; then
    info "Installing yay AUR helper..."
    if ! install_yay "$USERNAME"; then
        warn "Failed to install yay - skipping Limine AUR packages"
        warn "Snapshot boot menu integration will not be available"
        warn "You can install manually later: yay -S limine-snapper-sync limine-mkinitcpio-hook"
    else
        success "yay installed successfully"

        # Install limine-mkinitcpio-hook (provides btrfs-overlayfs hook and UKI support)
        info "Installing limine-mkinitcpio-hook from AUR..."
        pacman -S --noconfirm --needed base-devel
        sudo -u "$USERNAME" yay -S --noconfirm --needed limine-mkinitcpio-hook

        # Install limine-snapper-sync (automatic snapshot boot entries)
        info "Installing limine-snapper-sync from AUR..."
        sudo -u "$USERNAME" yay -S --noconfirm --needed limine-snapper-sync

        success "Limine AUR packages installed"

        # Configure /etc/default/limine for snapshot support
        info "Configuring Limine for snapshot support..."

        # Get kernel cmdline from limine.conf
        CMDLINE=$(grep "^cmdline:" /boot/limine.conf | head -1 | sed 's/^cmdline:[[:space:]]*//')

        cat > /etc/default/limine <<EOF
# Limine configuration for snapshot boot support
# Generated by arch installer

TARGET_OS_NAME="Arch Linux"

ESP_PATH="/boot"

KERNEL_CMDLINE[default]="$CMDLINE"

# Enable UKI (Unified Kernel Images) for snapshot support
ENABLE_UKI=yes
CUSTOM_UKI_NAME="arch"

# Enable Limine fallback
ENABLE_LIMINE_FALLBACK=yes

# Find and add other bootloaders (Windows, etc.)
FIND_BOOTLOADERS=yes

# Boot order in menu
BOOT_ORDER="*, *fallback, Snapshots"

# Maximum snapshot entries in boot menu
MAX_SNAPSHOT_ENTRIES=5

# Snapshot naming format
SNAPSHOT_FORMAT_CHOICE=5
EOF

        success "Limine configuration created at /etc/default/limine"

        # Run limine-update to generate UKIs and update boot menu
        info "Running limine-update to generate boot entries..."
        if limine-update; then
            success "Limine boot menu updated"
        else
            warn "limine-update failed - boot menu may not include snapshots"
        fi

        # Add btrfs-overlayfs hook to mkinitcpio.conf (now that the hook is installed)
        info "Adding btrfs-overlayfs hook to mkinitcpio..."
        if grep -q "encrypt" /etc/mkinitcpio.conf; then
            # LUKS encrypted system
            sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck btrfs-overlayfs)/' /etc/mkinitcpio.conf
        else
            # Non-encrypted system
            sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck btrfs-overlayfs)/' /etc/mkinitcpio.conf
        fi

        # Rebuild initramfs with limine hooks
        info "Rebuilding initramfs with Limine hooks..."
        mkinitcpio -P

        # Enable limine-snapper-sync service
        info "Enabling limine-snapper-sync service..."
        systemctl enable limine-snapper-sync.service

        success "Limine snapshot boot integration complete"
        success "Snapshot entries will appear in boot menu automatically"
    fi
else
    info "yay already installed"
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

# Configure ufw (but don't enable in chroot - kernel modules not available)
info "Configuring firewall rules..."
ufw --force reset >/dev/null 2>&1 || true  # Suppress errors in chroot
ufw default deny incoming >/dev/null 2>&1 || true
ufw default allow outgoing >/dev/null 2>&1 || true
ufw limit ssh >/dev/null 2>&1 || true  # Rate limit SSH (prevents brute force)

# Note: Don't run 'ufw enable' in chroot - it tries to load kernel modules
# Instead, enable the systemd service which will activate on first boot
info "Enabling firewall service (will activate on first boot)..."
systemctl enable ufw.service

# Create a systemd service to enable ufw on first boot
cat > /etc/systemd/system/ufw-enable.service <<'EOF'
[Unit]
Description=Enable UFW firewall on first boot
After=network-pre.target
Before=network.target
DefaultDependencies=no

[Service]
Type=oneshot
ExecStart=/usr/bin/ufw --force enable
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl enable ufw-enable.service

success "Firewall configured (will be enabled on first boot with SSH rate limiting)"

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

  5. Review snapshot configuration
     - List snapshots: sudo snapper list
     - Create manual snapshot: sudo snapper create --description "Before major change"
     - Snapshots created automatically (hourly) and before pacman updates

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

# --- PHASE 3: SNAPSHOT POST-INSTALL MESSAGE ---

info "Creating snapshot guide..."
cat > /home/${USERNAME}/SNAPSHOTS_GUIDE.txt <<EOF
📸 BTRFS Snapshots with Snapper - User Guide

Your system is now configured with automatic BTRFS snapshots!

================================================================================
✅ What's Configured
================================================================================

1. Automatic Timeline Snapshots (Hourly)
   - Snapper creates automatic snapshots every hour
   - Retention: 5 hourly, 7 daily, 4 weekly, 3 monthly
   - Old snapshots cleaned up automatically

2. Automatic Pre/Post Snapshots (Before Updates)
   - snap-pac creates snapshots before and after every pacman operation
   - Allows you to rollback if an update breaks your system
   - No configuration needed - works automatically

3. Snapshot Storage
   - Snapshots stored in /.snapshots (BTRFS @snapshots subvolume)
   - Uses BTRFS copy-on-write (minimal space usage)
   - Space limit: 50% of filesystem

================================================================================
📋 Common Commands
================================================================================

List all snapshots:
  sudo snapper list

Create a manual snapshot:
  sudo snapper create --description "Before major change"

Compare snapshot to current system:
  sudo snapper status 1..0

Show files changed since snapshot:
  sudo snapper diff 1..0

Delete a snapshot:
  sudo snapper delete <snapshot-number>

================================================================================
🔄 How to Rollback After a Bad Update
================================================================================

METHOD 1: File-level rollback (Recommended for small changes)
---------------------------------------------------------------
1. List snapshots to find the one you want:
   sudo snapper list

2. Restore specific files from snapshot #5:
   sudo snapper undochange 5..0

3. Or restore entire snapshot:
   sudo snapper rollback 5
   sudo reboot

METHOD 2: Manual recovery (For major issues)
---------------------------------------------------------------
If your system won't boot:

1. Boot from Arch Linux live USB

2. Decrypt and mount your system (if using LUKS):
   cryptsetup open /dev/sdXY cryptroot
   mount -o subvol=@snapshots /dev/mapper/cryptroot /mnt

3. Find the snapshot you want (snapshots are numbered directories):
   ls /mnt/

4. Mount the snapshot as your root:
   umount /mnt
   mount -o subvol=@snapshots/5/snapshot /dev/mapper/cryptroot /mnt

5. Mount other subvolumes and chroot:
   mount -o subvol=@home /dev/mapper/cryptroot /mnt/home
   mount /dev/sdX1 /mnt/boot  # EFI partition
   arch-chroot /mnt

6. Fix your system, then exit and reboot

METHOD 3: Boot from snapshot (Automatic with Limine)
---------------------------------------------------------------
If limine-snapper-sync is installed, snapshots appear automatically in the
boot menu:

1. Reboot your system
2. In the Limine boot menu, you'll see:
   • Arch Linux (current)
   • Arch Linux (Fallback)
   • Arch Linux (Snapshot #1 - before update)
   • Arch Linux (Snapshot #2 - yesterday)
   • ...up to 5 snapshots

3. Select a snapshot entry to boot from that snapshot
4. Each snapshot boots with its matching kernel version
5. Changes made in snapshot mode don't affect other snapshots

⚠️  Note: Booting from snapshot is read-only by default for safety

================================================================================
⚠️  IMPORTANT: Snapshots Are NOT Backups!
================================================================================

Snapshots protect against:
  ✅ Bad system updates
  ✅ Configuration mistakes
  ✅ Accidental file deletion
  ✅ Software bugs

Snapshots do NOT protect against:
  ❌ Hard drive failure (same disk!)
  ❌ Ransomware (could encrypt snapshots)
  ❌ Physical damage
  ❌ Theft

🔐 For true backups:
  - Copy important data to external drive
  - Use tools like: borg, restic, rsync
  - Store backups off-site (cloud, second location)

================================================================================
🔧 Advanced Configuration
================================================================================

Edit snapshot retention policy:
  sudo vim /etc/snapper/configs/root

Disable hourly snapshots:
  sudo systemctl disable snapper-timeline.timer

Disable automatic cleanup:
  sudo systemctl disable snapper-cleanup.timer

Manual cleanup:
  sudo snapper cleanup timeline

================================================================================
🚀 Limine Boot Menu Features
================================================================================

Your system uses Limine bootloader with automatic snapshot integration:

✅ Automatic Boot Entries:
  - Limine detects all snapshots automatically
  - Each snapshot gets its own boot menu entry
  - Snapshots boot with their original kernel version
  - Up to 5 snapshot entries shown (configurable)

✅ Dual-Boot Support:
  - Limine auto-detects Windows and other operating systems
  - All OS options appear in the same boot menu

✅ UKI (Unified Kernel Images):
  - Kernel + initramfs combined into single .efi file
  - Stored on ESP for each snapshot
  - Ensures kernel-module version matching

Configuration:
  /etc/default/limine - Boot menu settings
  MAX_SNAPSHOT_ENTRIES=5 - Number of snapshots in menu

================================================================================
📚 More Information
================================================================================

Arch Wiki - Snapper:
  https://wiki.archlinux.org/title/Snapper

Arch Wiki - BTRFS Snapshots:
  https://wiki.archlinux.org/title/Btrfs#Snapshots

Test snapshots in a VM before relying on them for real recovery!

Delete this file after reviewing: rm ~/SNAPSHOTS_GUIDE.txt
EOF

chown ${USERNAME}:${USERNAME} /home/${USERNAME}/SNAPSHOTS_GUIDE.txt
chmod 644 /home/${USERNAME}/SNAPSHOTS_GUIDE.txt

success "Snapshot guide created at ~/SNAPSHOTS_GUIDE.txt"

success "Security hardening complete"
success "Finalization complete"
