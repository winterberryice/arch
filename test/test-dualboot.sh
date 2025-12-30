#!/bin/bash
# test-dualboot.sh - Test Linux installer on dual-boot disk

set -e

DISK_NAME="windows-linux-dualboot.qcow2"
ARCH_ISO="archlinux-x86_64.iso"

echo "🐧 Testing Linux installer on dual-boot disk..."
echo ""
echo "Test scenarios:"
echo "  1. Existing partition mode (select /dev/vda3)"
echo "  2. Free space mode (if you didn't use all space)"
echo ""
echo "Expected behavior:"
echo "  ✅ Detects Windows"
echo "  ✅ Warns about dual-boot"
echo "  ✅ Reuses existing 2GB EFI partition"
echo "  ✅ LUKS encryption works"
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
echo "✅ Test complete!"
