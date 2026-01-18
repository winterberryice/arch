#!/bin/bash
# Migration: Add swap support (zram + swapfile)
# Adds hibernation-ready swap configuration to existing systems

set -e

echo "=== Swap Setup Migration ==="
echo "Adding hibernation-ready swap configuration..."
echo ""

# 1. Check if swap already configured
if swapon --show | grep -q '/swap/swapfile'; then
    echo "✓ Swapfile already exists, skipping swapfile creation..."
    SWAPFILE_EXISTS=true
else
    SWAPFILE_EXISTS=false
fi

if swapon --show | grep -q 'zram'; then
    echo "✓ Zram already configured, skipping zram setup..."
    ZRAM_EXISTS=true
else
    ZRAM_EXISTS=false
fi

if [[ "$SWAPFILE_EXISTS" == "true" ]] && [[ "$ZRAM_EXISTS" == "true" ]]; then
    echo "✓ Swap already fully configured, nothing to do."
    exit 0
fi

# 2. Detect RAM size
echo "Detecting system RAM..."
RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
RAM_GB=$((RAM_MB / 1024))
echo "  RAM: ${RAM_GB}GB (${RAM_MB}MB)"
echo ""

# 3. Check free space on BTRFS filesystem (RAM + 2GB buffer)
REQUIRED_MB=$((RAM_MB + 2048))
REQUIRED_GB=$((REQUIRED_MB / 1024))

echo "Checking available disk space..."
echo "  Required: ${REQUIRED_GB}GB (${RAM_GB}GB RAM + 2GB buffer)"

# Get BTRFS free space (use 'btrfs filesystem usage' for accurate space calculation)
CRYPTROOT="/dev/mapper/cryptroot"
if [[ ! -e "$CRYPTROOT" ]]; then
    echo "ERROR: $CRYPTROOT not found" >&2
    exit 1
fi

# Get free space in MB from BTRFS
FREE_MB=$(btrfs filesystem usage / 2>/dev/null | grep -i "Free (estimated)" | head -1 | awk '{print $3}' | sed 's/GiB//' | awk '{print int($1 * 1024)}')

if [[ -z "$FREE_MB" ]] || [[ "$FREE_MB" -eq 0 ]]; then
    # Fallback: use df if btrfs command fails
    FREE_MB=$(df -m / | awk 'NR==2 {print $4}')
fi

FREE_GB=$((FREE_MB / 1024))
echo "  Available: ${FREE_GB}GB"
echo ""

if [[ "$FREE_MB" -lt "$REQUIRED_MB" ]]; then
    echo "ERROR: Insufficient disk space for swapfile" >&2
    echo "  Required: ${REQUIRED_GB}GB" >&2
    echo "  Available: ${FREE_GB}GB" >&2
    echo "  Short by: $(( (REQUIRED_MB - FREE_MB) / 1024 ))GB" >&2
    echo "" >&2
    echo "To proceed:" >&2
    echo "  1. Free up disk space (clean package cache: sudo pacman -Scc)" >&2
    echo "  2. Or manually create smaller swapfile for your needs" >&2
    exit 1
fi

echo "✓ Sufficient disk space available"
echo ""

# 4. Setup swapfile (if not exists)
if [[ "$SWAPFILE_EXISTS" == "false" ]]; then
    echo "Setting up swapfile..."

    # Create @swap subvolume if it doesn't exist
    if ! btrfs subvolume list / | grep -q '@swap'; then
        echo "  Creating @swap subvolume..."

        # Mount BTRFS root temporarily
        mkdir -p /mnt/btrfs-root
        mount "$CRYPTROOT" /mnt/btrfs-root

        # Create @swap subvolume
        btrfs subvolume create /mnt/btrfs-root/@swap

        # Unmount
        umount /mnt/btrfs-root
        rmdir /mnt/btrfs-root

        echo "  ✓ @swap subvolume created"
    else
        echo "  ✓ @swap subvolume already exists"
    fi

    # Mount @swap subvolume if not already mounted
    if ! mountpoint -q /swap; then
        echo "  Mounting @swap subvolume to /swap..."
        mkdir -p /swap
        mount -o subvol=@swap,compress=zstd,noatime "$CRYPTROOT" /swap
        echo "  ✓ Mounted /swap"
    else
        echo "  ✓ /swap already mounted"
    fi

    # Add @swap to fstab if not present
    if ! grep -q '/swap.*btrfs.*subvol=@swap' /etc/fstab; then
        echo "  Adding @swap to fstab..."
        echo "$CRYPTROOT /swap btrfs subvol=@swap,compress=zstd,noatime 0 0" >> /etc/fstab
        echo "  ✓ Added to fstab"
    else
        echo "  ✓ Already in fstab"
    fi

    # Create swapfile
    echo "  Creating ${RAM_GB}GB swapfile (hibernation-ready)..."
    touch /swap/swapfile
    chattr +C /swap/swapfile
    dd if=/dev/zero of=/swap/swapfile bs=1M count="$RAM_MB" status=progress
    chmod 600 /swap/swapfile
    mkswap /swap/swapfile
    echo "  ✓ Swapfile created"

    # Add swapfile to fstab if not present
    if ! grep -q '/swap/swapfile' /etc/fstab; then
        echo "  Adding swapfile to fstab..."
        echo "/swap/swapfile none swap defaults,pri=1 0 0" >> /etc/fstab
        echo "  ✓ Added to fstab"
    else
        echo "  ✓ Already in fstab"
    fi

    # Enable swapfile
    echo "  Enabling swapfile..."
    swapon /swap/swapfile
    echo "  ✓ Swapfile enabled"

    echo "✓ Swapfile setup complete"
    echo ""
else
    echo "Swapfile already configured, skipping."
    echo ""
fi

# 5. Setup zram (if not exists)
if [[ "$ZRAM_EXISTS" == "false" ]]; then
    echo "Setting up zram..."

    # Install zram-generator
    echo "  Installing zram-generator..."
    pacman -S --noconfirm --needed zram-generator
    echo "  ✓ Installed"

    # Configure zram (50% of RAM, priority 100)
    echo "  Configuring zram (50% of RAM, priority 100)..."
    cat > /etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
EOF
    echo "  ✓ Configured"

    # Start zram
    echo "  Starting zram..."
    systemctl daemon-reload
    systemctl start systemd-zram-setup@zram0.service
    echo "  ✓ Started"

    echo "✓ Zram setup complete"
    echo ""
else
    echo "Zram already configured, skipping."
    echo ""
fi

# 6. Verify configuration
echo "=== Swap Configuration Summary ==="
swapon --show
echo ""
echo "✓ Migration complete!"
echo ""
echo "Swap details:"
echo "  Zram: $(( RAM_GB / 2 ))GB compressed (priority 100 - fast swap)"
echo "  Swapfile: ${RAM_GB}GB (priority 1 - hibernation-ready)"
echo ""
echo "To enable hibernation in the future:"
echo "  1. Calculate swapfile offset: sudo btrfs inspect-internal map-swapfile -r /swap/swapfile"
echo "  2. Add 'resume' hook to /etc/mkinitcpio.conf.d/arch-cosmic.conf after 'encrypt'"
echo "  3. Add kernel params: resume=/dev/mapper/cryptroot resume_offset=XXXXX"
echo "  4. Rebuild initramfs: sudo mkinitcpio -P"
echo "  5. Update Limine: sudo limine-snapper-sync"
echo ""
