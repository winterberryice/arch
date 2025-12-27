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
    echo "Phase 1 - Interactive Installation"
    echo ""
    echo "Features:"
    echo "  • Interactive configuration"
    echo "  • BTRFS with subvolumes"
    echo "  • systemd-boot"
    echo "  • COSMIC desktop"
    echo "  • Hardware auto-detection"
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

    # Set locale (default for Phase 1)
    LOCALE="en_US.UTF-8"

    # Show configuration summary
    ui_header "Configuration Summary"
    echo "Username:  $USERNAME"
    echo "Hostname:  $HOSTNAME"
    echo "Timezone:  $TIMEZONE"
    echo "Locale:    $LOCALE"
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

    echo ""
    ui_header "Disk Information: $disk"

    # Show disk details
    lsblk "$disk" -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL
    echo ""

    # Check for mounted partitions
    local mounted_parts=$(lsblk -n -o MOUNTPOINT "$disk" | grep -v "^$" || true)
    if [[ -n "$mounted_parts" ]]; then
        warn "⚠️  WARNING: This disk has MOUNTED partitions!"
        echo "Mounted at:"
        echo "$mounted_parts"
        echo ""
    fi

    # Check for existing filesystems
    local filesystems=$(lsblk -n -o FSTYPE "$disk" | grep -v "^$" || true)
    if [[ -n "$filesystems" ]]; then
        warn "⚠️  WARNING: This disk contains existing filesystems!"
        echo "Filesystem types detected:"
        echo "$filesystems" | sort -u
        echo ""
    fi

    # Check for existing partition table
    if blkid "$disk" &>/dev/null || sfdisk -d "$disk" &>/dev/null 2>&1; then
        warn "⚠️  WARNING: This disk has an existing partition table!"
        echo ""
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
        echo ""
    fi

    if [[ "$has_linux" == true ]]; then
        warn "⚠️  DETECTED: Possible Linux installation on this disk!"
        echo ""
    fi
}

# Confirm disk wipe
confirm_disk_wipe() {
    local disk="$1"

    echo ""
    error "═══════════════════════════════════════════════════════════════"
    error "⚠️   DESTRUCTIVE OPERATION - ALL DATA WILL BE LOST!   ⚠️"
    error "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "This will completely ERASE the selected disk:"
    echo "  Device: $disk"

    # Get disk size and model
    local disk_info=$(lsblk -d -n -o SIZE,MODEL "$disk" 2>/dev/null || echo "Unknown")
    echo "  Info: $disk_info"
    echo ""
    echo "ALL DATA on this disk will be PERMANENTLY DELETED!"
    echo "This includes:"
    echo "  • All files and folders"
    echo "  • All partitions"
    echo "  • All operating systems"
    echo "  • Everything. No recovery possible."
    echo ""
    error "═══════════════════════════════════════════════════════════════"
    echo ""

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
    ui_header "Disk Selection"

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
            echo "$disk"
            return 0
        else
            warn "Installation cancelled by user"
            exit 0
        fi
    else
        # Multiple disks, let user choose
        info "Found $disk_count disks"
        echo ""

        # Show brief list first
        echo "Available disks:"
        lsblk -d -o NAME,SIZE,TYPE,MODEL | grep -E "disk|NAME"
        echo ""

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
            echo "$selected_disk"
            return 0
        else
            warn "Installation cancelled by user"
            exit 0
        fi
    fi
}
