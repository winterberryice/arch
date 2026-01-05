#!/bin/bash
# test/qemu-test.sh - QEMU testing helper for installer
# Part of omarchy fork installer

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="${SCRIPT_DIR}"
DISK_IMAGE="${TEST_DIR}/test-disk.qcow2"
DISK_SIZE="30G"
ISO_PATH="${TEST_DIR}/archlinux-x86_64.iso"
OVMF_PATH="${OVMF_PATH:-}"  # Allow override via environment variable

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
    # Check if already set via environment variable
    if [[ -n "$OVMF_PATH" ]] && [[ -f "$OVMF_PATH" ]]; then
        info "Using OVMF firmware (from env): $OVMF_PATH"
        return 0
    fi

    # Try common OVMF paths
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
            info "Using OVMF firmware: $OVMF_PATH"
            return 0
        fi
    done

    # Not found in common locations, try to find it
    warn "OVMF firmware not found in common locations"
    info "Searching for OVMF firmware..."

    local found_files
    found_files=$(find /usr/share -name "*OVMF*CODE*.fd" -o -name "ovmf-*-code.bin" 2>/dev/null | head -5)

    if [[ -n "$found_files" ]]; then
        echo ""
        echo "Found potential OVMF firmware files:"
        echo "$found_files"
        echo ""
        read -p "Enter full path to OVMF firmware (or press Enter to exit): " user_path
        if [[ -f "$user_path" ]]; then
            OVMF_PATH="$user_path"
            info "Using OVMF firmware: $OVMF_PATH"
            return 0
        fi
    fi

    error "OVMF firmware not found"
    echo "Install with: sudo pacman -S edk2-ovmf"
    echo "Or set OVMF_PATH environment variable"
    exit 1
}

# Create test disk (empty, no partitions)
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

# Create test disk with pre-existing partitions (simulate dual-boot scenario)
create_disk_partitioned() {
    local scenario="${1:-basic}"

    if [[ -f "$DISK_IMAGE" ]]; then
        rm -f "$DISK_IMAGE"
    fi

    info "Creating partitioned test disk: $DISK_IMAGE ($DISK_SIZE)"
    info "Scenario: $scenario"

    # Create empty disk
    qemu-img create -f qcow2 "$DISK_IMAGE" "$DISK_SIZE"

    info "Creating partition layout in disk image..."

    # We need to partition the disk by booting into live environment
    # This will be done interactively by the user in QEMU
    # We'll provide instructions

    echo ""
    echo "============================================================"
    echo "PARTITION SETUP REQUIRED"
    echo "============================================================"
    echo ""
    echo "The QEMU VM will boot. Follow these steps to create test partitions:"
    echo ""

    if [[ "$scenario" == "windows" ]]; then
        echo "SCENARIO: Simulated Windows + Free Space"
        echo "-----------------------------------------------------------"
        echo "Run these commands in the live environment:"
        echo ""
        echo "  # Create partition table"
        echo "  sgdisk -Z /dev/vda"
        echo "  sgdisk -o /dev/vda"
        echo ""
        echo "  # Create EFI partition (512MB)"
        echo "  sgdisk -n 1:0:+512M -t 1:ef00 /dev/vda"
        echo ""
        echo "  # Create 'Windows' partition (20GB)"
        echo "  sgdisk -n 2:0:+20G -t 2:0700 /dev/vda"
        echo ""
        echo "  # Leave remaining ~9.5GB as free space"
        echo ""
        echo "  # Format partitions"
        echo "  mkfs.fat -F32 /dev/vda1"
        echo "  mkfs.ntfs -f -L 'Windows' /dev/vda2"
        echo ""
        echo "  # Verify"
        echo "  lsblk /dev/vda"
        echo ""
        echo "  # Shutdown when done"
        echo "  poweroff"
        echo ""
    elif [[ "$scenario" == "linux" ]]; then
        echo "SCENARIO: Existing Linux + Free Space"
        echo "-----------------------------------------------------------"
        echo "Run these commands in the live environment:"
        echo ""
        echo "  # Create partition table"
        echo "  sgdisk -Z /dev/vda"
        echo "  sgdisk -o /dev/vda"
        echo ""
        echo "  # Create EFI partition (512MB)"
        echo "  sgdisk -n 1:0:+512M -t 1:ef00 /dev/vda"
        echo ""
        echo "  # Create existing Linux partition (15GB)"
        echo "  sgdisk -n 2:0:+15G -t 2:8300 /dev/vda"
        echo ""
        echo "  # Leave remaining ~14.5GB as free space"
        echo ""
        echo "  # Format partitions"
        echo "  mkfs.fat -F32 /dev/vda1"
        echo "  mkfs.ext4 -L 'OldLinux' /dev/vda2"
        echo ""
        echo "  # Verify"
        echo "  lsblk /dev/vda"
        echo ""
        echo "  # Shutdown when done"
        echo "  poweroff"
        echo ""
    elif [[ "$scenario" == "multi" ]]; then
        echo "SCENARIO: Multiple Partitions, No Free Space"
        echo "-----------------------------------------------------------"
        echo "Run these commands in the live environment:"
        echo ""
        echo "  # Create partition table"
        echo "  sgdisk -Z /dev/vda"
        echo "  sgdisk -o /dev/vda"
        echo ""
        echo "  # Create EFI partition (512MB)"
        echo "  sgdisk -n 1:0:+512M -t 1:ef00 /dev/vda"
        echo ""
        echo "  # Create Windows partition (15GB)"
        echo "  sgdisk -n 2:0:+15G -t 2:0700 /dev/vda"
        echo ""
        echo "  # Create data partition (10GB)"
        echo "  sgdisk -n 3:0:+10G -t 3:8300 /dev/vda"
        echo ""
        echo "  # Create another partition (remaining ~4.5GB)"
        echo "  sgdisk -n 4:0:0 -t 4:8300 /dev/vda"
        echo ""
        echo "  # Format partitions"
        echo "  mkfs.fat -F32 /dev/vda1"
        echo "  mkfs.ntfs -f -L 'Windows' /dev/vda2"
        echo "  mkfs.ext4 -L 'Data' /dev/vda3"
        echo "  mkfs.ext4 -L 'Extra' /dev/vda4"
        echo ""
        echo "  # Verify"
        echo "  lsblk /dev/vda"
        echo ""
        echo "  # Shutdown when done"
        echo "  poweroff"
        echo ""
    else
        error "Unknown scenario: $scenario"
        echo "Valid scenarios: windows, linux, multi"
        exit 1
    fi

    echo "============================================================"
    echo ""
    warn "Press ENTER to launch QEMU for partition setup..."
    read

    # Launch QEMU for partition setup
    qemu-system-x86_64 \
        -enable-kvm \
        -cpu host \
        -smp 2 \
        -m 4G \
        -drive if=pflash,format=raw,readonly=on,file="$OVMF_PATH" \
        -drive file="$DISK_IMAGE",format=qcow2,if=virtio \
        -cdrom "$ISO_PATH" \
        -boot d \
        -vga virtio \
        -display gtk \
        -device virtio-net-pci,netdev=net0 \
        -netdev user,id=net0

    info "Partition setup complete"
    info "Disk is ready for testing installer with $scenario scenario"
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
    info "Launching QEMU with SSH port forwarding..."
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
    echo "git checkout claude/phase-2-implementation-qgF5M"
    echo "cd install"
    echo "sudo ./install.sh"
    echo "==================================================================="
    echo ""
    warn "Press ENTER to launch QEMU..."
    read

    qemu-system-x86_64 \
        -enable-kvm \
        -cpu host \
        -smp 4 \
        -m 8G \
        -drive if=pflash,format=raw,readonly=on,file="$OVMF_PATH" \
        -drive file="$DISK_IMAGE",format=qcow2,if=virtio \
        -cdrom "$ISO_PATH" \
        -boot d \
        -device virtio-vga-gl \
        -display gtk,gl=on \
        -device virtio-net-pci,netdev=net0 \
        -netdev user,id=net0,hostfwd=tcp::2222-:22 \
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
        -smp 4 \
        -m 8G \
        -drive if=pflash,format=raw,readonly=on,file="$OVMF_PATH" \
        -drive file="$DISK_IMAGE",format=qcow2,if=virtio \
        -device virtio-vga-gl \
        -display gtk,gl=on \
        -device virtio-net-pci,netdev=net0 \
        -netdev user,id=net0,hostfwd=tcp::2222-:22 \
        -monitor stdio
}

# Show usage
usage() {
    echo "Usage: $0 [command] [scenario]"
    echo ""
    echo "Commands:"
    echo "  install              - Create empty disk and launch installer (Phase 1 behavior)"
    echo "  install-partitioned  - Create partitioned disk for testing (Phase 2)"
    echo "    Scenarios:"
    echo "      windows          - Simulated Windows + free space"
    echo "      linux            - Existing Linux + free space"
    echo "      multi            - Multiple partitions, no free space"
    echo "  test                 - Boot into installed system"
    echo "  clean                - Remove test disk"
    echo ""
    echo "Examples:"
    echo "  $0 install                      # Empty disk (Phase 1)"
    echo "  $0 install-partitioned windows  # Windows dual-boot test"
    echo "  $0 install-partitioned linux    # Linux dual-boot test"
    echo "  $0 test                         # Boot installed system"
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
        install-partitioned)
            local scenario="${2:-windows}"
            download_iso
            create_disk_partitioned "$scenario"
            info ""
            info "Partition setup complete. Now launching installer..."
            info ""
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
