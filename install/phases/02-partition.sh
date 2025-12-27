#!/bin/bash
# phases/02-partition.sh - Automated disk partitioning
# Part of omarchy fork installer
# Phase 0: Auto-detect first disk, full wipe

ui_section "Disk Partitioning"

# Auto-detect first disk
info "Detecting disks..."

# Try NVMe first, then SATA/virtio
if [[ -b /dev/nvme0n1 ]]; then
    DISK="/dev/nvme0n1"
    PARTITION_SUFFIX="p"
elif [[ -b /dev/sda ]]; then
    DISK="/dev/sda"
    PARTITION_SUFFIX=""
elif [[ -b /dev/vda ]]; then
    DISK="/dev/vda"
    PARTITION_SUFFIX=""
else
    error "No suitable disk found (checked nvme0n1, sda, vda)"
    exit 1
fi

info "Selected disk: $DISK"

# Show current disk info
info "Current disk layout:"
lsblk "$DISK" || true

# Define partition paths
EFI_PARTITION="${DISK}${PARTITION_SUFFIX}1"
BTRFS_PARTITION="${DISK}${PARTITION_SUFFIX}2"

warn "⚠ This will WIPE ALL DATA on $DISK"
sleep 3

# Wipe existing partition table
info "Wiping partition table..."
wipefs -af "$DISK"
sgdisk -Z "$DISK"

# Create GPT partition table
info "Creating GPT partition table..."
sgdisk -o "$DISK"

# Create EFI partition (512MB)
info "Creating EFI partition (512MB)..."
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI System Partition" "$DISK"

# Create BTRFS partition (remaining space)
info "Creating BTRFS partition (remaining space)..."
sgdisk -n 2:0:0 -t 2:8300 -c 2:"Arch Linux" "$DISK"

# Inform kernel of partition changes
info "Updating kernel partition table..."
partprobe "$DISK"
sleep 2

# Format EFI partition
info "Formatting EFI partition as FAT32..."
mkfs.fat -F 32 -n EFI "$EFI_PARTITION"

# Format BTRFS partition
info "Formatting BTRFS partition..."
mkfs.btrfs -f -L ArchLinux "$BTRFS_PARTITION"

# Save partition info to state
save_state "disk" "$DISK"
save_state "efi_partition" "$EFI_PARTITION"
save_state "btrfs_partition" "$BTRFS_PARTITION"

success "Partitioning complete"
info "Partitions created:"
echo "  EFI:   $EFI_PARTITION (512MB)"
echo "  BTRFS: $BTRFS_PARTITION"
