#!/bin/bash
# lib/ui.sh - User interface functions
# Part of omarchy fork installer
# Phase 0: Simple output functions (no gum yet)

ui_header() {
    echo ""
    echo "========================================="
    echo "$*"
    echo "========================================="
    echo ""
}

ui_section() {
    echo ""
    echo "--- $* ---"
    echo ""
}

ui_info() {
    echo -e "\033[0;34mℹ\033[0m $*"
}

ui_success() {
    echo -e "\033[0;32m✅\033[0m $*"
}

ui_warn() {
    echo -e "\033[0;33m⚠\033[0m $*"
}

ui_error() {
    echo -e "\033[0;31m❌\033[0m $*"
}

ui_progress() {
    local current=$1
    local total=$2
    local description=$3

    echo -e "\033[1;36m[$current/$total]\033[0m $description"
}

show_welcome() {
    ui_header "Arch Linux Installer (omarchy fork)"
    echo "Phase 2 - Advanced Installation"
    echo ""
    echo "Features:"
    echo "  • Interactive configuration"
    echo "  • Flexible partitioning (whole disk, partition, or free space)"
    echo "  • Optional LUKS encryption"
    echo "  • Dual-boot support (Windows/Linux)"
    echo "  • BTRFS with subvolumes"
    echo "  • systemd-boot bootloader"
    echo "  • COSMIC desktop environment"
    echo "  • Hardware auto-detection"
    echo "  • Security hardening"
    echo ""
    echo "This installer will guide you through setting up Arch Linux."
    echo ""
    sleep 2
}

show_success_message() {
    ui_header "Installation Complete!"
    echo ""
    echo "Your system has been installed successfully."
    echo ""
    echo "Your credentials:"
    echo "  Username: $USERNAME"
    echo "  Hostname: $HOSTNAME"
    echo "  Timezone: $TIMEZONE"
    echo ""
    echo "Next steps:"
    echo "  1. Type 'reboot' to restart"
    echo "  2. Remove installation media"
    echo "  3. Log in with your username and password"
    echo ""
    success "Installation complete!"
}

# --- PHASE 1: INTERACTIVE CONFIGURATION ---

# Check if gum is available, install if not
check_gum() {
    if command -v gum &>/dev/null; then
        return 0
    fi

    warn "gum (TUI tool) not found. Installing..."
    if pacman -Sy --noconfirm gum; then
        success "gum installed successfully"
        return 0
    else
        error "Failed to install gum"
        return 1
    fi
}

# Prompt for username with validation
prompt_username() {
    local username

    while true; do
        username=$(gum input --placeholder "Enter username (lowercase, alphanumeric)" --prompt "Username: " --value "")

        # Validate username
        if [[ -z "$username" ]]; then
            warn "Username cannot be empty"
            continue
        fi

        if [[ ! "$username" =~ ^[a-z][a-z0-9_-]*$ ]]; then
            warn "Username must start with lowercase letter and contain only lowercase letters, numbers, dash, or underscore"
            continue
        fi

        if [[ ${#username} -lt 3 ]]; then
            warn "Username must be at least 3 characters"
            continue
        fi

        echo "$username"
        return 0
    done
}

# Prompt for password with confirmation
prompt_password() {
    local prompt_text="$1"
    local password
    local password_confirm

    while true; do
        password=$(gum input --password --placeholder "Enter password (min 8 characters)" --prompt "$prompt_text: ")

        if [[ -z "$password" ]]; then
            warn "Password cannot be empty"
            continue
        fi

        if [[ ${#password} -lt 8 ]]; then
            warn "Password must be at least 8 characters"
            continue
        fi

        password_confirm=$(gum input --password --placeholder "Confirm password" --prompt "Confirm $prompt_text: ")

        if [[ "$password" != "$password_confirm" ]]; then
            warn "Passwords do not match. Try again."
            continue
        fi

        echo "$password"
        return 0
    done
}

# Prompt for hostname with validation
prompt_hostname() {
    local hostname
    local default="archlinux"

    while true; do
        hostname=$(gum input --placeholder "Enter hostname" --prompt "Hostname: " --value "$default")

        if [[ -z "$hostname" ]]; then
            hostname="$default"
        fi

        # Validate hostname (RFC 952)
        if [[ ! "$hostname" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]]; then
            warn "Hostname must contain only lowercase letters, numbers, and hyphens (no leading/trailing hyphens)"
            continue
        fi

        echo "$hostname"
        return 0
    done
}

# Prompt for timezone with validation
prompt_timezone() {
    local timezone
    local default="Europe/Warsaw"

    while true; do
        timezone=$(gum input --placeholder "Enter timezone (e.g., Europe/Warsaw, America/New_York)" --prompt "Timezone: " --value "$default")

        if [[ -z "$timezone" ]]; then
            timezone="$default"
        fi

        # Validate timezone exists
        if [[ ! -f "/usr/share/zoneinfo/$timezone" ]]; then
            warn "Timezone '$timezone' not found in /usr/share/zoneinfo/"
            echo "Tip: Use format like 'Europe/Warsaw' or 'America/New_York'"
            continue
        fi

        echo "$timezone"
        return 0
    done
}

# Interactive configuration - collect all user input
configure_installation() {
    ui_header "Installation Configuration"

    echo "Let's configure your Arch Linux installation."
    echo ""

    # Check for gum
    if ! check_gum; then
        error "Cannot proceed without gum. Please install it manually: pacman -S gum"
        exit 1
    fi

    echo ""

    # Collect configuration
    info "User Account Setup"
    USERNAME=$(prompt_username)
    success "Username: $USERNAME"
    echo ""

    USER_PASSWORD=$(prompt_password "User password")
    success "User password set"
    echo ""

    ROOT_PASSWORD=$(prompt_password "Root password")
    success "Root password set"
    echo ""

    info "System Configuration"
    HOSTNAME=$(prompt_hostname)
    success "Hostname: $HOSTNAME"
    echo ""

    TIMEZONE=$(prompt_timezone)
    success "Timezone: $TIMEZONE"
    echo ""

    # Set locale (default for Phase 2, will be enhanced in Phase 3)
    LOCALE="en_US.UTF-8"

    # Optional: LUKS encryption (Phase 2)
    info "Security Options"
    ENABLE_ENCRYPTION=false
    LUKS_PASSWORD=""

    if gum confirm "Enable full-disk encryption? (LUKS)

  ✅ Protects all data at rest
  ⚠️  Requires password on every boot
  ⚠️  If you forget password, data is lost forever"; then

        ENABLE_ENCRYPTION=true

        # Prompt for LUKS password
        LUKS_PASSWORD=$(prompt_luks_password)

        if [[ -z "$LUKS_PASSWORD" ]]; then
            warn "Encryption setup cancelled"
            ENABLE_ENCRYPTION=false
        else
            success "Encryption will be enabled"
        fi
    else
        info "Encryption will be disabled"
    fi
    echo ""

    # Show configuration summary
    ui_header "Configuration Summary"
    echo "Username:    $USERNAME"
    echo "Hostname:    $HOSTNAME"
    echo "Timezone:    $TIMEZONE"
    echo "Locale:      $LOCALE"
    echo "Encryption:  $( [[ "$ENABLE_ENCRYPTION" == true ]] && echo "Enabled (LUKS)" || echo "Disabled" )"
    echo ""

    # Confirm
    if gum confirm "Proceed with this configuration?"; then
        success "Configuration confirmed!"
        echo ""

        # Export configuration variables
        export TIMEZONE
        export LOCALE
        export HOSTNAME
        export USERNAME
        export USER_PASSWORD
        export ROOT_PASSWORD
        export ENABLE_ENCRYPTION
        export LUKS_PASSWORD

        return 0
    else
        warn "Configuration cancelled by user"
        exit 0
    fi
}

# --- DISK SELECTION ---

# Get list of available disks
get_available_disks() {
    # List all block devices that are disks (not partitions, not loop devices)
    lsblk -d -n -o NAME,SIZE,TYPE,MODEL | grep -E "disk" | awk '{print "/dev/"$1}'
}

# Show disk details with warnings
show_disk_details() {
    local disk="$1"
    local disk_name=$(basename "$disk")

    echo "" >&2
    ui_header "Disk Information: $disk" >&2

    # Show disk details
    lsblk "$disk" -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL >&2
    echo "" >&2

    # Check for mounted partitions
    local mounted_parts=$(lsblk -n -o MOUNTPOINT "$disk" | grep -v "^$" || true)
    if [[ -n "$mounted_parts" ]]; then
        warn "⚠️  WARNING: This disk has MOUNTED partitions!"
        echo "Mounted at:" >&2
        echo "$mounted_parts" >&2
        echo "" >&2
    fi

    # Check for existing filesystems
    local filesystems=$(lsblk -n -o FSTYPE "$disk" | grep -v "^$" || true)
    if [[ -n "$filesystems" ]]; then
        warn "⚠️  WARNING: This disk contains existing filesystems!"
        echo "Filesystem types detected:" >&2
        echo "$filesystems" | sort -u >&2
        echo "" >&2
    fi

    # Check for existing partition table
    if blkid "$disk" &>/dev/null || sfdisk -d "$disk" &>/dev/null 2>&1; then
        warn "⚠️  WARNING: This disk has an existing partition table!"
        echo "" >&2
    fi

    # Detect potential operating systems
    local has_windows=false
    local has_linux=false

    # Check each partition
    for part in $(lsblk -ln -o NAME "$disk" | tail -n +2); do
        local part_path="/dev/$part"

        # Check for Windows (NTFS, FAT32 with specific labels)
        if blkid "$part_path" 2>/dev/null | grep -iE "(ntfs|vfat)" | grep -iE "(Windows|EFI|Microsoft)" &>/dev/null; then
            has_windows=true
        fi

        # Check for Linux (ext4, xfs, btrfs, swap)
        if blkid "$part_path" 2>/dev/null | grep -iE "(ext[234]|xfs|btrfs|swap)" &>/dev/null; then
            has_linux=true
        fi
    done

    if [[ "$has_windows" == true ]]; then
        warn "⚠️  DETECTED: Possible Windows installation on this disk!"
        echo "" >&2
    fi

    if [[ "$has_linux" == true ]]; then
        warn "⚠️  DETECTED: Possible Linux installation on this disk!"
        echo "" >&2
    fi
}

# Confirm disk wipe
confirm_disk_wipe() {
    local disk="$1"

    echo "" >&2
    error "═══════════════════════════════════════════════════════════════"
    error "⚠️   DESTRUCTIVE OPERATION - ALL DATA WILL BE LOST!   ⚠️"
    error "═══════════════════════════════════════════════════════════════"
    echo "" >&2
    echo "This will completely ERASE the selected disk:" >&2
    echo "  Device: $disk" >&2

    # Get disk size and model
    local disk_info=$(lsblk -d -n -o SIZE,MODEL "$disk" 2>/dev/null || echo "Unknown")
    echo "  Info: $disk_info" >&2
    echo "" >&2
    echo "ALL DATA on this disk will be PERMANENTLY DELETED!" >&2
    echo "This includes:" >&2
    echo "  • All files and folders" >&2
    echo "  • All partitions" >&2
    echo "  • All operating systems" >&2
    echo "  • Everything. No recovery possible." >&2
    echo "" >&2
    error "═══════════════════════════════════════════════════════════════"
    echo "" >&2

    # Require typing "YES" in all caps
    local confirmation
    confirmation=$(gum input --placeholder "Type 'YES' in all caps to confirm" --prompt "Confirm deletion: ")

    if [[ "$confirmation" == "YES" ]]; then
        return 0
    else
        return 1
    fi
}

# Interactive disk selection
select_installation_disk() {
    ui_header "Disk Selection" >&2

    info "Scanning for available disks..."

    local disks=$(get_available_disks)

    if [[ -z "$disks" ]]; then
        error "No disks found!"
        exit 1
    fi

    # Count disks
    local disk_count=$(echo "$disks" | wc -l)

    if [[ $disk_count -eq 1 ]]; then
        # Only one disk, show it and confirm
        local disk="$disks"
        info "Found 1 disk: $disk"
        show_disk_details "$disk"

        if confirm_disk_wipe "$disk"; then
            # Only the disk path goes to stdout
            echo "$disk"
            return 0
        else
            warn "Installation cancelled by user"
            exit 0
        fi
    else
        # Multiple disks, let user choose
        info "Found $disk_count disks"
        echo "" >&2

        # Show brief list first
        echo "Available disks:" >&2
        lsblk -d -o NAME,SIZE,TYPE,MODEL | grep -E "disk|NAME" >&2
        echo "" >&2

        # Create menu options with size and model
        local disk_options=()
        while IFS= read -r disk; do
            local disk_info=$(lsblk -d -n -o SIZE,MODEL "$disk" | xargs)
            disk_options+=("$disk ($disk_info)")
        done <<< "$disks"

        # Let user choose
        local selected_option=$(gum choose --header "Select disk for installation:" "${disk_options[@]}")

        # Extract disk path from selection
        local selected_disk=$(echo "$selected_option" | awk '{print $1}')

        # Show details and confirm
        show_disk_details "$selected_disk"

        if confirm_disk_wipe "$selected_disk"; then
            # Only the disk path goes to stdout
            echo "$selected_disk"
            return 0
        else
            warn "Installation cancelled by user"
            exit 0
        fi
    fi
}

# --- PHASE 2: INSTALLATION TARGET SELECTION ---

# Select installation target (whole disk, partition, or free space)
select_installation_target() {
    local disk="$1"

    ui_header "Installation Target Selection" >&2

    info "Analyzing disk: $disk"
    echo "" >&2

    # Show disk overview
    lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT "$disk" >&2
    echo "" >&2

    # Detect existing EFI partition
    local existing_efi=$(detect_existing_efi "$disk")

    # Detect Windows
    local has_windows=false
    if detect_windows "$disk"; then
        has_windows=true
        warn "⚠️  Windows installation detected on this disk!"
        echo "" >&2
    fi

    # Build menu options
    local options=()
    local option_types=()

    # Option 1: Whole disk (wipe everything)
    local disk_info=$(get_disk_display_info "$disk")
    options+=("Whole disk $disk ($disk_info) - ⚠️  WILL ERASE EVERYTHING")
    option_types+=("whole_disk:$disk")

    # Option 2: Free space blocks (>= 20GB)
    local free_spaces=$(detect_free_space "$disk")
    local free_count=1
    if [[ -n "$free_spaces" ]]; then
        while IFS=: read -r start_sector end_sector size_gb; do
            [[ -z "$start_sector" ]] && continue
            options+=("Free space #${free_count} (${size_gb}GB) - Available for installation")
            option_types+=("free_space:${start_sector}:${end_sector}:${size_gb}")
            ((free_count++))
        done <<< "$free_spaces"
    fi

    # Option 3: Existing partitions (that can be wiped)
    local partitions=$(get_disk_partitions "$disk")
    if [[ -n "$partitions" ]]; then
        while IFS= read -r partition; do
            [[ -z "$partition" ]] && continue

            # Get partition info
            local part_info=$(get_partition_info "$partition")
            IFS=: read -r size filesystem label mountpoint <<< "$part_info"

            # Check if mounted
            local mount_warning=""
            if [[ -n "$mountpoint" ]]; then
                mount_warning=" ⛔ MOUNTED - CANNOT USE"
            else
                mount_warning=" - ⚠️  WILL FORMAT"
            fi

            # Build option text
            local option_text="$partition ($size"
            [[ -n "$filesystem" ]] && option_text+=", $filesystem"
            [[ -n "$label" ]] && option_text+=", \"$label\""
            option_text+=")${mount_warning}"

            options+=("$option_text")
            option_types+=("partition:$partition:$mountpoint")
        done <<< "$partitions"
    fi

    # Show available options count
    info "Found installation targets:"
    echo "  • 1 whole disk option" >&2
    [[ $((free_count - 1)) -gt 0 ]] && echo "  • $((free_count - 1)) free space block(s)" >&2
    local part_count=$(echo "$partitions" | grep -c "^/dev/" || echo "0")
    [[ $part_count -gt 0 ]] && echo "  • $part_count existing partition(s)" >&2
    echo "" >&2

    # Warnings
    if [[ "$has_windows" == true ]]; then
        warn "⚠️  If you select 'Whole disk', Windows will be erased!"
        warn "⚠️  To dual-boot, choose a partition or free space instead."
        echo "" >&2
    fi

    if [[ -n "$existing_efi" ]]; then
        info "ℹ️  Existing EFI partition found: $existing_efi"
        info "ℹ️  This will be reused (not wiped) for dual-boot compatibility."
        echo "" >&2
    fi

    # Let user choose
    local selected_option=$(gum choose --header "Choose installation target:" "${options[@]}")
    local selected_index=-1

    # Find selected index
    for i in "${!options[@]}"; do
        if [[ "${options[$i]}" == "$selected_option" ]]; then
            selected_index=$i
            break
        fi
    done

    if [[ $selected_index -lt 0 ]]; then
        error "Invalid selection"
        exit 1
    fi

    # Get selected target type and data
    local target_info="${option_types[$selected_index]}"
    local target_type=$(echo "$target_info" | cut -d: -f1)

    # Validate selection
    if [[ "$target_type" == "partition" ]]; then
        local partition=$(echo "$target_info" | cut -d: -f2)
        local mountpoint=$(echo "$target_info" | cut -d: -f3)

        # Block mounted partitions
        if [[ -n "$mountpoint" ]]; then
            error "Cannot install to mounted partition: $partition (mounted at $mountpoint)"
            error "Please unmount it first or choose a different target."
            exit 1
        fi

        # Verify partition is safe to use
        if ! verify_partition_safe "$partition"; then
            error "Partition $partition is in use and cannot be formatted."
            exit 1
        fi
    fi

    # Confirm selection
    echo "" >&2
    info "Selected target: $selected_option"
    echo "" >&2

    # Show confirmation based on type
    if [[ "$target_type" == "whole_disk" ]]; then
        if ! confirm_disk_wipe "$disk"; then
            warn "Installation cancelled by user"
            exit 0
        fi
    else
        # Confirm partition or free space installation
        local confirm_msg=""
        if [[ "$target_type" == "free_space" ]]; then
            local size_gb=$(echo "$target_info" | cut -d: -f4)
            confirm_msg="Install to free space (${size_gb}GB)?"
        else
            local partition=$(echo "$target_info" | cut -d: -f2)
            confirm_msg="Format and install to $partition? All data on this partition will be lost!"
        fi

        echo "" >&2
        warn "⚠️  WARNING: This operation cannot be undone!"
        echo "" >&2

        if ! gum confirm "$confirm_msg"; then
            warn "Installation cancelled by user"
            exit 0
        fi
    fi

    # Return target info to stdout (format: type:data)
    echo "$target_info"
    return 0
}
