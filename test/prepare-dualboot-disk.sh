#!/bin/bash
# prepare-dualboot-disk.sh - Prepare disk for Windows + Linux dual-boot testing

set -e

DISK_NAME="windows-linux-dualboot.qcow2"
DISK_SIZE="60G"
ARCH_ISO="archlinux-x86_64.iso"
WINDOWS_ISO="${1:-windows11.iso}"

echo "🔧 Preparing dual-boot test disk for QEMU"
echo ""

# Check if Windows ISO provided
if [[ ! -f "$WINDOWS_ISO" ]]; then
    echo "❌ Error: Windows ISO not found: $WINDOWS_ISO"
    echo ""
    echo "Usage: $0 /path/to/windows11.iso"
    exit 1
fi

# Check if Arch ISO exists
if [[ ! -f "$ARCH_ISO" ]]; then
    echo "📥 Downloading Arch Linux ISO..."
    wget https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso
fi

# Create disk if it doesn't exist
if [[ ! -f "$DISK_NAME" ]]; then
    echo "💾 Creating $DISK_SIZE disk image..."
    qemu-img create -f qcow2 "$DISK_NAME" "$DISK_SIZE"
    echo "✅ Disk created: $DISK_NAME"
else
    echo "⚠️  Disk already exists: $DISK_NAME"
    read -p "Recreate disk? This will DELETE existing data! (y/N): " confirm
    if [[ "$confirm" == "y" ]]; then
        rm "$DISK_NAME"
        qemu-img create -f qcow2 "$DISK_NAME" "$DISK_SIZE"
        echo "✅ Disk recreated"
    fi
fi

echo ""
echo "📋 Next steps:"
echo ""
echo "STEP 1: Partition the disk"
echo "  Run: ./partition-dualboot-disk.sh"
echo ""
echo "STEP 2: Install Windows"
echo "  Run: ./install-windows.sh $WINDOWS_ISO"
echo ""
echo "STEP 3: Test Linux installer"
echo "  Run: ./test-dualboot.sh"
echo ""
