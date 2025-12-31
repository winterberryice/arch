#!/bin/bash
# lib/disk.sh - Disk detection and selection
# Handles dual-boot detection, free space finding, partition selection

# --- DISK DETECTION ---

# Get list of available disks (excluding live USB)
get_available_disks() {
    local exclude_disk=""

    # Don't offer the install media as an option
    exclude_disk=$(findmnt -no SOURCE /run/archiso/bootmnt 2>/dev/null || true)

    lsblk -dpno NAME,TYPE |
        awk '$2=="disk"{print $1}' |
        grep -E '/dev/(sd|hd|vd|nvme|mmcblk)' |
        { if [[ -n "$exclude_disk" ]]; then grep -Fvx "$exclude_disk"; else cat; fi; }
}

# Get disk info for display
get_disk_info() {
    local device="$1"
    local size model

    size=$(lsblk -dno SIZE "$device" 2>/dev/null)
    model=$(lsblk -dno MODEL "$device" 2>/dev/null | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

    local display="$device"
    [[ -n "$size" ]] && display="$display ($size)"
    [[ -n "$model" ]] && display="$display - $model"

    echo "$display"
}

# --- PARTITION DETECTION ---

# Detect existing EFI partition on disk
detect_efi_partition() {
    local disk="$1"

    # Find partitions with EFI type (ef00)
    local efi_parts
    efi_parts=$(sgdisk -p "$disk" 2>/dev/null | grep -i "EF00" | awk '{print $1}')

    for part_num in $efi_parts; do
        local partition
        if [[ "$disk" =~ nvme|mmcblk ]]; then
            partition="${disk}p${part_num}"
        else
            partition="${disk}${part_num}"
        fi

        # Verify it has FAT filesystem
        local fstype
        fstype=$(lsblk -no FSTYPE "$partition" 2>/dev/null | head -1)
        if [[ "$fstype" == "vfat" ]]; then
            echo "$partition"
            return 0
        fi
    done

    return 1
}

# Detect Windows installation on disk
detect_windows() {
    local disk="$1"

    # Check for NTFS partitions
    if lsblk -no FSTYPE "$disk"* 2>/dev/null | grep -q "ntfs"; then
        return 0
    fi

    # Check for Windows bootloader in EFI
    local efi_part
    efi_part=$(detect_efi_partition "$disk") || return 1

    # Try to detect Windows boot files (without mounting)
    if strings "$efi_part" 2>/dev/null | grep -qi "Microsoft\|Windows\|bootmgr"; then
        return 0
    fi

    return 1
}

# Detect free space on disk (minimum 40GB)
detect_free_space() {
    local disk="$1"
    local min_size_gb=40
    local min_size_bytes=$((min_size_gb * 1024 * 1024 * 1024))

    # Get sector size
    local sector_size
    sector_size=$(blockdev --getss "$disk" 2>/dev/null || echo 512)

    # Get total disk size in sectors
    local total_sectors
    total_sectors=$(blockdev --getsz "$disk" 2>/dev/null)

    # Get used sectors from partitions
    local used_sectors=0
    while read -r start size; do
        [[ -z "$start" ]] && continue
        used_sectors=$((used_sectors + size))
    done < <(sfdisk -d "$disk" 2>/dev/null | grep "^/dev" | sed 's/.*start=\s*\([0-9]*\).*size=\s*\([0-9]*\).*/\1 \2/')

    # Calculate free space
    local free_sectors=$((total_sectors - used_sectors - 2048))  # Reserve for GPT
    local free_bytes=$((free_sectors * sector_size))
    local free_gb=$((free_bytes / 1024 / 1024 / 1024))

    if [[ $free_bytes -ge $min_size_bytes ]]; then
        echo "$free_gb"
        return 0
    fi

    return 1
}

# Get list of partitions on disk (excluding EFI)
get_disk_partitions() {
    local disk="$1"
    local efi_part
    efi_part=$(detect_efi_partition "$disk" 2>/dev/null || echo "")

    lsblk -lno NAME,SIZE,FSTYPE "$disk" |
        tail -n +2 |
        while read -r name size fstype; do
            local part="/dev/$name"
            # Skip EFI partition
            [[ "$part" == "$efi_part" ]] && continue
            # Skip if mounted
            if ! findmnt -no TARGET "$part" &>/dev/null; then
                echo "$part ($size${fstype:+, $fstype})"
            fi
        done
}

# --- DISK SELECTION UI ---

# Main disk selection function
select_disk() {
    log_step "Disk Selection"

    local disks
    disks=$(get_available_disks)

    if [[ -z "$disks" ]]; then
        die "No suitable disks found"
    fi

    # Build disk options
    local disk_options=()
    while IFS= read -r device; do
        [[ -n "$device" ]] && disk_options+=("$(get_disk_info "$device")")
    done <<< "$disks"

    # Let user choose disk
    local selected
    selected=$(choose "Select installation disk:" "${disk_options[@]}")
    SELECTED_DISK=$(echo "$selected" | awk '{print $1}')

    log_info "Selected disk: $SELECTED_DISK"

    # Check for Windows
    if detect_windows "$SELECTED_DISK"; then
        HAS_WINDOWS=true
        log_warn "Windows installation detected on this disk"
    else
        HAS_WINDOWS=false
    fi

    # Check for existing EFI
    EXISTING_EFI=$(detect_efi_partition "$SELECTED_DISK" 2>/dev/null || echo "")
    if [[ -n "$EXISTING_EFI" ]]; then
        log_info "Existing EFI partition found: $EXISTING_EFI"
    fi

    export SELECTED_DISK HAS_WINDOWS EXISTING_EFI
}

# Select installation target (wipe, free space, or partition)
select_installation_target() {
    log_step "Installation Target"

    local options=()
    local option_types=()

    # Option 1: Wipe entire disk
    options+=("Wipe entire disk - ERASES EVERYTHING")
    option_types+=("wipe")

    # Option 2: Use free space (if available)
    local free_space_gb
    if free_space_gb=$(detect_free_space "$SELECTED_DISK"); then
        options+=("Use free space (${free_space_gb}GB available)")
        option_types+=("free_space")
    fi

    # Option 3: Use existing partition
    local partitions
    partitions=$(get_disk_partitions "$SELECTED_DISK")
    if [[ -n "$partitions" ]]; then
        while IFS= read -r part_info; do
            [[ -n "$part_info" ]] || continue
            options+=("Use partition: $part_info")
            option_types+=("partition:$(echo "$part_info" | awk '{print $1}')")
        done <<< "$partitions"
    fi

    # Show warnings for dual-boot
    if [[ "$HAS_WINDOWS" == true ]]; then
        echo
        log_warn "Windows detected! Selecting 'Wipe entire disk' will DESTROY Windows!"
        log_info "For dual-boot, choose 'Use free space' or a specific partition."
        echo
    fi

    # Let user choose
    local selected
    selected=$(choose "How do you want to install?" "${options[@]}")

    # Find selected option type
    for i in "${!options[@]}"; do
        if [[ "${options[$i]}" == "$selected" ]]; then
            INSTALL_MODE="${option_types[$i]}"
            break
        fi
    done

    # Confirm destructive operations
    case "$INSTALL_MODE" in
        wipe)
            echo
            log_warn "This will ERASE ALL DATA on $SELECTED_DISK!"
            if ! confirm "Are you absolutely sure?"; then
                die "Installation cancelled by user"
            fi
            ;;
        partition:*)
            local target_part="${INSTALL_MODE#partition:}"
            echo
            log_warn "This will ERASE partition $target_part!"
            if ! confirm "Are you sure?"; then
                die "Installation cancelled by user"
            fi
            TARGET_PARTITION="$target_part"
            ;;
    esac

    log_info "Installation mode: $INSTALL_MODE"
    export INSTALL_MODE TARGET_PARTITION
}
