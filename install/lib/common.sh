#!/bin/bash
# lib/common.sh - Common functions, error handling, logging
# Part of omarchy fork installer

set -euo pipefail

# --- LOGGING ---

LOG_FILE="/var/log/arch-install.log"
VERBOSE=${VERBOSE:-true}  # Phase 0: verbose by default

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

info() {
    log "INFO: $*"
    if [[ "$VERBOSE" == true ]]; then
        echo -e "\033[0;34mℹ\033[0m $*" >&2
    fi
}

warn() {
    log "WARN: $*"
    echo -e "\033[0;33m⚠\033[0m $*" >&2
}

error() {
    log "ERROR: $*"
    echo -e "\033[0;31m❌\033[0m $*" >&2
}

success() {
    log "SUCCESS: $*"
    echo -e "\033[0;32m✅\033[0m $*" >&2
}

# --- ERROR HANDLING ---

cleanup_on_error() {
    warn "Cleaning up after error..."

    # Unmount filesystems
    if mountpoint -q /mnt 2>/dev/null; then
        info "Unmounting /mnt..."
        umount -R /mnt 2>/dev/null || true
    fi

    info "Cleanup complete"
}

handle_error() {
    local exit_code=$1
    local line_number=$2

    error "Installation failed at line $line_number with exit code $exit_code"
    cleanup_on_error

    echo ""
    error "Installation failed!"
    echo "Log file: $LOG_FILE"
    echo ""

    exit "$exit_code"
}

trap 'handle_error $? $LINENO' ERR

# --- REQUIREMENT CHECKS ---

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}

check_uefi() {
    if [[ ! -d /sys/firmware/efi ]]; then
        error "UEFI not detected. This installer requires UEFI."
        exit 1
    fi
}

check_network() {
    info "Checking network connectivity..."

    # Try multiple hosts to avoid false negatives
    local hosts=("8.8.8.8" "1.1.1.1" "archlinux.org")
    local connected=false

    for host in "${hosts[@]}"; do
        if ping -c 1 -W 3 "$host" &>/dev/null; then
            connected=true
            break
        fi
    done

    if [[ "$connected" == false ]]; then
        error "No network connection. Please connect to network first."
        echo "Tip: Use 'iwctl' for WiFi or check ethernet connection"
        exit 1
    fi

    success "Network connectivity OK"
}

# --- UTILITY FUNCTIONS ---

run_phase() {
    local phase=$1
    local description=$2

    echo ""
    echo "========================================="
    echo "Phase: $description"
    echo "========================================="
    log "INFO: Phase: $description"

    if ! source "${SCRIPT_DIR}/phases/$phase.sh"; then
        error "Phase $phase failed"
        return 1
    fi

    success "Completed: $description"
}

run_phase_in_chroot() {
    local phase=$1
    local description=$2

    echo ""
    echo "========================================="
    echo "Phase (chroot): $description"
    echo "========================================="
    log "INFO: Phase (chroot): $description"

    # Create installer directory in chroot's /root
    mkdir -p /mnt/root/installer

    # Verify source files exist
    if [[ ! -f "${SCRIPT_DIR}/phases/$phase.sh" ]]; then
        error "Source file not found: ${SCRIPT_DIR}/phases/$phase.sh"
        return 1
    fi

    # Create installer directory in chroot's /root
    mkdir -p /mnt/root/installer

    # Verify source files exist
    if [[ ! -f "${SCRIPT_DIR}/phases/$phase.sh" ]]; then
        error "Source file not found: ${SCRIPT_DIR}/phases/$phase.sh"
        return 1
    fi

    # Copy phase script into chroot
    cp "${SCRIPT_DIR}/phases/$phase.sh" /mnt/root/installer/
    cp "${SCRIPT_DIR}/lib/common.sh" /mnt/root/installer/
    cp "${SCRIPT_DIR}/lib/ui.sh" /mnt/root/installer/

    # Read hardware/partition state (saved outside chroot, need to pass in)
    local BTRFS_PARTITION=$(load_state "btrfs_partition" || echo "")
    local MICROCODE=$(load_state "microcode" || echo "")
    local HAS_NVIDIA=$(load_state "has_nvidia" || echo "false")
    local ENABLE_ENCRYPTION=$(load_state "enable_encryption" || echo "false")
    local LUKS_PARTITION=$(load_state "luks_partition" || echo "")

    # Export configuration variables for chroot
    local config_exports="
        export TIMEZONE='$TIMEZONE'
        export LOCALE='$LOCALE'
        export HOSTNAME='$HOSTNAME'
        export USERNAME='$USERNAME'
        export USER_PASSWORD='$USER_PASSWORD'
        export ROOT_PASSWORD='$ROOT_PASSWORD'
        export VERBOSE='$VERBOSE'
        export LOG_FILE='$LOG_FILE'
        export BTRFS_PARTITION='$BTRFS_PARTITION'
        export MICROCODE='$MICROCODE'
        export HAS_NVIDIA='$HAS_NVIDIA'
        export ENABLE_ENCRYPTION='$ENABLE_ENCRYPTION'
        export LUKS_PARTITION='$LUKS_PARTITION'
    "

    # Execute in chroot
    if ! arch-chroot /mnt bash -c "
        $config_exports
        source /root/installer/common.sh
        source /root/installer/ui.sh
        source /root/installer/$phase.sh
    "; then
        error "Phase $phase failed in chroot"
        return 1
    fi

    # Cleanup
    rm -rf /mnt/root/installer

    success "Completed: $description"
}

# --- STATE MANAGEMENT ---

STATE_DIR="/tmp/arch-install"
mkdir -p "$STATE_DIR"

save_state() {
    local key=$1
    local value=$2
    echo "$value" > "${STATE_DIR}/${key}"
}

load_state() {
    local key=$1
    if [[ -f "${STATE_DIR}/${key}" ]]; then
        cat "${STATE_DIR}/${key}"
    else
        echo ""
    fi
}

# --- CONFIGURATION ---
# Phase 1: Configuration is now set interactively via configure_installation() in ui.sh
# Variables: TIMEZONE, LOCALE, HOSTNAME, USERNAME, USER_PASSWORD, ROOT_PASSWORD
# These are set by the user during installation and exported by configure_installation()
