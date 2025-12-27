#!/bin/bash
# phases/02-partition.sh - Interactive disk partitioning
# Part of omarchy fork installer
# Phase 1: Interactive disk selection with safety checks

ui_section "Disk Partitioning"

# Interactive disk selection (from ui.sh)
DISK=$(select_installation_disk)

info "Selected disk: $DISK"

# Determine partition suffix based on disk type
if [[ "$DISK" =~ nvme ]]; then
    PARTITION_SUFFIX="p"
else
    PARTITION_SUFFIX=""
fi

# Define partition paths
EFI_PARTITION="${DISK}${PARTITION_SUFFIX}1"
BTRFS_PARTITION="${DISK}${PARTITION_SUFFIX}2"

info "Partition paths:"
echo "  EFI:   $EFI_PARTITION"
echo "  BTRFS: $BTRFS_PARTITION"
echo ""

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
