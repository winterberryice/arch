# Installation Script Architecture

## Overview

This document describes the overall architecture and organization of the Arch Linux installation scripts. It covers script structure, error handling, user interaction flow, logging, and state management.

## Design Goals

- ✅ Modular design (separate concerns into different scripts)
- ✅ Clear error messages and recovery guidance
- ✅ Graceful failure handling (cleanup on error)
- ✅ Progress indication (user knows what's happening)
- ✅ Idempotent where possible (can retry failed steps)
- ✅ Logging for troubleshooting
- ✅ Clean user experience (gum TUI)
- ✅ Testable components

## Script Organization

### Modular Approach (Recommended)

**Separate scripts by phase:**

```
install/
├── install.sh                  # Main orchestrator
├── lib/
│   ├── common.sh              # Shared functions, error handling
│   ├── ui.sh                  # gum wrappers, user interaction
│   └── hardware.sh            # GPU/CPU detection functions
├── phases/
│   ├── 01-prepare.sh          # Dependencies, checks
│   ├── 02-partition.sh        # Partitioning TUI
│   ├── 03-luks.sh             # LUKS setup
│   ├── 04-btrfs.sh            # BTRFS and subvolumes
│   ├── 05-install.sh          # pacstrap
│   ├── 06-configure.sh        # Chroot configuration
│   ├── 07-bootloader.sh       # systemd-boot setup
│   └── 08-finalize.sh         # Cleanup, final steps
└── README.md                   # Installation instructions
```

**Why modular:**
- ✅ Easy to maintain (each script ~200-300 lines)
- ✅ Easy to test (test individual phases)
- ✅ Easy to debug (isolate failures)
- ✅ Reusable (call phases independently)
- ✅ Clear separation of concerns

### Alternative: Monolithic Approach

**Single large script:**
```
install.sh                      # Everything in one file
```

**Pros:**
- Simpler to distribute (one file)
- No sourcing issues

**Cons:**
- Hard to maintain (1000+ lines)
- Difficult to test
- Harder to debug
- Less modular

**V1 Decision: Modular approach** (better maintainability)

## Main Orchestrator (install.sh)

### Purpose

**Main entry point:**
- Coordinates all phases
- Handles overall flow
- Error handling at top level
- Progress tracking

### Structure

```bash
#!/bin/bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Source libraries
source "$(dirname "$0")/lib/common.sh"
source "$(dirname "$0")/lib/ui.sh"
source "$(dirname "$0")/lib/hardware.sh"

# Main installation flow
main() {
    # Show welcome
    show_welcome

    # Run phases in order
    run_phase "01-prepare" "Preparing environment"
    run_phase "02-partition" "Partitioning disk"
    run_phase "03-luks" "Setting up LUKS encryption"
    run_phase "04-btrfs" "Creating BTRFS filesystem"
    run_phase "05-install" "Installing base system"

    # Chroot and continue
    run_phase_in_chroot "06-configure" "Configuring system"
    run_phase_in_chroot "07-bootloader" "Installing bootloader"
    run_phase_in_chroot "08-finalize" "Finalizing installation"

    # Success
    show_success
}

main "$@"
```

## Common Library (lib/common.sh)

### Error Handling

**Global error handler:**
```bash
set -euo pipefail
trap 'handle_error $? $LINENO' ERR

handle_error() {
    local exit_code=$1
    local line_number=$2

    error "Installation failed at line $line_number with exit code $exit_code"

    # Cleanup
    cleanup_on_error

    # Show recovery instructions
    show_recovery_help

    exit $exit_code
}
```

**Cleanup function:**
```bash
cleanup_on_error() {
    # Unmount filesystems
    if mountpoint -q /mnt; then
        umount -R /mnt 2>/dev/null || true
    fi

    # Close LUKS container
    if [[ -b /dev/mapper/cryptroot ]]; then
        cryptsetup close cryptroot 2>/dev/null || true
    fi

    info "Cleaned up mounts and LUKS containers"
}
```

### Logging

**Log levels:**
```bash
LOG_FILE="/var/log/arch-install.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

info() {
    log "INFO: $*"
    gum style --foreground 2 "ℹ $*"
}

warn() {
    log "WARN: $*"
    gum style --foreground 208 "⚠ $*"
}

error() {
    log "ERROR: $*"
    gum style --foreground 196 "❌ $*"
}

success() {
    log "SUCCESS: $*"
    gum style --foreground 2 "✅ $*"
}
```

### Utility Functions

**Check requirements:**
```bash
check_uefi() {
    if [[ ! -d /sys/firmware/efi ]]; then
        error "UEFI not detected. This installer requires UEFI."
        exit 1
    fi
}

check_network() {
    if ! ping -c 1 archlinux.org &>/dev/null; then
        error "No network connection. Please connect to network first."
        exit 1
    fi
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}
```

**Run phase:**
```bash
run_phase() {
    local phase=$1
    local description=$2

    info "Starting: $description"

    if ! source "phases/$phase.sh"; then
        error "Phase $phase failed"
        return 1
    fi

    success "Completed: $description"
}
```

## UI Library (lib/ui.sh)

### gum Wrappers

**Consistent styling:**
```bash
ui_header() {
    gum style \
        --border double \
        --border-foreground 212 \
        --padding "1 2" \
        --width 60 \
        "$*"
}

ui_info() {
    gum style --foreground 2 "ℹ $*"
}

ui_warn() {
    gum style --foreground 208 "⚠ $*"
}

ui_error() {
    gum style --foreground 196 "❌ $*"
}

ui_success() {
    gum style --foreground 2 "✅ $*"
}
```

**User input:**
```bash
ui_confirm() {
    local prompt=$1
    gum confirm "$prompt"
}

ui_input() {
    local placeholder=$1
    gum input --placeholder "$placeholder"
}

ui_password() {
    local placeholder=$1
    gum input --password --placeholder "$placeholder"
}

ui_choose() {
    local header=$1
    shift
    gum choose --header "$header" "$@"
}
```

**Progress indication:**
```bash
ui_spin() {
    local title=$1
    local command=$2
    gum spin --spinner dot --title "$title" -- bash -c "$command"
}

ui_progress() {
    local current=$1
    local total=$2
    local description=$3

    echo "[$current/$total] $description"
}
```

## Hardware Detection Library (lib/hardware.sh)

### GPU Detection

```bash
detect_gpu() {
    local gpu_info=$(lspci | grep -i "VGA\|3D\|Display")

    if echo "$gpu_info" | grep -iq "AMD\|ATI"; then
        HAS_AMD_GPU=true
    fi

    if echo "$gpu_info" | grep -iq "NVIDIA"; then
        HAS_NVIDIA_GPU=true
    fi

    if echo "$gpu_info" | grep -iq "Intel"; then
        HAS_INTEL_GPU=true
    fi
}
```

### CPU Detection

```bash
detect_cpu() {
    if grep -qi "AMD" /proc/cpuinfo; then
        HAS_AMD_CPU=true
        MICROCODE="amd-ucode"
    elif grep -qi "Intel" /proc/cpuinfo; then
        HAS_INTEL_CPU=true
        MICROCODE="intel-ucode"
    fi
}
```

### Package List Builder

```bash
build_package_list() {
    PACKAGES=(base linux linux-firmware btrfs-progs)

    # Microcode
    [[ -n "$MICROCODE" ]] && PACKAGES+=("$MICROCODE")

    # GPU drivers
    [[ "$HAS_NVIDIA_GPU" == true ]] && PACKAGES+=(nvidia nvidia-utils nvidia-settings)
    [[ "$HAS_AMD_GPU" == true ]] && PACKAGES+=(mesa vulkan-radeon)

    # Desktop
    PACKAGES+=(gnome gdm networkmanager)

    # Tools
    PACKAGES+=(vim sudo base-devel git)
}
```

## Phase Scripts

### Phase 01: Prepare

**File:** `phases/01-prepare.sh`

**Purpose:**
- Check requirements (UEFI, network, root)
- Install dependencies (gum, parted)
- Show welcome message

```bash
#!/bin/bash

# Check requirements
check_root
check_uefi
check_network

# Install dependencies
pacman -Sy --noconfirm gum parted

# Show welcome
ui_header "
Arch Linux Installer

Features:
• LUKS encryption
• BTRFS with snapshots
• systemd-boot
• Dual-boot with Windows
"

ui_confirm "Ready to begin installation?" || exit 0
```

### Phase 02: Partition

**File:** `phases/02-partition.sh`

**Purpose:**
- Disk selection (gum TUI)
- Show current layout
- Free space detection
- Partition creation
- ESP handling

```bash
#!/bin/bash

# Disk selection
DISK=$(lsblk -dno NAME,SIZE | gum choose --header "Select disk:")
DISK_PATH="/dev/$DISK"

# Show layout
ui_info "Current layout:"
lsblk "$DISK_PATH"

# Detect free space
# ... (from partitioning planning)

# User selects partition method
METHOD=$(ui_choose "Partition method:" \
    "Create in free space" \
    "Use existing partition")

# Create/select partition
# ... (TUI logic)

# Store selected partition
echo "$PARTITION" > /tmp/arch-install-partition
```

### Phase 03: LUKS

**File:** `phases/03-luks.sh`

**Purpose:**
- Password prompt
- LUKS container creation
- Open container

```bash
#!/bin/bash

PARTITION=$(cat /tmp/arch-install-partition)

# Password prompt
PASSWORD=$(ui_password "Enter LUKS encryption password")
PASSWORD_CONFIRM=$(ui_password "Confirm password")

[[ "$PASSWORD" != "$PASSWORD_CONFIRM" ]] && {
    ui_error "Passwords do not match"
    exit 1
}

# Warn about security
ui_warn "
⚠️  IMPORTANT:
• Forgotten password = DATA LOST FOREVER
• You will enter this password at every boot
"

ui_confirm "Proceed with encryption?" || exit 1

# Create LUKS
ui_spin "Creating LUKS container..." \
    "echo -n '$PASSWORD' | cryptsetup luksFormat --type luks2 '$PARTITION' -"

# Open LUKS
ui_spin "Opening LUKS container..." \
    "echo -n '$PASSWORD' | cryptsetup open '$PARTITION' cryptroot -"

# Verify
[[ -b /dev/mapper/cryptroot ]] || {
    ui_error "Failed to open LUKS container"
    exit 1
}

# Store LUKS UUID
LUKS_UUID=$(blkid -s UUID -o value "$PARTITION")
echo "$LUKS_UUID" > /tmp/arch-install-luks-uuid
```

### Phase 04: BTRFS

**File:** `phases/04-btrfs.sh`

**Purpose:**
- Create BTRFS filesystem
- Create subvolumes
- Mount all

```bash
#!/bin/bash

# Create BTRFS
ui_spin "Creating BTRFS filesystem..." \
    "mkfs.btrfs -f /dev/mapper/cryptroot"

# Mount top-level
mount /dev/mapper/cryptroot /mnt

# Create subvolumes
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@swap

# Disable CoW for swap
chattr +C /mnt/@swap

# Unmount
umount /mnt

# Mount with proper options
mount -o noatime,compress=zstd,subvol=@ /dev/mapper/cryptroot /mnt
mkdir -p /mnt/{home,.snapshots,var/log,swap,boot}
mount -o noatime,compress=zstd,subvol=@home /dev/mapper/cryptroot /mnt/home
mount -o noatime,compress=zstd,subvol=@snapshots /dev/mapper/cryptroot /mnt/.snapshots
mount -o noatime,compress=zstd,subvol=@var_log /dev/mapper/cryptroot /mnt/var/log

# Mount ESP
ESP_PARTITION=$(cat /tmp/arch-install-esp)
mount "$ESP_PARTITION" /mnt/boot

ui_success "BTRFS filesystem created and mounted"
```

### Phase 05: Install (pacstrap)

**File:** `phases/05-install.sh`

**Purpose:**
- Detect hardware
- Build package list
- Run pacstrap
- Generate fstab

```bash
#!/bin/bash

# Detect hardware
detect_cpu
detect_gpu
build_package_list

# Show detected hardware
ui_header "
Hardware Detected:

CPU:  $CPU_NAME
      Microcode: $MICROCODE

GPU:  $GPU_NAME
      Drivers: ${GPU_DRIVERS[@]}
"

# Install packages
ui_info "Installing ${#PACKAGES[@]} packages..."
pacstrap -K /mnt "${PACKAGES[@]}"

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

ui_success "Base system installed"
```

### Phase 06: Configure (in chroot)

**File:** `phases/06-configure.sh`

**Purpose:**
- Timezone, locale
- Hostname
- User creation
- mkinitcpio (LUKS hooks!)
- Services

```bash
#!/bin/bash
# NOTE: This runs inside chroot

# Timezone
ln -sf /usr/share/zoneinfo/Europe/Warsaw /etc/localtime
hwclock --systohc

# Locale
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Hostname
echo "archlinux" > /etc/hostname

# User
USERNAME=$(cat /tmp/arch-install-username)
useradd -m -G wheel,video,audio -s /bin/bash "$USERNAME"
echo "$USERNAME:$(cat /tmp/arch-install-user-password)" | chpasswd

# Sudo
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

# mkinitcpio - CRITICAL FOR LUKS!
if [[ "$HAS_NVIDIA_GPU" == true ]]; then
    # Add NVIDIA modules
    sed -i 's/^MODULES=.*/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
fi

# Add encrypt hook
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)/' /etc/mkinitcpio.conf

# Rebuild
mkinitcpio -P

# Enable services
systemctl enable gdm NetworkManager

ui_success "System configured"
```

### Phase 07: Bootloader

**File:** `phases/07-bootloader.sh`

**Purpose:**
- Install systemd-boot
- Create boot entries
- Configure loader

```bash
#!/bin/bash
# NOTE: This runs inside chroot

# Install systemd-boot
bootctl install

# Create loader.conf
cat > /boot/loader/loader.conf <<EOF
default  arch.conf
timeout  3
console-mode max
editor   no
EOF

# Get LUKS UUID
LUKS_UUID=$(cat /tmp/arch-install-luks-uuid)

# Build kernel parameters
OPTIONS="cryptdevice=UUID=${LUKS_UUID}:cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw"

# Add NVIDIA params if needed
[[ "$HAS_NVIDIA_GPU" == true ]] && OPTIONS+=" nvidia_drm.modeset=1"

# Create main entry
cat > /boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /${MICROCODE}.img
initrd  /initramfs-linux.img
options $OPTIONS
EOF

# Create fallback entry
cat > /boot/loader/entries/arch-fallback.conf <<EOF
title   Arch Linux (Fallback)
linux   /vmlinuz-linux
initrd  /${MICROCODE}.img
initrd  /initramfs-linux-fallback.img
options $OPTIONS
EOF

# Verify
bootctl status

ui_success "Bootloader installed"
```

### Phase 08: Finalize

**File:** `phases/08-finalize.sh`

**Purpose:**
- zram setup
- Swapfile creation
- Snapper configuration
- Final steps

```bash
#!/bin/bash
# NOTE: This runs inside chroot

# zram
cat > /etc/systemd/zram-generator.conf <<EOF
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF

# Swapfile
dd if=/dev/zero of=/swap/swapfile bs=1M count=16384
chmod 600 /swap/swapfile
mkswap /swap/swapfile
echo "/swap/swapfile none swap defaults 0 0" >> /etc/fstab

# Snapper
snapper -c root create-config /
snapper -c home create-config /home
snapper -c root create -d "Fresh install"

ui_success "Installation complete!"
```

## State Management

### Temporary State Files

**Store state between phases:**
```
/tmp/arch-install-partition
/tmp/arch-install-esp
/tmp/arch-install-luks-uuid
/tmp/arch-install-username
/tmp/arch-install-user-password  # Careful with permissions!
```

**Alternative: Single state file (JSON)**
```bash
STATE_FILE="/tmp/arch-install-state.json"

save_state() {
    local key=$1
    local value=$2
    jq --arg k "$key" --arg v "$value" '.[$k] = $v' "$STATE_FILE" > "$STATE_FILE.tmp"
    mv "$STATE_FILE.tmp" "$STATE_FILE"
}

load_state() {
    local key=$1
    jq -r ".$key" "$STATE_FILE"
}
```

## Error Recovery

### Idempotent Operations

**Check before acting:**
```bash
# BTRFS subvolume creation
if btrfs subvolume list /mnt | grep -q "@"; then
    warn "Subvolume @ already exists, skipping"
else
    btrfs subvolume create /mnt/@
fi

# Package installation
pacman -S --needed ... # Only installs if not present

# Service enabling
systemctl enable service || true  # Don't fail if already enabled
```

### Recovery Instructions

**On failure, show:**
```bash
show_recovery_help() {
    ui_header "
Installation Failed

To recover manually:
1. Boot from Arch USB
2. Unlock LUKS: cryptsetup open /dev/nvmeXnYpZ cryptroot
3. Mount: mount /dev/mapper/cryptroot /mnt
4. Chroot: arch-chroot /mnt
5. Fix issue and continue

Logs: $LOG_FILE
"
}
```

## Progress Tracking

### Phase Progress

**Show overall progress:**
```bash
TOTAL_PHASES=8
CURRENT_PHASE=0

run_phase() {
    ((CURRENT_PHASE++))
    ui_progress $CURRENT_PHASE $TOTAL_PHASES "$2"
    # ...
}
```

**Output:**
```
[1/8] Preparing environment...
[2/8] Partitioning disk...
[3/8] Setting up LUKS encryption...
```

## Testing Strategy

### Unit Tests

**Test individual functions:**
```bash
# test_hardware.sh
source lib/hardware.sh

test_detect_amd_gpu() {
    # Mock lspci
    lspci() { echo "01:00.0 VGA compatible controller: AMD"; }

    detect_gpu

    [[ "$HAS_AMD_GPU" == true ]] || {
        echo "FAIL: AMD GPU not detected"
        return 1
    }
}
```

### Integration Tests

**Test full flow in VM:**
```bash
# test_install.sh
qemu-system-x86_64 \
    -cdrom archlinux.iso \
    -drive file=test-disk.img,format=qcow2 \
    -m 4G \
    -enable-kvm \
    -boot d
```

### Dry Run Mode

**Test without actual changes:**
```bash
DRY_RUN=true

cryptsetup_wrapper() {
    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY RUN] Would run: cryptsetup $*"
        return 0
    else
        cryptsetup "$@"
    fi
}
```

## V1 Implementation Summary

**Architecture:**
- ✅ Modular scripts (8 phases)
- ✅ Common libraries (error handling, UI, hardware)
- ✅ Main orchestrator (install.sh)
- ✅ gum-based TUI
- ✅ Comprehensive logging
- ✅ Error recovery guidance

**Features:**
- ✅ Hardware auto-detection
- ✅ Progress tracking
- ✅ Cleanup on error
- ✅ Idempotent operations (where possible)
- ✅ State management
- ✅ Clear error messages

**Deferred to V2:**
- ⏳ Advanced testing framework
- ⏳ Dry-run mode
- ⏳ Resume from failed phase
- ⏳ Configuration file support
- ⏳ Non-interactive mode

## References

- [Bash Best Practices](https://bertvv.github.io/cheat-sheets/Bash.html)
- [Defensive BASH Programming](http://www.kfirlavi.com/blog/2012/11/14/defensive-bash-programming/)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
