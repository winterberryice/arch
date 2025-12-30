#!/bin/bash
# partition-dualboot-disk.sh - Partition disk for dual-boot

set -e

DISK_NAME="windows-linux-dualboot.qcow2"
ARCH_ISO="archlinux-x86_64.iso"

echo "🔧 Partitioning disk for dual-boot..."
echo ""
echo "This will boot Arch live ISO and partition the disk:"
echo "  - 2GB EFI partition"
echo "  - 30GB Windows partition"
echo "  - 28GB Linux partition"
echo ""
echo "⚠️  Manual steps required:"
echo ""
echo "1. Wait for Arch to boot"
echo "2. Run these commands:"
echo ""
cat << 'EOF'
   gdisk /dev/vda

   Commands in gdisk:
   o     (create new GPT table)
   y     (confirm)

   n     (new partition)
   1     (partition number)
   <Enter>
   +2G
   ef00  (EFI type)

   n     (new partition)
   2     (partition number)
   <Enter>
   +30G
   0700  (Windows type)

   n     (new partition)
   3     (partition number)
   <Enter>
   <Enter>
   8300  (Linux type)

   p     (print - verify)
   w     (write changes)
   y     (confirm)

   # Format EFI partition
   mkfs.fat -F 32 -n EFI /dev/vda1

   # Verify
   lsblk -f
   fdisk -l /dev/vda

   # Shutdown
   poweroff
EOF

echo ""
read -p "Press Enter to boot Arch live ISO..."

qemu-system-x86_64 \
  -enable-kvm \
  -m 4G \
  -cpu host \
  -smp 2 \
  -drive file="$DISK_NAME",if=virtio \
  -cdrom "$ARCH_ISO" \
  -boot d \
  -bios /usr/share/edk2-ovmf/x64/OVMF.fd \
  -vga virtio \
  -display sdl

echo ""
echo "✅ Partitioning complete (if you followed the steps above)"
echo ""
echo "Next: Install Windows with ./install-windows.sh"
