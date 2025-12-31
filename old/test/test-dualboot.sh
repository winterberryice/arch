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
echo "==================================================================="
echo "SSH INTO QEMU (much easier than GUI!):"
echo "==================================================================="
echo ""
echo "After QEMU boots, in the QEMU window run:"
echo "  passwd           # Set root password (e.g. 'root')"
echo "  systemctl start sshd"
echo ""
echo "Then from your host terminal, SSH in:"
echo "  ssh -p 2222 root@localhost"
echo ""
echo "Now you can copy/paste normally in your terminal!"
echo "==================================================================="
echo ""
echo "INSTALLATION COMMANDS (run via SSH):"
echo "-------------------------------------------------------------------"
echo "git clone https://github.com/winterberryice/arch.git"
echo "cd arch"
echo "git checkout claude/snapper-snapshot-automation-IAVhp"
echo "sudo ./install.sh"
echo ""
echo "During installation:"
echo "  - Select /dev/vda3 (28GB Linux partition)"
echo "  - EFI should auto-detect /dev/vda1"
echo "  - Test with or without LUKS encryption"
echo "==================================================================="
echo ""
read -p "Press Enter to boot Arch live ISO..."

qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -smp 4 \
  -m 8G \
  -drive if=pflash,format=raw,readonly=on,file="$OVMF_PATH" \
  -drive file="$DISK_NAME",format=qcow2,if=virtio \
  -cdrom "$ARCH_ISO" \
  -boot d \
  -device virtio-vga-gl \
  -display gtk,gl=on \
  -device virtio-net-pci,netdev=net0 \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -monitor stdio

echo ""
echo "✅ Test complete!"
