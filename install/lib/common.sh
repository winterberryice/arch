#!/bin/bash
# lib/common.sh - Common functions, error handling, logging
# Part of omarchy fork installer

set -euo pipefail

# --- LOGGING ---

LOG_FILE="/var/log/arch-install.log"
VERBOSE=${VERBOSE:-true}  # Phase 0: verbose by default

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

info() {
    log "INFO: $*"
    if [[ "$VERBOSE" == true ]]; then
        echo -e "\033[0;34mℹ\033[0m $*"
    fi
}

warn() {
    log "WARN: $*"
    echo -e "\033[0;33m⚠\033[0m $*"
}

error() {
    log "ERROR: $*"
    echo -e "\033[0;31m❌\033[0m $*" >&2
}

success() {
    log "SUCCESS: $*"
    echo -e "\033[0;32m✅\033[0m $*"
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
    if ! ping -c 1 -W 5 archlinux.org &>/dev/null; then
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
    info "========================================="
    info "Phase: $description"
    info "========================================="

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
    info "========================================="
    info "Phase (chroot): $description"
    info "========================================="

    # Copy phase script into chroot
    cp "${SCRIPT_DIR}/phases/$phase.sh" /mnt/tmp/
    cp "${SCRIPT_DIR}/lib/common.sh" /mnt/tmp/
    cp "${SCRIPT_DIR}/lib/ui.sh" /mnt/tmp/

    # Execute in chroot
    if ! arch-chroot /mnt bash -c "
        source /tmp/common.sh
        source /tmp/ui.sh
        source /tmp/$phase.sh
    "; then
        error "Phase $phase failed in chroot"
        return 1
    fi

    # Cleanup
    rm -f /mnt/tmp/{$phase.sh,common.sh,ui.sh}

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

# --- CONFIGURATION (Phase 0 hardcoded values) ---

# System settings
TIMEZONE="Europe/Warsaw"
LOCALE="en_US.UTF-8"
HOSTNAME="archlinux"

# User settings (hardcoded for Phase 0)
USERNAME="january"
USER_PASSWORD="test123"  # TODO: Change on first login
ROOT_PASSWORD="root123"  # TODO: Change or lock

info "Configuration loaded (Phase 0 - hardcoded values)"
