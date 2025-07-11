#!/bin/bash
# --- PRE-INSTALLATION SCRIPT ---
# Prepares drives, subvolumes, and chroots into the new system.
# Run from the live environment AFTER exporting variables.

# Exit immediately if a command exits with a non-zero status.
set -e

# --- 1. VALIDATE ENVIRONMENT VARIABLES ---
# Check that the required variables have been exported.
if [ -z "$EFI_PARTITION" ] || [ -z "$BTRFS_PARTITION" ] || [ -z "$USERNAME" ]; then
  echo "❌ Error: Please export EFI_PARTITION, BTRFS_PARTITION, and USERNAME variables before running."
  echo "Example: export EFI_PARTITION=\"/dev/sdX1\""
  exit 1
fi

# --- 2. CREATE BTRFS SUBVOLUMES ---
echo ">>> Formatting and creating Btrfs subvolumes on ${BTRFS_PARTITION}..."
mount "${BTRFS_PARTITION}" /mnt
# Create subvolumes for system root, home, snapshots, and logs
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var_log
umount /mnt
echo "✅ Subvolumes created."

# --- 3. MOUNT PARTITIONS AND SUBVOLUMES ---
echo ">>> Mounting all partitions and subvolumes..."
# Mount the root subvolume with performance options
mount -o noatime,compress=zstd,subvol=@ "${BTRFS_PARTITION}" /mnt

# Create directories for the other mount points
mkdir -p /mnt/{home,.snapshots,var/log,.btrfsroot,efi}

# Mount the other subvolumes
mount -o noatime,compress=zstd,subvol=@home "${BTRFS_PARTITION}" /mnt/home
mount -o noatime,compress=zstd,subvol=@snapshots "${BTRFS_PARTITION}" /mnt/.snapshots
mount -o noatime,compress=zstd,subvol=@var_log "${BTRFS_PARTITION}" /mnt/var/log

# Mount the top-level BTRFS volume (subvolid=5) to .btrfsroot
# This is useful for maintenance and browsing all subvolumes from one place.
mount -o noatime,compress=zstd,subvolid=5 "${BTRFS_PARTITION}" /mnt/.btrfsroot

# Mount the EFI System Partition
mount "${EFI_PARTITION}" /mnt/efi
echo "✅ All partitions and subvolumes mounted."

# --- 4. PACSTRAP (INSTALL BASE SYSTEM) ---
echo ">>> Installing base system with pacstrap..."
pacstrap -K /mnt base linux-lts linux-firmware vim amd-ucode grub efibootmgr networkmanager btrfs-progs

# --- 5. GENERATE FSTAB ---
echo ">>> Generating fstab..."
# -U uses UUIDs for portability
genfstab -U /mnt >> /mnt/etc/fstab

# --- 6. PREPARE FOR CHROOT ---
echo ">>> Copying system configuration script into new system..."
# Ensure the target directory exists
mkdir -p "/mnt/home/${USERNAME}"
# Copy the next script to be run inside the chroot
cp ./system_config.sh "/mnt/home/${USERNAME}/system_config.sh"
# Make it executable
chmod +x "/mnt/home/${USERNAME}/system_config.sh"

echo ""
echo "✅ Base install complete. Chrooting into the new system."
echo "➡️  To continue, run: /home/${USERNAME}/system_config.sh"
echo ""
arch-chroot /mnt
