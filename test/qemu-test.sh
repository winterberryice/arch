#!/bin/bash
# test/qemu-test.sh - QEMU testing helper for installer
# Part of omarchy fork installer

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="${SCRIPT_DIR}"
DISK_IMAGE="${TEST_DIR}/test-disk.qcow2"
DISK_SIZE="20G"
ISO_PATH="${TEST_DIR}/archlinux-x86_64.iso"
OVMF_PATH="/usr/share/ovmf/x64/OVMF_CODE.fd"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Check if QEMU is installed
check_qemu() {
    if ! command -v qemu-system-x86_64 &>/dev/null; then
        error "qemu-system-x86_64 not found"
        echo "Install with: sudo pacman -S qemu-full"
        exit 1
    fi
}

# Check if OVMF firmware exists
check_ovmf() {
    # Try common OVMF paths
    if [[ -f /usr/share/ovmf/x64/OVMF_CODE.fd ]]; then
        OVMF_PATH="/usr/share/ovmf/x64/OVMF_CODE.fd"
    elif [[ -f /usr/share/edk2-ovmf/x64/OVMF_CODE.fd ]]; then
        OVMF_PATH="/usr/share/edk2-ovmf/x64/OVMF_CODE.fd"
    elif [[ -f /usr/share/OVMF/OVMF_CODE.fd ]]; then
        OVMF_PATH="/usr/share/OVMF/OVMF_CODE.fd"
    else
        error "OVMF firmware not found"
        echo "Install with: sudo pacman -S edk2-ovmf"
        exit 1
    fi
    info "Using OVMF firmware: $OVMF_PATH"
}

# Create test disk
create_disk() {
    if [[ -f "$DISK_IMAGE" ]]; then
        warn "Test disk already exists: $DISK_IMAGE"
        read -p "Recreate? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Using existing disk"
            return
        fi
        rm -f "$DISK_IMAGE"
    fi

    info "Creating test disk: $DISK_IMAGE ($DISK_SIZE)"
    qemu-img create -f qcow2 "$DISK_IMAGE" "$DISK_SIZE"
}

# Download Arch ISO
download_iso() {
    if [[ -f "$ISO_PATH" ]]; then
        info "ISO already exists: $ISO_PATH"
        return
    fi

    warn "Arch Linux ISO not found"
    echo "Download from: https://archlinux.org/download/"
    echo "Expected path: $ISO_PATH"
    read -p "Continue without ISO? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
}

# Launch QEMU for installation
launch_install() {
    info "Launching QEMU for installation..."
    echo ""
    echo "Installation steps:"
    echo "  1. Boot into Arch Linux live environment"
    echo "  2. Connect to network (automatic for wired, 'iwctl' for WiFi)"
    echo "  3. Download installer: curl -O https://... or use git clone"
    echo "  4. Run: cd arch/install && sudo ./install.sh"
    echo ""
    warn "Press ENTER to continue..."
    read

    qemu-system-x86_64 \
        -enable-kvm \
        -cpu host \
        -smp 2 \
        -m 4G \
        -bios "$OVMF_PATH" \
        -drive file="$DISK_IMAGE",format=qcow2,if=virtio \
        -cdrom "$ISO_PATH" \
        -boot d \
        -vga virtio \
        -display gtk,gl=on \
        -device virtio-net-pci,netdev=net0 \
        -netdev user,id=net0 \
        -monitor stdio
}

# Launch QEMU for testing installed system
launch_test() {
    if [[ ! -f "$DISK_IMAGE" ]]; then
        error "Test disk not found: $DISK_IMAGE"
        echo "Run './qemu-test.sh install' first"
        exit 1
    fi

    info "Launching QEMU to test installed system..."
    warn "Remove ISO or change boot order in QEMU menu if needed"
    echo ""

    qemu-system-x86_64 \
        -enable-kvm \
        -cpu host \
        -smp 2 \
        -m 4G \
        -bios "$OVMF_PATH" \
        -drive file="$DISK_IMAGE",format=qcow2,if=virtio \
        -vga virtio \
        -display gtk,gl=on \
        -device virtio-net-pci,netdev=net0 \
        -netdev user,id=net0 \
        -monitor stdio
}

# Show usage
usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  install    - Create disk and launch installer"
    echo "  test       - Boot into installed system"
    echo "  clean      - Remove test disk"
    echo ""
}

# Main
main() {
    check_qemu
    check_ovmf

    case "${1:-}" in
        install)
            create_disk
            download_iso
            launch_install
            ;;
        test)
            launch_test
            ;;
        clean)
            if [[ -f "$DISK_IMAGE" ]]; then
                info "Removing test disk: $DISK_IMAGE"
                rm -f "$DISK_IMAGE"
                info "Clean complete"
            else
                info "No test disk to clean"
            fi
            ;;
        *)
            usage
            exit 0
            ;;
    esac
}

main "$@"
