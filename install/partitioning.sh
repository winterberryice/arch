#!/bin/bash
# lib/partitioning.sh - Disk partitioning, LUKS, and BTRFS setup
# Creates partitions and mounts to /mnt/archinstall for archinstall

# --- PARTITION CREATION ---

# Get partition path based on disk type
get_partition_path() {
    local disk="$1"
    local num="$2"

    if [[ "$disk" =~ nvme|mmcblk ]]; then
        echo "${disk}p${num}"
    else
        echo "${disk}${num}"
    fi
}

# Wipe and create fresh partition table
create_partition_table() {
    local disk="$1"

    log_info "Wiping disk and creating GPT partition table..."
    wipefs -af "$disk" >> "$LOG_FILE" 2>&1
    sgdisk -Z "$disk" >> "$LOG_FILE" 2>&1
    sgdisk -o "$disk" >> "$LOG_FILE" 2>&1
}

# Create EFI partition (2GB)
create_efi_partition() {
    local disk="$1"
    local part_num="${2:-1}"

    log_info "Creating EFI partition (2GB)..."
    sgdisk -n "${part_num}:0:+2G" -t "${part_num}:ef00" -c "${part_num}:EFI" "$disk" >> "$LOG_FILE" 2>&1

    partprobe "$disk"
    udevadm settle --timeout=10 || sleep 2

    local efi_part
    efi_part=$(get_partition_path "$disk" "$part_num")

    log_info "Formatting EFI partition as FAT32..."
    mkfs.fat -F 32 -n EFI "$efi_part" >> "$LOG_FILE" 2>&1

    echo "$efi_part"
}

# Create LUKS container
create_luks_container() {
    local partition="$1"
    local password="$2"

    log_info "Creating LUKS2 encrypted container..."
    log_info "This may take a moment..."

    echo -n "$password" | cryptsetup luksFormat --type luks2 \
        --cipher aes-xts-plain64 \
        --key-size 512 \
        --hash sha512 \
        --iter-time 2000 \
        --pbkdf argon2id \
        --label cryptroot \
        "$partition" - >> "$LOG_FILE" 2>&1

    log_success "LUKS container created"
}

# Open LUKS container
open_luks_container() {
    local partition="$1"
    local password="$2"
    local name="${3:-cryptroot}"

    log_info "Opening LUKS container..."
    echo -n "$password" | cryptsetup open "$partition" "$name" - >> "$LOG_FILE" 2>&1

    echo "/dev/mapper/$name"
}

# Create BTRFS filesystem with subvolumes
create_btrfs_filesystem() {
    local device="$1"

    log_info "Creating BTRFS filesystem..."
    mkfs.btrfs -f -L ArchLinux "$device" >> "$LOG_FILE" 2>&1

    # Mount temporarily to create subvolumes
    mount "$device" /mnt

    log_info "Creating BTRFS subvolumes..."
    btrfs subvolume create /mnt/@ >> "$LOG_FILE" 2>&1
    btrfs subvolume create /mnt/@home >> "$LOG_FILE" 2>&1
    btrfs subvolume create /mnt/@log >> "$LOG_FILE" 2>&1
    btrfs subvolume create /mnt/@pkg >> "$LOG_FILE" 2>&1

    umount /mnt

    log_success "BTRFS filesystem created with subvolumes"
}

# Mount filesystems for installation
mount_filesystems() {
    local btrfs_device="$1"
    local efi_partition="$2"
    local mount_point="${3:-/mnt/archinstall}"

    log_info "Mounting filesystems to $mount_point..."

    # BTRFS mount options
    local btrfs_opts="compress=zstd,noatime"

    # Mount root subvolume
    mkdir -p "$mount_point"
    mount -o "subvol=@,$btrfs_opts" "$btrfs_device" "$mount_point"

    # Mount other subvolumes
    mkdir -p "$mount_point/home"
    mount -o "subvol=@home,$btrfs_opts" "$btrfs_device" "$mount_point/home"

    mkdir -p "$mount_point/var/log"
    mount -o "subvol=@log,$btrfs_opts" "$btrfs_device" "$mount_point/var/log"

    mkdir -p "$mount_point/var/cache/pacman/pkg"
    mount -o "subvol=@pkg,$btrfs_opts" "$btrfs_device" "$mount_point/var/cache/pacman/pkg"

    # Mount EFI partition
    mkdir -p "$mount_point/boot"
    mount "$efi_partition" "$mount_point/boot"

    log_success "Filesystems mounted"
}

# --- INSTALLATION MODES ---

# Mode 1: Wipe entire disk
partition_wipe_disk() {
    local disk="$SELECTED_DISK"

    create_partition_table "$disk"

    # Create EFI partition
    EFI_PARTITION=$(create_efi_partition "$disk" 1)

    # Create main partition (rest of disk)
    log_info "Creating main partition..."
    sgdisk -n 2:0:0 -t 2:8300 -c 2:"Linux" "$disk" >> "$LOG_FILE" 2>&1
    partprobe "$disk"
    udevadm settle --timeout=10 || sleep 2

    LUKS_PARTITION=$(get_partition_path "$disk" 2)
}

# Mode 2: Use free space
partition_free_space() {
    local disk="$SELECTED_DISK"

    # Find the end of the last partition (use awk instead of bc for portability)
    local last_end
    last_end=$(sfdisk -d "$disk" 2>/dev/null | grep "^/dev" | tail -1 | \
        awk -F'[=, ]+' '{for(i=1;i<=NF;i++){if($i=="start")s=$(i+1);if($i=="size")sz=$(i+1)}}END{print s+sz}')
    last_end=${last_end:-2048}

    # Start new partition after last one (align to 1MB)
    local start_sector=$(( (last_end / 2048 + 1) * 2048 ))

    # Get next partition number
    local next_num
    next_num=$(sfdisk -d "$disk" 2>/dev/null | grep "^/dev" | wc -l)
    next_num=$((next_num + 1))

    # Check if we need to create EFI partition
    if [[ -z "$EXISTING_EFI" ]]; then
        log_info "Creating new EFI partition in free space..."

        sgdisk -n "${next_num}:${start_sector}:+2G" -t "${next_num}:ef00" -c "${next_num}:EFI" "$disk" >> "$LOG_FILE" 2>&1
        partprobe "$disk"
        udevadm settle --timeout=10 || sleep 2

        EFI_PARTITION=$(get_partition_path "$disk" "$next_num")
        mkfs.fat -F 32 -n EFI "$EFI_PARTITION" >> "$LOG_FILE" 2>&1

        next_num=$((next_num + 1))
        start_sector=$((start_sector + 2 * 1024 * 1024 * 1024 / 512))  # +2GB in sectors
    else
        log_info "Reusing existing EFI partition: $EXISTING_EFI"
        EFI_PARTITION="$EXISTING_EFI"
    fi

    # Create main partition in remaining free space
    log_info "Creating Linux partition in free space..."
    sgdisk -n "${next_num}:${start_sector}:0" -t "${next_num}:8300" -c "${next_num}:Linux" "$disk" >> "$LOG_FILE" 2>&1
    partprobe "$disk"
    udevadm settle --timeout=10 || sleep 2

    LUKS_PARTITION=$(get_partition_path "$disk" "$next_num")
}

# Mode 3: Use existing partition
partition_existing() {
    local partition="$TARGET_PARTITION"

    log_info "Using existing partition: $partition"

    # Wipe the partition
    wipefs -af "$partition" >> "$LOG_FILE" 2>&1

    # Check for EFI
    if [[ -z "$EXISTING_EFI" ]]; then
        die "No EFI partition found. Cannot install without EFI partition."
    fi

    EFI_PARTITION="$EXISTING_EFI"
    LUKS_PARTITION="$partition"
}

# --- MAIN PARTITIONING FLOW ---

run_partitioning() {
    log_step "Partitioning and Encryption"

    # Ensure any old mounts are cleaned up
    umount -R "$MOUNT_POINT" 2>/dev/null || true
    umount -R /mnt 2>/dev/null || true
    cryptsetup close cryptroot 2>/dev/null || true

    # Run appropriate partitioning mode
    case "$INSTALL_MODE" in
        wipe)
            partition_wipe_disk
            ;;
        free_space)
            partition_free_space
            ;;
        partition:*)
            partition_existing
            ;;
        *)
            die "Unknown installation mode: $INSTALL_MODE"
            ;;
    esac

    # Create LUKS container
    create_luks_container "$LUKS_PARTITION" "$PASSWORD"

    # Open LUKS container
    BTRFS_DEVICE=$(open_luks_container "$LUKS_PARTITION" "$PASSWORD" "cryptroot")

    # Create BTRFS filesystem
    create_btrfs_filesystem "$BTRFS_DEVICE"

    # Mount filesystems
    mount_filesystems "$BTRFS_DEVICE" "$EFI_PARTITION" "$MOUNT_POINT"

    # Export for later use
    export EFI_PARTITION LUKS_PARTITION BTRFS_DEVICE

    log_success "Partitioning complete"
    log_info "EFI: $EFI_PARTITION"
    log_info "LUKS: $LUKS_PARTITION"
    log_info "BTRFS: $BTRFS_DEVICE"
}
