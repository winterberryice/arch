#!/bin/bash
# lib/post-install.sh - Post-installation setup
# Configures Limine-Snapper integration, mkinitcpio, COSMIC

# --- CHROOT HELPER ---

chroot_run() {
    arch-chroot "$MOUNT_POINT" /bin/bash -c "$1"
}

# --- MKINITCPIO CONFIGURATION ---

configure_mkinitcpio() {
    log_info "Configuring mkinitcpio hooks..."

    # Create hook configuration
    chroot_run "cat > /etc/mkinitcpio.conf.d/arch-cosmic.conf << 'EOF'
# Arch COSMIC Installer - mkinitcpio configuration
HOOKS=(base udev keyboard autodetect microcode modconf kms keymap consolefont block encrypt filesystems fsck btrfs-overlayfs)
EOF"

    log_success "mkinitcpio configured"
}

# --- LIMINE BOOTLOADER CONFIGURATION ---

configure_limine() {
    log_info "Configuring Limine bootloader..."

    # Get kernel cmdline
    local luks_uuid
    luks_uuid=$(blkid -s UUID -o value "$LUKS_PARTITION")

    local cmdline="cryptdevice=UUID=${luks_uuid}:cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw quiet"

    # Create /etc/default/limine configuration
    chroot_run "cat > /etc/default/limine << EOF
TARGET_OS_NAME=\"Arch Linux COSMIC\"

ESP_PATH=\"/boot\"

KERNEL_CMDLINE[default]=\"$cmdline\"

ENABLE_UKI=yes
CUSTOM_UKI_NAME=\"arch-cosmic\"

ENABLE_LIMINE_FALLBACK=yes

# Find and add other bootloaders (Windows, etc.)
FIND_BOOTLOADERS=yes

BOOT_ORDER=\"*, *fallback, Snapshots\"

MAX_SNAPSHOT_ENTRIES=5

SNAPSHOT_FORMAT_CHOICE=5
EOF"

    # Create base limine.conf
    chroot_run "cat > /boot/limine.conf << 'EOF'
### Arch Linux COSMIC - Limine Configuration
timeout: 5
default_entry: 1
interface_branding: Arch Linux COSMIC
interface_branding_color: 2
hash_mismatch_panic: no

# Tokyo Night color palette
term_background: 1a1b26
backdrop: 1a1b26
term_palette: 15161e;f7768e;9ece6a;e0af68;7aa2f7;bb9af7;7dcfff;a9b1d6
term_palette_bright: 414868;f7768e;9ece6a;e0af68;7aa2f7;bb9af7;7dcfff;c0caf5
term_foreground: c0caf5
term_foreground_bright: c0caf5
term_background_bright: 24283b
EOF"

    log_success "Limine configured"
}

# --- SNAPPER CONFIGURATION ---

configure_snapper() {
    log_info "Configuring Snapper..."

    # Create snapper configs for root and home
    chroot_run "snapper -c root create-config /" 2>/dev/null || true
    chroot_run "snapper -c home create-config /home" 2>/dev/null || true

    # Configure snapper settings (like omarchy)
    chroot_run "
        # Disable timeline snapshots (manual/pacman only)
        sed -i 's/^TIMELINE_CREATE=\"yes\"/TIMELINE_CREATE=\"no\"/' /etc/snapper/configs/root /etc/snapper/configs/home 2>/dev/null || true

        # Limit number of snapshots
        sed -i 's/^NUMBER_LIMIT=\"50\"/NUMBER_LIMIT=\"5\"/' /etc/snapper/configs/root /etc/snapper/configs/home 2>/dev/null || true
        sed -i 's/^NUMBER_LIMIT_IMPORTANT=\"10\"/NUMBER_LIMIT_IMPORTANT=\"5\"/' /etc/snapper/configs/root /etc/snapper/configs/home 2>/dev/null || true

        # Space limits
        sed -i 's/^SPACE_LIMIT=\"0.5\"/SPACE_LIMIT=\"0.3\"/' /etc/snapper/configs/root /etc/snapper/configs/home 2>/dev/null || true
        sed -i 's/^FREE_LIMIT=\"0.2\"/FREE_LIMIT=\"0.3\"/' /etc/snapper/configs/root /etc/snapper/configs/home 2>/dev/null || true
    "

    # Enable btrfs quota for space-aware cleanup
    chroot_run "btrfs quota enable /" 2>/dev/null || true

    log_success "Snapper configured"
}

# --- LIMINE-SNAPPER INTEGRATION ---

install_limine_snapper() {
    log_info "Installing Limine-Snapper integration packages..."

    # These packages enable booting from snapshots
    # Note: These are in the official repos or AUR
    chroot_run "pacman -S --noconfirm --needed limine-snapper-sync limine-mkinitcpio-hook 2>/dev/null || true"

    # Enable the sync service
    chroot_run "systemctl enable limine-snapper-sync.service" 2>/dev/null || true

    log_success "Limine-Snapper integration installed"
}

# --- REBUILD AND UPDATE ---

rebuild_initramfs() {
    log_info "Rebuilding initramfs..."
    chroot_run "mkinitcpio -P" >> "$LOG_FILE" 2>&1
    log_success "Initramfs rebuilt"
}

update_limine() {
    log_info "Updating Limine boot entries..."
    chroot_run "limine-update" >> "$LOG_FILE" 2>&1 || {
        log_warn "limine-update not available yet, running limine install..."
        chroot_run "limine --install /boot" >> "$LOG_FILE" 2>&1 || true
    }
    log_success "Limine updated"
}

# --- COSMIC SPECIFIC SETUP ---

configure_cosmic() {
    log_info "Configuring COSMIC desktop..."

    # Enable required services
    chroot_run "systemctl enable cosmic-greeter.service"
    chroot_run "systemctl enable power-profiles-daemon.service" 2>/dev/null || true

    # Create user directories
    chroot_run "mkdir -p /home/$USERNAME/.config"
    chroot_run "chown -R $USERNAME:$USERNAME /home/$USERNAME"

    log_success "COSMIC configured"
}

# --- FINAL TOUCHES ---

final_setup() {
    log_info "Applying final configuration..."

    # Enable NetworkManager
    chroot_run "systemctl enable NetworkManager.service"

    # Set timezone
    chroot_run "ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime"
    chroot_run "hwclock --systohc"

    # Generate locales
    chroot_run "sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen"
    chroot_run "locale-gen" >> "$LOG_FILE" 2>&1
    chroot_run "echo 'LANG=en_US.UTF-8' > /etc/locale.conf"

    # Set keyboard
    chroot_run "echo 'KEYMAP=$KEYBOARD' > /etc/vconsole.conf"

    # Create initial snapshot
    chroot_run "snapper -c root create --description 'Fresh Install'" 2>/dev/null || true

    log_success "Final configuration complete"
}

# --- MAIN POST-INSTALL FLOW ---

run_post_install() {
    log_step "Post-Installation Setup"

    # Configure components
    configure_mkinitcpio
    configure_limine
    configure_snapper
    install_limine_snapper

    # Rebuild and update
    rebuild_initramfs
    update_limine

    # COSMIC and final setup
    configure_cosmic
    final_setup

    log_success "Post-installation complete"
}
