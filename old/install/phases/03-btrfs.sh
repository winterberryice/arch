#!/bin/bash
# phases/03-btrfs.sh - BTRFS filesystem and subvolume setup
# Part of omarchy fork installer
# Based on docs/001-partitioning.md

ui_section "BTRFS Setup"

# Load partition info
BTRFS_PARTITION=$(load_state "btrfs_partition")
EFI_PARTITION=$(load_state "efi_partition")

info "Setting up BTRFS on $BTRFS_PARTITION"

# Mount top-level BTRFS volume
info "Mounting BTRFS top-level volume..."
mount "$BTRFS_PARTITION" /mnt

# Create subvolumes
info "Creating BTRFS subvolumes..."
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@swap

# Disable CoW for swap subvolume
info "Disabling CoW for swap subvolume..."
chattr +C /mnt/@swap

# List created subvolumes
info "Created subvolumes:"
btrfs subvolume list /mnt

# Unmount top-level
info "Unmounting top-level volume..."
umount /mnt

# Mount subvolumes with proper options
info "Mounting subvolumes with compression and noatime..."

# Mount root subvolume
mount -o noatime,compress=zstd:1,space_cache=v2,subvol=@ "$BTRFS_PARTITION" /mnt

# Create mount points
mkdir -p /mnt/{home,.snapshots,var/log,swap,boot}

# Mount other subvolumes
mount -o noatime,compress=zstd:1,space_cache=v2,subvol=@home "$BTRFS_PARTITION" /mnt/home
mount -o noatime,compress=zstd:1,space_cache=v2,subvol=@snapshots "$BTRFS_PARTITION" /mnt/.snapshots
mount -o noatime,compress=zstd:1,space_cache=v2,subvol=@var_log "$BTRFS_PARTITION" /mnt/var/log
mount -o noatime,subvol=@swap "$BTRFS_PARTITION" /mnt/swap  # No compression for swap

# Mount EFI partition
info "Mounting EFI partition..."
mount -o umask=0077,fmask=0077,dmask=0077 "$EFI_PARTITION" /mnt/boot

# Verify mounts
info "Verifying mounts..."
if ! mountpoint -q /mnt; then
    error "Failed to mount root filesystem"
    exit 1
fi

success "BTRFS setup complete"
info "Mount layout:"
findmnt -t btrfs /mnt
