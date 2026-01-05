#!/bin/bash
# lib/archinstall.sh - Generate archinstall JSON config and run archinstall
# Uses pre_mounted_config mode since we handle partitioning ourselves

# Pinned archinstall version
ARCHINSTALL_VERSION="${ARCHINSTALL_VERSION:-3.0.14-1}"

# --- MKINITCPIO OPTIMIZATION ---
# Disable hooks in the chroot BEFORE archinstall runs to prevent multiple rebuilds

disable_mkinitcpio_in_chroot() {
    log_info "Disabling mkinitcpio hooks in chroot (speed optimization)..."

    # Disable hooks in the mounted system
    if [ -f "$MOUNT_POINT/usr/share/libalpm/hooks/90-mkinitcpio-install.hook" ]; then
        mv "$MOUNT_POINT/usr/share/libalpm/hooks/90-mkinitcpio-install.hook" \
           "$MOUNT_POINT/usr/share/libalpm/hooks/90-mkinitcpio-install.hook.disabled"
    fi
    if [ -f "$MOUNT_POINT/usr/share/libalpm/hooks/60-mkinitcpio-remove.hook" ]; then
        mv "$MOUNT_POINT/usr/share/libalpm/hooks/60-mkinitcpio-remove.hook" \
           "$MOUNT_POINT/usr/share/libalpm/hooks/60-mkinitcpio-remove.hook.disabled"
    fi

    log_success "mkinitcpio hooks disabled"
}

# --- JSON GENERATION ---

generate_user_config() {
    local config_file="$1"

    log_info "Generating archinstall configuration..."

    # Get LUKS partition UUID for encryption reference
    local luks_uuid
    luks_uuid=$(blkid -s UUID -o value "$LUKS_PARTITION")

    # Note: For pre_mounted_config, we use minimal disk_config
    # archinstall will detect what's mounted at mountpoint
    cat > "$config_file" <<EOF
{
    "archinstall-language": "English",
    "audio_config": {
        "audio": "pipewire"
    },
    "bootloader": "Limine",
    "disk_config": {
        "config_type": "pre_mounted_config",
        "mountpoint": "$MOUNT_POINT"
    },
    "hostname": "$HOSTNAME",
    "kernels": ["linux"],
    "locale_config": {
        "kb_layout": "$KEYBOARD",
        "sys_enc": "UTF-8",
        "sys_lang": "en_US.UTF-8"
    },
    "mirror_config": {
        "custom_servers": [],
        "mirror_regions": {}
    },
    "network_config": {
        "type": "nm"
    },
    "no_pkg_lookups": false,
    "ntp": true,
    "packages": [
        "base-devel",
        "git",
        "vim",
        "networkmanager",
        "snapper",
        "cosmic",
        "cosmic-greeter",
        "xdg-desktop-portal-cosmic",
        "power-profiles-daemon"
    ],
    "parallel_downloads": 8,
    "profile_config": {
        "gfx_driver": null,
        "greeter": null,
        "profile": null
    },
    "swap": false,
    "timezone": "$TIMEZONE",
    "version": "$ARCHINSTALL_VERSION"
}
EOF

    log_success "Configuration file created: $config_file"
}

generate_user_credentials() {
    local creds_file="$1"

    log_info "Generating credentials file..."

    # Escape values for JSON
    local password_escaped
    local password_hash_escaped
    local username_escaped

    password_escaped=$(echo -n "$PASSWORD" | jq -Rsa)
    password_hash_escaped=$(echo -n "$PASSWORD_HASH" | jq -Rsa)
    username_escaped=$(echo -n "$USERNAME" | jq -Rsa)

    cat > "$creds_file" <<EOF
{
    "encryption_password": $password_escaped,
    "!root-password": $password_hash_escaped,
    "!users": [
        {
            "!password": $password_hash_escaped,
            "groups": ["wheel"],
            "sudo": true,
            "username": $username_escaped
        }
    ]
}
EOF

    # Secure the credentials file
    chmod 600 "$creds_file"

    log_success "Credentials file created: $creds_file"
}

# --- ARCHINSTALL EXECUTION ---

install_archinstall() {
    log_info "Ensuring archinstall version $ARCHINSTALL_VERSION..."

    # Check current version
    local current_version
    current_version=$(pacman -Q archinstall 2>/dev/null | awk '{print $2}' || echo "none")

    if [[ "$current_version" != "$ARCHINSTALL_VERSION" ]]; then
        log_info "Installing archinstall $ARCHINSTALL_VERSION..."
        pacman -Sy --noconfirm "archinstall=$ARCHINSTALL_VERSION" >> "$LOG_FILE" 2>&1 || {
            log_warn "Could not install exact version, using available version"
            pacman -Sy --noconfirm archinstall >> "$LOG_FILE" 2>&1
        }
    fi
}

run_archinstall() {
    log_step "Running Archinstall"

    # Create temp directory for config files
    local config_dir="/tmp/arch-cosmic-install"
    mkdir -p "$config_dir"

    # Generate config files
    generate_user_config "$config_dir/config.json"
    generate_user_credentials "$config_dir/creds.json"

    # Install/update archinstall
    install_archinstall

    # Bootstrap base system into chroot so we can disable hooks
    log_info "Bootstrapping base system..."
    pacstrap "$MOUNT_POINT" base >> "$LOG_FILE" 2>&1

    # Disable mkinitcpio hooks BEFORE installing remaining packages
    disable_mkinitcpio_in_chroot

    # Show what we're doing
    log_info "Installing remaining packages with archinstall..."
    log_info "This will take 10-30 minutes depending on your internet speed."
    echo >&2

    # Run archinstall with our pre-mounted config
    # Note: archinstall will use what's already mounted at $MOUNT_POINT
    if ! archinstall \
        --config "$config_dir/config.json" \
        --creds "$config_dir/creds.json" \
        --mountpoint "$MOUNT_POINT" \
        --silent \
        --skip-ntp \
        2>&1 | tee -a "$LOG_FILE"; then

        log_error "Archinstall failed. Check log for details."
        cat "$config_dir/config.json" >> "$LOG_FILE"
        die "Archinstall failed"
    fi

    # Cleanup config files (contain sensitive data)
    rm -rf "$config_dir"

    log_success "Base system installed successfully"
}
