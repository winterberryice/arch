#!/bin/bash
# partition-dualboot-disk.sh - Partition disk for dual-boot

set -e

DISK_NAME="windows-linux-dualboot.qcow2"
ARCH_ISO="archlinux-x86_64.iso"

# Auto-detect OVMF firmware (same as qemu-test.sh)
detect_ovmf() {
    local search_paths=(
        "/usr/share/ovmf/x64/OVMF_CODE.fd"
        "/usr/share/edk2-ovmf/x64/OVMF_CODE.fd"
        "/usr/share/edk2/x64/OVMF_CODE.4m.fd"
        "/usr/share/edk2/x64/OVMF_CODE.fd"
        "/usr/share/OVMF/OVMF_CODE.fd"
        "/usr/share/qemu/ovmf-x86_64-code.bin"
        "/usr/share/edk2/ovmf/OVMF_CODE.fd"
    )

    for path in "${search_paths[@]}"; do
        if [[ -f "$path" ]]; then
            OVMF_PATH="$path"
            echo "✅ Found OVMF: $OVMF_PATH"
            return 0
        fi
    done

    echo "❌ Error: OVMF firmware not found!"
    echo "Install with: sudo pacman -S edk2-ovmf"
    exit 1
}

detect_ovmf

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
  -drive if=pflash,format=raw,readonly=on,file="$OVMF_PATH" \
  -drive file="$DISK_NAME",format=qcow2,if=virtio \
  -cdrom "$ARCH_ISO" \
  -boot d \
  -vga virtio \
  -display sdl

echo ""
echo "✅ Partitioning complete (if you followed the steps above)"
echo ""
echo "Next: Install Windows with ./install-windows.sh"
