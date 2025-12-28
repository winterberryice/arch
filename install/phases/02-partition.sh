#!/bin/bash
# phases/02-partition.sh - Interactive disk partitioning
# Part of omarchy fork installer
# Phase 2: Support whole disk, partition, and free space installation

ui_section "Disk Partitioning"

# Step 1: Select disk
DISK=$(select_installation_disk)
info "Selected disk: $DISK"
echo ""

# Step 2: Select installation target (whole disk, partition, or free space)
TARGET_INFO=$(select_installation_target "$DISK")
TARGET_TYPE=$(echo "$TARGET_INFO" | cut -d: -f1)

info "Installation mode: $TARGET_TYPE"
echo ""

# Determine partition suffix based on disk type
if [[ "$DISK" =~ nvme ]]; then
    PARTITION_SUFFIX="p"
else
    PARTITION_SUFFIX=""
fi

# Variables to be set based on installation mode
EFI_PARTITION=""
BTRFS_PARTITION=""
EXISTING_EFI=""

# Detect existing EFI partition
EXISTING_EFI=$(detect_existing_efi "$DISK" || echo "")

# ============================================================================
# MODE 1: WHOLE DISK INSTALLATION (Phase 1 behavior)
# ============================================================================
if [[ "$TARGET_TYPE" == "whole_disk" ]]; then
    info "Mode: Whole disk installation"
    info "This will erase all data on $DISK"
    echo ""

    # Wipe existing partition table
    info "Wiping partition table..."
    wipefs -af "$DISK"
    sgdisk -Z "$DISK"

    # Create GPT partition table
    info "Creating GPT partition table..."
    sgdisk -o "$DISK"

    # Create EFI partition (2GB)
    info "Creating EFI partition (2GB)..."
    sgdisk -n 1:0:+2G -t 1:ef00 -c 1:"EFI System Partition" "$DISK"

    # Create BTRFS partition (remaining space)
    info "Creating BTRFS partition (remaining space)..."
    sgdisk -n 2:0:0 -t 2:8300 -c 2:"Arch Linux" "$DISK"

    # Inform kernel of partition changes
    info "Updating kernel partition table..."
    partprobe "$DISK"
    sleep 2

    # Set partition paths
    EFI_PARTITION="${DISK}${PARTITION_SUFFIX}1"
    BTRFS_PARTITION="${DISK}${PARTITION_SUFFIX}2"

    # Format EFI partition
    info "Formatting EFI partition as FAT32..."
    mkfs.fat -F 32 -n EFI "$EFI_PARTITION"

    # BTRFS formatting (and optional LUKS) happens at the end

# ============================================================================
# MODE 2: FREE SPACE INSTALLATION
# ============================================================================
elif [[ "$TARGET_TYPE" == "free_space" ]]; then
    info "Mode: Free space installation"

    # Extract free space info
    local start_sector=$(echo "$TARGET_INFO" | cut -d: -f2)
    local end_sector=$(echo "$TARGET_INFO" | cut -d: -f3)
    local size_gb=$(echo "$TARGET_INFO" | cut -d: -f4)

    info "Installing to free space: ${size_gb}GB (sectors ${start_sector}-${end_sector})"
    echo ""

    # Check if we need to create EFI partition
    if [[ -z "$EXISTING_EFI" ]]; then
        info "No existing EFI partition found, creating new one..."

        # Calculate next partition number
        local efi_part_num=$(get_next_partition_number "$DISK")
        local btrfs_part_num=$((efi_part_num + 1))

        # Create EFI partition (2GB at start of free space)
        info "Creating EFI partition (2GB)..."
        sgdisk -n "${efi_part_num}:${start_sector}:+2G" -t "${efi_part_num}:ef00" -c "${efi_part_num}:EFI System Partition" "$DISK"

        # Update start sector for BTRFS partition
        local efi_end_sector=$(sgdisk -i "$efi_part_num" "$DISK" 2>/dev/null | grep "Last sector:" | awk '{print $3}')
        start_sector=$((efi_end_sector + 1))

        # Create BTRFS partition (remaining free space)
        info "Creating BTRFS partition in remaining free space..."
        sgdisk -n "${btrfs_part_num}:${start_sector}:${end_sector}" -t "${btrfs_part_num}:8300" -c "${btrfs_part_num}:Arch Linux" "$DISK"

        # Inform kernel of partition changes
        info "Updating kernel partition table..."
        partprobe "$DISK"
        sleep 2

        # Set partition paths
        EFI_PARTITION=$(format_partition_path "$DISK" "$efi_part_num")
        BTRFS_PARTITION=$(format_partition_path "$DISK" "$btrfs_part_num")

        # Format EFI partition
        info "Formatting EFI partition as FAT32..."
        mkfs.fat -F 32 -n EFI "$EFI_PARTITION"

    else
        info "Existing EFI partition found: $EXISTING_EFI"
        info "Reusing for dual-boot compatibility..."

        # Calculate next partition number
        local btrfs_part_num=$(get_next_partition_number "$DISK")

        # Create BTRFS partition in free space
        info "Creating BTRFS partition in free space..."
        sgdisk -n "${btrfs_part_num}:${start_sector}:${end_sector}" -t "${btrfs_part_num}:8300" -c "${btrfs_part_num}:Arch Linux" "$DISK"

        # Inform kernel of partition changes
        info "Updating kernel partition table..."
        partprobe "$DISK"
        sleep 2

        # Set partition paths
        EFI_PARTITION="$EXISTING_EFI"
        BTRFS_PARTITION=$(format_partition_path "$DISK" "$btrfs_part_num")
    fi

    # BTRFS formatting (and optional LUKS) happens at the end

# ============================================================================
# MODE 3: EXISTING PARTITION INSTALLATION
# ============================================================================
elif [[ "$TARGET_TYPE" == "partition" ]]; then
    info "Mode: Existing partition installation"

    # Extract partition info
    local selected_partition=$(echo "$TARGET_INFO" | cut -d: -f2)

    info "Installing to partition: $selected_partition"
    echo ""

    # Verify partition is safe
    if ! verify_partition_safe "$selected_partition"; then
        error "Cannot use partition $selected_partition (in use)"
        exit 1
    fi

    # Wipe partition
    info "Wiping partition $selected_partition..."
    wipefs -af "$selected_partition"

    # Check if we need to create EFI partition
    if [[ -z "$EXISTING_EFI" ]]; then
        warn "No existing EFI partition found on disk!"
        warn "A dual-boot setup requires an EFI partition."
        echo ""

        if gum confirm "Create new EFI partition? (Required for boot)"; then
            # Find free space for EFI partition
            local free_spaces=$(detect_free_space "$DISK")

            if [[ -z "$free_spaces" ]]; then
                error "No free space available for EFI partition"
                error "Cannot proceed without EFI partition"
                exit 1
            fi

            # Use first free space block for EFI
            local first_free=$(echo "$free_spaces" | head -1)
            local efi_start=$(echo "$first_free" | cut -d: -f1)
            local efi_part_num=$(get_next_partition_number "$DISK")

            info "Creating EFI partition (2GB)..."
            sgdisk -n "${efi_part_num}:${efi_start}:+2G" -t "${efi_part_num}:ef00" -c "${efi_part_num}:EFI System Partition" "$DISK"

            # Inform kernel of partition changes
            partprobe "$DISK"
            sleep 2

            EFI_PARTITION=$(format_partition_path "$DISK" "$efi_part_num")

            # Format EFI partition
            info "Formatting EFI partition as FAT32..."
            mkfs.fat -F 32 -n EFI "$EFI_PARTITION"
        else
            error "Cannot install without EFI partition"
            exit 1
        fi
    else
        info "Existing EFI partition found: $EXISTING_EFI"
        info "Reusing for dual-boot compatibility..."
        EFI_PARTITION="$EXISTING_EFI"
    fi

    # Set BTRFS partition to selected partition
    BTRFS_PARTITION="$selected_partition"

    # BTRFS formatting (and optional LUKS) happens at the end

else
    error "Unknown installation mode: $TARGET_TYPE"
    exit 1
fi

# ============================================================================
# LUKS ENCRYPTION (Optional, Phase 2)
# ============================================================================

# Save the raw partition (before encryption)
LUKS_PARTITION=""

if [[ "$ENABLE_ENCRYPTION" == true ]]; then
    info "Setting up LUKS encryption..."
    echo ""

    # Save raw partition for LUKS
    LUKS_PARTITION="$BTRFS_PARTITION"

    # Create LUKS container
    if ! create_luks_container "$LUKS_PARTITION" "$LUKS_PASSWORD"; then
        error "Failed to create LUKS container"
        exit 1
    fi

    # Open LUKS container
    if ! open_luks_container "$LUKS_PARTITION" "$LUKS_PASSWORD" "cryptroot"; then
        error "Failed to open LUKS container"
        exit 1
    fi

    # Update BTRFS partition to point to unlocked mapper device
    BTRFS_PARTITION="/dev/mapper/cryptroot"

    success "LUKS encryption setup complete"
    info "Encrypted partition: $LUKS_PARTITION"
    info "Unlocked as: $BTRFS_PARTITION"
    echo ""
fi

# ============================================================================
# BTRFS FILESYSTEM FORMATTING
# ============================================================================

info "Formatting BTRFS filesystem..."
if [[ "$ENABLE_ENCRYPTION" == true ]]; then
    info "Formatting encrypted volume: $BTRFS_PARTITION"
else
    info "Formatting partition: $BTRFS_PARTITION"
fi

mkfs.btrfs -f -L ArchLinux "$BTRFS_PARTITION"

# ============================================================================
# FINAL VERIFICATION AND STATE SAVING
# ============================================================================

info "Verifying partitions..."

# Verify EFI partition exists
if [[ ! -b "$EFI_PARTITION" ]]; then
    error "EFI partition not found: $EFI_PARTITION"
    exit 1
fi

# Verify BTRFS partition exists
if [[ ! -b "$BTRFS_PARTITION" ]]; then
    error "BTRFS partition not found: $BTRFS_PARTITION"
    exit 1
fi

# Save partition info to state
save_state "disk" "$DISK"
save_state "efi_partition" "$EFI_PARTITION"
save_state "btrfs_partition" "$BTRFS_PARTITION"
save_state "installation_mode" "$TARGET_TYPE"
save_state "enable_encryption" "$ENABLE_ENCRYPTION"
save_state "luks_partition" "$LUKS_PARTITION"

success "Partitioning complete"
info "Partition layout:"
echo "  EFI:    $EFI_PARTITION"
if [[ "$ENABLE_ENCRYPTION" == true ]]; then
    echo "  LUKS:   $LUKS_PARTITION (encrypted)"
    echo "  BTRFS:  $BTRFS_PARTITION (unlocked LUKS volume)"
else
    echo "  BTRFS:  $BTRFS_PARTITION"
fi
echo ""

# Show final partition table
info "Final partition table:"
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT "$DISK"
