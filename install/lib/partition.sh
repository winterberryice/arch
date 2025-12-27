#!/bin/bash
# lib/partition.sh - Partition detection and management
# Part of omarchy fork installer - Phase 2

# Get partition information (size, filesystem, label, mount status)
get_partition_info() {
    local partition="$1"
    local size filesystem label mountpoint

    size=$(lsblk -b -d -n -o SIZE "$partition" 2>/dev/null | numfmt --to=iec-i --suffix=B 2>/dev/null || echo "Unknown")
    filesystem=$(lsblk -n -o FSTYPE "$partition" 2>/dev/null | head -1)
    label=$(lsblk -n -o LABEL "$partition" 2>/dev/null | head -1)
    mountpoint=$(lsblk -n -o MOUNTPOINT "$partition" 2>/dev/null | head -1)

    # Return as colon-separated string
    echo "${size}:${filesystem}:${label}:${mountpoint}"
}

# Get partition size in bytes
get_partition_size_bytes() {
    local partition="$1"
    lsblk -b -d -n -o SIZE "$partition" 2>/dev/null || echo "0"
}

# Get partition size in GB
get_partition_size_gb() {
    local partition="$1"
    local bytes=$(get_partition_size_bytes "$partition")
    echo $((bytes / 1024 / 1024 / 1024))
}

# Check if partition is mounted
is_partition_mounted() {
    local partition="$1"
    local mountpoint=$(lsblk -n -o MOUNTPOINT "$partition" 2>/dev/null | head -1)
    [[ -n "$mountpoint" ]]
}

# Detect free space blocks on disk (>= 20GB)
# Returns: start_sector:end_sector:size_gb for each free block
detect_free_space() {
    local disk="$1"
    local min_size_gb=20

    # Get partition table info using sgdisk
    # Format: partition_number:start_sector:end_sector
    local partitions=$(sgdisk -p "$disk" 2>/dev/null | grep -E "^\s+[0-9]+" | awk '{print $1":"$2":"$3}')

    # Get total disk sectors
    local disk_sectors=$(sgdisk -p "$disk" 2>/dev/null | grep "^Disk" | grep "sectors" | awk '{print $3}')

    # Get sector size (usually 512 bytes)
    local sector_size=$(sgdisk -p "$disk" 2>/dev/null | grep "Logical sector size:" | awk '{print $4}')
    [[ -z "$sector_size" ]] && sector_size=512

    # Calculate free space blocks
    local free_blocks=""
    local current_end=2048  # GPT starts at sector 2048

    # Sort partitions by start sector
    local sorted_parts=$(echo "$partitions" | sort -t: -k2 -n)

    while IFS=: read -r part_num start_sector end_sector; do
        [[ -z "$start_sector" ]] && continue

        # Check if there's free space before this partition
        local gap_start=$current_end
        local gap_end=$((start_sector - 1))
        local gap_sectors=$((gap_end - gap_start + 1))
        local gap_bytes=$((gap_sectors * sector_size))
        local gap_gb=$((gap_bytes / 1024 / 1024 / 1024))

        if [[ $gap_gb -ge $min_size_gb ]]; then
            free_blocks="${free_blocks}${gap_start}:${gap_end}:${gap_gb}\n"
        fi

        current_end=$((end_sector + 1))
    done <<< "$sorted_parts"

    # Check free space at the end of disk
    local final_gap_start=$current_end
    local final_gap_end=$((disk_sectors - 34))  # GPT backup at end
    local final_gap_sectors=$((final_gap_end - final_gap_start + 1))
    local final_gap_bytes=$((final_gap_sectors * sector_size))
    local final_gap_gb=$((final_gap_bytes / 1024 / 1024 / 1024))

    if [[ $final_gap_gb -ge $min_size_gb ]]; then
        free_blocks="${free_blocks}${final_gap_start}:${final_gap_end}:${final_gap_gb}\n"
    fi

    # Return free blocks
    echo -e "$free_blocks" | grep -v "^$"
}

# Detect existing EFI partition on disk
detect_existing_efi() {
    local disk="$1"

    # Find partitions with EFI type (ef00)
    local efi_parts=$(sgdisk -p "$disk" 2>/dev/null | grep -i "EF00" | awk '{print $1}')

    # Check each potential EFI partition
    for part_num in $efi_parts; do
        # Determine partition path
        local partition
        if [[ "$disk" =~ nvme ]]; then
            partition="${disk}p${part_num}"
        else
            partition="${disk}${part_num}"
        fi

        # Verify it has FAT filesystem
        local fstype=$(lsblk -n -o FSTYPE "$partition" 2>/dev/null | head -1)
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

    # Check all partitions on disk
    local partitions=$(lsblk -ln -o NAME,FSTYPE "$disk" | grep -v "^$(basename $disk)" | awk '{print $1}')

    for part_name in $partitions; do
        local partition="/dev/$part_name"
        local fstype=$(lsblk -n -o FSTYPE "$partition" 2>/dev/null | head -1)
        local label=$(lsblk -n -o LABEL "$partition" 2>/dev/null | head -1)

        # Check for NTFS filesystem (Windows)
        if [[ "$fstype" == "ntfs" ]]; then
            return 0
        fi

        # Check for Windows-related labels
        if echo "$label" | grep -iqE "windows|microsoft"; then
            return 0
        fi
    done

    # Check EFI partition for Windows bootloader
    local efi_partition=$(detect_existing_efi "$disk")
    if [[ -n "$efi_partition" ]] && [[ -b "$efi_partition" ]]; then
        # Try to mount and check for Windows boot files (without actually mounting)
        # Check partition content using strings (safer than mounting)
        if strings "$efi_partition" 2>/dev/null | grep -iq "Microsoft\|bootmgr\|Windows"; then
            return 0
        fi
    fi

    return 1
}

# Get list of all partitions on disk
get_disk_partitions() {
    local disk="$1"

    # List partitions (exclude the disk itself)
    lsblk -ln -o NAME "$disk" | grep -v "^$(basename $disk)$" | while read part_name; do
        echo "/dev/$part_name"
    done
}

# Calculate next available partition number
get_next_partition_number() {
    local disk="$1"

    # Get existing partition numbers
    local max_num=$(sgdisk -p "$disk" 2>/dev/null | grep -E "^\s+[0-9]+" | awk '{print $1}' | sort -n | tail -1)

    if [[ -z "$max_num" ]]; then
        echo "1"
    else
        echo $((max_num + 1))
    fi
}

# Format partition path based on disk type
format_partition_path() {
    local disk="$1"
    local partition_number="$2"

    if [[ "$disk" =~ nvme ]]; then
        echo "${disk}p${partition_number}"
    else
        echo "${disk}${partition_number}"
    fi
}

# Get disk model and size for display
get_disk_display_info() {
    local disk="$1"

    local size=$(lsblk -d -n -o SIZE "$disk" 2>/dev/null)
    local model=$(lsblk -d -n -o MODEL "$disk" 2>/dev/null | xargs)

    if [[ -n "$model" ]]; then
        echo "${size}, ${model}"
    else
        echo "${size}"
    fi
}

# Convert bytes to human-readable format
bytes_to_human() {
    local bytes=$1
    numfmt --to=iec-i --suffix=B "$bytes" 2>/dev/null || echo "${bytes}B"
}

# Verify partition is not in use (not mounted, not in fstab, etc.)
verify_partition_safe() {
    local partition="$1"

    # Check if mounted
    if is_partition_mounted "$partition"; then
        error "Partition $partition is currently mounted"
        return 1
    fi

    # Check if used by LVM
    if command -v pvs &>/dev/null; then
        if pvs 2>/dev/null | grep -q "$partition"; then
            error "Partition $partition is used by LVM"
            return 1
        fi
    fi

    # Check if used by RAID
    if [[ -f /proc/mdstat ]]; then
        if grep -q "$(basename $partition)" /proc/mdstat 2>/dev/null; then
            error "Partition $partition is used by RAID"
            return 1
        fi
    fi

    return 0
}
