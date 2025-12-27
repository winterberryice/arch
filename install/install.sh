#!/bin/bash
# install.sh - Main installer orchestrator
# Part of omarchy fork installer - Phase 0 MVP
#
# Usage: Run from Arch Linux live environment as root
#        curl -O https://... && bash install.sh

set -euo pipefail

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/hardware.sh"

# Main installation function
main() {
    # Show welcome message
    show_welcome

    # Phase 1: Preparation
    run_phase "01-prepare" "Preparation and requirements check"

    # Phase 2: Partitioning
    run_phase "02-partition" "Disk partitioning"

    # Phase 3: BTRFS setup
    run_phase "03-btrfs" "BTRFS filesystem and subvolumes"

    # Phase 4: Install base system
    run_phase "04-install" "Base system installation (pacstrap)"

    # Phase 5: Configure system (in chroot)
    run_phase_in_chroot "05-configure" "System configuration"

    # Phase 6: Install bootloader (in chroot)
    run_phase_in_chroot "06-bootloader" "Bootloader installation"

    # Phase 7: Finalize (in chroot)
    run_phase_in_chroot "07-finalize" "Finalization"

    # Show success message
    show_success_message

    # Unmount filesystems
    info "Unmounting filesystems..."
    umount -R /mnt || warn "Some filesystems may still be mounted"

    success "Installation complete! You may now reboot."
}

# Run main function
main "$@"
