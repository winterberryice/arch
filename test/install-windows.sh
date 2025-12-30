#!/bin/bash
# install-windows.sh - Install Windows to the dual-boot disk

set -e

DISK_NAME="windows-linux-dualboot.qcow2"
WINDOWS_ISO="${1:-windows11.iso}"

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

if [[ ! -f "$WINDOWS_ISO" ]]; then
    echo "❌ Error: Windows ISO not found: $WINDOWS_ISO"
    echo "Usage: $0 /path/to/windows11.iso"
    exit 1
fi

detect_ovmf

echo "🪟 Installing Windows to dual-boot disk..."
echo ""
echo "⚠️  IMPORTANT - During Windows installation:"
echo ""
echo "1. Select 'Custom: Install Windows only (advanced)'"
echo "2. In partition list, select:"
echo "   Drive 0 Partition 2: (empty) 30720 MB  ← SELECT THIS"
echo "3. Click Next (do NOT format other partitions!)"
echo "4. Complete Windows setup (create user, etc.)"
echo ""
read -p "Press Enter to boot Windows installer..."

qemu-system-x86_64 \
  -enable-kvm \
  -m 4G \
  -cpu host \
  -smp 2 \
  -drive if=pflash,format=raw,readonly=on,file="$OVMF_PATH" \
  -drive file="$DISK_NAME",format=qcow2,if=virtio \
  -cdrom "$WINDOWS_ISO" \
  -boot d \
  -vga virtio \
  -display sdl \
  -device usb-ehci \
  -device usb-tablet

echo ""
echo "✅ Windows installation complete!"
echo ""
echo "Next: Test Linux installer with ./test-dualboot.sh"
