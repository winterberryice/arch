#!/bin/bash
# test-dualboot.sh - Test Linux installer on dual-boot disk

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
  -drive if=pflash,format=raw,readonly=on,file="$OVMF_PATH" \
  -drive file="$DISK_NAME",format=qcow2,if=virtio \
  -cdrom "$ARCH_ISO" \
  -boot d \
  -vga virtio \
  -display sdl

echo ""
echo "✅ Test complete!"
