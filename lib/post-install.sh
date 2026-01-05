#!/bin/bash
# lib/post-install.sh - Post-installation setup
# Based on omarchy's install/login/limine-snapper.sh
#
# This runs AFTER archinstall, in chroot, to configure:
# - mkinitcpio with proper hooks for LUKS + BTRFS
# - Limine bootloader with snapshot support
# - Snapper for BTRFS snapshots
# - COSMIC desktop greeter

# --- CHROOT HELPER ---

chroot_run() {
    arch-chroot "$MOUNT_POINT" /bin/bash -c "$1"
}

# --- MKINITCPIO OPTIMIZATION ---
# Disable hooks during post-install configuration to prevent multiple rebuilds

disable_mkinitcpio_hooks() {
    log_info "Disabling mkinitcpio hooks during configuration..."

    chroot_run "
        if [ -f /usr/share/libalpm/hooks/90-mkinitcpio-install.hook ]; then
            mv /usr/share/libalpm/hooks/90-mkinitcpio-install.hook \
               /usr/share/libalpm/hooks/90-mkinitcpio-install.hook.disabled
        fi
        if [ -f /usr/share/libalpm/hooks/60-mkinitcpio-remove.hook ]; then
            mv /usr/share/libalpm/hooks/60-mkinitcpio-remove.hook \
               /usr/share/libalpm/hooks/60-mkinitcpio-remove.hook.disabled
        fi
    "

    log_success "mkinitcpio hooks disabled"
}

enable_mkinitcpio_hooks() {
    log_info "Re-enabling mkinitcpio hooks..."

    chroot_run "
        if [ -f /usr/share/libalpm/hooks/90-mkinitcpio-install.hook.disabled ]; then
            mv /usr/share/libalpm/hooks/90-mkinitcpio-install.hook.disabled \
               /usr/share/libalpm/hooks/90-mkinitcpio-install.hook
        fi
        if [ -f /usr/share/libalpm/hooks/60-mkinitcpio-remove.hook.disabled ]; then
            mv /usr/share/libalpm/hooks/60-mkinitcpio-remove.hook.disabled \
               /usr/share/libalpm/hooks/60-mkinitcpio-remove.hook
        fi
    "

    log_success "mkinitcpio hooks re-enabled"
}

# --- MKINITCPIO CONFIGURATION ---

configure_mkinitcpio() {
    log_info "Configuring mkinitcpio hooks..."

    # Create hook configuration for LUKS + BTRFS
    # Note: btrfs-overlayfs is added later if limine-mkinitcpio-hook is installed
    chroot_run "cat > /etc/mkinitcpio.conf.d/arch-cosmic.conf << 'EOF'
# Arch COSMIC Installer - mkinitcpio configuration
# Hooks for LUKS encrypted BTRFS root
HOOKS=(base udev keyboard autodetect microcode modconf kms keymap consolefont block encrypt filesystems fsck)
EOF"

    log_success "mkinitcpio configured"
}

# --- LIMINE BOOTLOADER CONFIGURATION ---

configure_limine() {
    log_info "Configuring Limine bootloader..."

    # Get LUKS partition UUID
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

    # Create snapper configs for root and home (like omarchy)
    chroot_run "snapper -c root create-config / 2>/dev/null || true"
    chroot_run "snapper -c home create-config /home 2>/dev/null || true"

    # Configure snapper settings (like omarchy)
    chroot_run "
        for config in root home; do
            if [ -f /etc/snapper/configs/\$config ]; then
                # Disable timeline snapshots (manual/pacman only)
                sed -i 's/^TIMELINE_CREATE=\"yes\"/TIMELINE_CREATE=\"no\"/' /etc/snapper/configs/\$config

                # Limit number of snapshots
                sed -i 's/^NUMBER_LIMIT=\"50\"/NUMBER_LIMIT=\"5\"/' /etc/snapper/configs/\$config
                sed -i 's/^NUMBER_LIMIT_IMPORTANT=\"10\"/NUMBER_LIMIT_IMPORTANT=\"5\"/' /etc/snapper/configs/\$config

                # Space limits
                sed -i 's/^SPACE_LIMIT=\"0.5\"/SPACE_LIMIT=\"0.3\"/' /etc/snapper/configs/\$config
                sed -i 's/^FREE_LIMIT=\"0.2\"/FREE_LIMIT=\"0.3\"/' /etc/snapper/configs/\$config
            fi
        done
    "

    # Enable btrfs quota for space-aware cleanup
    chroot_run "btrfs quota enable / 2>/dev/null || true"

    log_success "Snapper configured (root + home)"
}

# --- AUR PACKAGES ---
# limine-snapper-sync and limine-mkinitcpio-hook are AUR packages

install_aur_helper() {
    log_info "Installing yay AUR helper..."

    chroot_run "
        # Temporary sudo access for build
        echo '$USERNAME ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/temp-build
        chmod 440 /etc/sudoers.d/temp-build

        # Build yay as user
        cd /tmp
        sudo -u '$USERNAME' git clone https://aur.archlinux.org/yay.git
        cd yay
        sudo -u '$USERNAME' makepkg -si --noconfirm

        # Cleanup
        rm -rf /tmp/yay
        rm -f /etc/sudoers.d/temp-build
    " >> "$LOG_FILE" 2>&1 || {
        log_warn "Failed to install yay - skipping AUR packages"
        return 1
    }

    log_success "yay installed"
    return 0
}

install_limine_snapper_packages() {
    log_info "Installing Limine-Snapper integration packages from AUR..."

    # Check if packages exist in official repos first
    if chroot_run "pacman -Ss limine-snapper-sync" &>/dev/null; then
        chroot_run "pacman -S --noconfirm --needed limine-snapper-sync limine-mkinitcpio-hook" >> "$LOG_FILE" 2>&1
    else
        # Fall back to AUR
        if ! install_aur_helper; then
            log_warn "Skipping Limine-Snapper AUR packages"
            return 1
        fi

        chroot_run "
            echo '$USERNAME ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/temp-build
            sudo -u '$USERNAME' yay -S --noconfirm --needed limine-snapper-sync limine-mkinitcpio-hook
            rm -f /etc/sudoers.d/temp-build
        " >> "$LOG_FILE" 2>&1 || {
            log_warn "Failed to install Limine-Snapper packages"
            return 1
        }
    fi

    # Update mkinitcpio hooks to include btrfs-overlayfs
    chroot_run "
        if [ -f /usr/lib/initcpio/install/btrfs-overlayfs ]; then
            sed -i 's/^HOOKS=.*/HOOKS=(base udev keyboard autodetect microcode modconf kms keymap consolefont block encrypt filesystems fsck btrfs-overlayfs)/' /etc/mkinitcpio.conf.d/arch-cosmic.conf
        fi
    "

    # Enable the sync service
    chroot_run "systemctl enable limine-snapper-sync.service 2>/dev/null || true"

    log_success "Limine-Snapper integration installed"
    return 0
}

# --- REBUILD AND UPDATE ---

rebuild_initramfs() {
    log_info "Rebuilding initramfs..."
    echo >&2  # Add blank line for visibility
    # Answer 'y' to the limine-mkinitcpio prompt automatically
    echo "y" | chroot_run "mkinitcpio -P" 2>&1 | tee -a "$LOG_FILE" >&2
    log_success "Initramfs rebuilt"
}

update_limine() {
    log_info "Installing Limine bootloader..."
    echo >&2

    # Try limine-update first (from limine-mkinitcpio-hook)
    if chroot_run "command -v limine-update" &>/dev/null; then
        log_info "Running limine-update..."
        chroot_run "limine-update" 2>&1 | tee -a "$LOG_FILE" >&2 || true
    fi

    # Ensure Limine EFI is installed to fallback location
    log_info "Installing Limine EFI bootloader..."
    chroot_run "
        mkdir -p /boot/EFI/BOOT
        cp /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/
    " 2>&1 | tee -a "$LOG_FILE" >&2

    log_success "Limine installed"
}

# --- SERVICES AND FINAL SETUP ---

configure_services() {
    log_info "Enabling system services..."

    chroot_run "
        systemctl enable NetworkManager.service
        systemctl enable cosmic-greeter.service
        systemctl enable power-profiles-daemon.service 2>/dev/null || true
    "

    log_success "Services enabled"
}

configure_locale() {
    log_info "Configuring locale and timezone..."

    chroot_run "
        # Timezone
        ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
        hwclock --systohc

        # Locale
        sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
        locale-gen
        echo 'LANG=en_US.UTF-8' > /etc/locale.conf

        # Keyboard
        echo 'KEYMAP=$KEYBOARD' > /etc/vconsole.conf
    " >> "$LOG_FILE" 2>&1

    log_success "Locale configured"
}

create_initial_snapshot() {
    log_info "Creating initial snapshots..."
    chroot_run "snapper -c root create --description 'Fresh Install'" 2>/dev/null || true
    chroot_run "snapper -c home create --description 'Fresh Install'" 2>/dev/null || true
    log_success "Initial snapshots created (root + home)"
}

# --- MAIN POST-INSTALL FLOW ---

run_post_install() {
    log_step "Post-Installation Setup"

    # Configure components
    configure_mkinitcpio
    configure_limine
    configure_snapper

    # Install AUR packages for snapshot booting (optional, may fail)
    install_limine_snapper_packages || true

    # Update Limine (this will trigger mkinitcpio automatically via hooks)
    update_limine

    # Final configuration
    configure_services
    configure_locale
    create_initial_snapshot

    log_success "Post-installation complete"
}
