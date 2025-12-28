#!/bin/bash
# lib/encryption.sh - LUKS encryption functions
# Part of omarchy fork installer - Phase 2
# Based on docs/003-luks-setup.md

# Prompt for LUKS encryption password with validation
prompt_luks_password() {
    local password
    local password_confirm

    while true; do
        password=$(gum input --password --placeholder "Enter LUKS encryption password (min 12 characters)" --prompt "LUKS Password: ")

        if [[ -z "$password" ]]; then
            warn "Password cannot be empty"
            continue
        fi

        # Check minimum length (12 characters recommended)
        if [[ ${#password} -lt 12 ]]; then
            warn "Password is short (${#password} characters)"
            warn "Minimum 12 characters recommended for LUKS encryption"
            echo ""
            echo "⚠️  Remember: You will type this password on EVERY boot!"
            echo "⚠️  If you forget it, your data is LOST FOREVER!"
            echo ""

            if ! gum confirm "Continue with this password?"; then
                continue
            fi
        fi

        # Confirm password
        password_confirm=$(gum input --password --placeholder "Confirm password" --prompt "Confirm LUKS Password: ")

        if [[ "$password" != "$password_confirm" ]]; then
            warn "Passwords do not match. Try again."
            continue
        fi

        # Final warning and confirmation
        echo "" >&2
        ui_header "LUKS Encryption Setup" >&2
        echo "⚠️  IMPORTANT:" >&2
        echo "  • This password encrypts ALL your data" >&2
        echo "  • You will need it EVERY time you boot" >&2
        echo "  • If you forget it, your data is LOST FOREVER" >&2
        echo "  • No recovery method exists" >&2
        echo "" >&2
        echo "Make sure you:" >&2
        echo "  ✓ Remember this password" >&2
        echo "  ✓ Can type it correctly (check keyboard layout!)" >&2
        echo "  ✓ Won't forget it" >&2
        echo "" >&2

        if gum confirm "Proceed with encryption?"; then
            # Return password to stdout
            echo "$password"
            return 0
        else
            warn "Encryption cancelled by user"
            return 1
        fi
    done
}

# Create LUKS container
create_luks_container() {
    local partition="$1"
    local password="$2"

    if [[ -z "$partition" ]] || [[ -z "$password" ]]; then
        error "create_luks_container: Missing partition or password"
        return 1
    fi

    info "Creating LUKS2 encrypted container on $partition..."
    info "DEBUG: Password length for create: ${#password} characters"
    info "DEBUG: Password hash (for comparison): $(echo -n "$password" | sha256sum | cut -d' ' -f1)"

    # Verify partition exists
    if [[ ! -b "$partition" ]]; then
        error "Partition not found: $partition"
        return 1
    fi

    # Create LUKS container with defaults (LUKS2, aes-xts-plain64, 512-bit key)
    info "DEBUG: Running cryptsetup luksFormat..."
    if ! echo -n "$password" | cryptsetup luksFormat --type luks2 "$partition" -; then
        error "Failed to create LUKS container"
        return 1
    fi

    success "LUKS container created successfully"
    return 0
}

# Open LUKS container
open_luks_container() {
    local partition="$1"
    local password="$2"
    local mapper_name="${3:-cryptroot}"

    if [[ -z "$partition" ]] || [[ -z "$password" ]]; then
        error "open_luks_container: Missing partition or password"
        return 1
    fi

    info "Opening LUKS container: $partition → /dev/mapper/$mapper_name..."
    info "DEBUG: Password length for open: ${#password} characters"
    info "DEBUG: Password hash (for comparison): $(echo -n "$password" | sha256sum | cut -d' ' -f1)"

    # Open LUKS container
    info "DEBUG: Running cryptsetup open..."
    if ! echo -n "$password" | cryptsetup open "$partition" "$mapper_name"; then
        error "Failed to open LUKS container"
        error "DEBUG: Cryptsetup open failed with exit code $?"
        return 1
    fi

    # Verify mapper device exists
    if [[ ! -b "/dev/mapper/$mapper_name" ]]; then
        error "Mapper device not found: /dev/mapper/$mapper_name"
        return 1
    fi

    success "LUKS container unlocked: /dev/mapper/$mapper_name"
    return 0
}

# Close LUKS container
close_luks_container() {
    local mapper_name="${1:-cryptroot}"

    if [[ -b "/dev/mapper/$mapper_name" ]]; then
        info "Closing LUKS container: /dev/mapper/$mapper_name..."
        cryptsetup close "$mapper_name" 2>&1 || warn "Failed to close LUKS container"
    fi
}

# Create LUKS header backup
create_luks_header_backup() {
    local partition="$1"
    local backup_path="${2:-/mnt/root/luks-header-backup.img}"

    if [[ -z "$partition" ]]; then
        error "create_luks_header_backup: Missing partition"
        return 1
    fi

    info "Creating LUKS header backup..."

    # Ensure backup directory exists
    local backup_dir=$(dirname "$backup_path")
    mkdir -p "$backup_dir"

    # Create backup
    if ! cryptsetup luksHeaderBackup "$partition" --header-backup-file "$backup_path" 2>&1; then
        error "Failed to create LUKS header backup"
        return 1
    fi

    success "LUKS header backup created: $backup_path"
    echo "" >&2
    warn "⚠️  IMPORTANT: Copy this file to external storage!" >&2
    warn "⚠️  This backup can recover your data if LUKS header corrupts." >&2
    warn "⚠️  Do not store it on the encrypted drive itself!" >&2
    echo "" >&2

    return 0
}

# Get LUKS UUID
get_luks_uuid() {
    local partition="$1"

    if [[ -z "$partition" ]]; then
        error "get_luks_uuid: Missing partition"
        return 1
    fi

    # Get UUID using blkid
    local uuid=$(blkid -s UUID -o value "$partition" 2>/dev/null)

    if [[ -z "$uuid" ]]; then
        error "Failed to get UUID for $partition"
        return 1
    fi

    echo "$uuid"
    return 0
}

# Verify LUKS container
verify_luks_container() {
    local partition="$1"

    if [[ -z "$partition" ]]; then
        error "verify_luks_container: Missing partition"
        return 1
    fi

    # Check if partition is LUKS
    if ! cryptsetup isLuks "$partition" 2>/dev/null; then
        error "Partition is not a LUKS container: $partition"
        return 1
    fi

    info "Verified LUKS container: $partition"
    return 0
}

# Show LUKS container info
show_luks_info() {
    local partition="$1"

    if [[ -z "$partition" ]]; then
        error "show_luks_info: Missing partition"
        return 1
    fi

    info "LUKS container information:"
    cryptsetup luksDump "$partition" 2>&1 | head -20
}
