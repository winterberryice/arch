# Implementation Strategy

## Overview

This document outlines the high-level implementation approach for the Arch Linux installer, focusing on the TUI-based information gathering phase and automated installation execution, similar to archinstall and omarchy.

## Design Philosophy

**Inspired by:**
- **archinstall** - Official Arch installer with TUI
- **omarchy** - Opinionated Arch installer ISO
- **Pop!_OS installer** - Clean UX, automated workflow

**Our approach:**
- Simple TUI for gathering all necessary information upfront
- Validate choices before proceeding
- Automated installation after confirmation
- Clear progress indication throughout
- Error recovery with helpful guidance

## Comparison with omarchy

### What We Can Reuse from omarchy

**Potential code to borrow:**
- Partition detection logic
- Disk layout algorithms
- Installation automation flow
- Error handling patterns
- Progress tracking mechanisms

**What we'll customize:**
- Partitioning (flexible, not full-disk wipe)
- Desktop environment (COSMIC instead of omarchy's choice)
- Configuration management (/opt/arch architecture)
- Multi-user support
- LUKS password handling

### Fork vs. Separate Project

**Considerations:**
- omarchy is MIT licensed (check before borrowing code)
- We have significant architectural differences (/opt/arch, multi-user)
- Our partitioning is more flexible
- Can start as fork, diverge over time
- Or reference omarchy code, rewrite with attribution

**Recommendation:** Start by studying omarchy, rewrite with clear attribution for borrowed concepts.

## Installation Flow

### Phase 1: Information Gathering (TUI)

**Concept:** Ask everything upfront, validate, then execute.

```
┌─────────────────────────────────────────┐
│  Arch Linux Installer                   │
├─────────────────────────────────────────┤
│                                         │
│  This installer will guide you through │
│  setting up Arch Linux with:           │
│                                         │
│  • LUKS encryption                      │
│  • BTRFS with snapshots                 │
│  • COSMIC desktop                       │
│  • Optional dual-boot with Windows      │
│                                         │
│         [Begin Setup] [Exit]            │
└─────────────────────────────────────────┘

    ↓ User clicks Begin

[Step 1/7] Disk Selection
[Step 2/7] Partitioning
[Step 3/7] Encryption
[Step 4/7] User Account
[Step 5/7] System Settings
[Step 6/7] Review Choices
[Step 7/7] Confirmation

    ↓ User confirms

Automated Installation (no more questions)
```

### Information Gathering Steps

**Step 1: Disk Selection**
```
Select installation disk:
> nvme0n1 (1TB NVMe SSD)
  sda (500GB SATA SSD)

Show current partition layout? [Yes]
```

**Step 2: Partitioning**
```
Partition method:
> Create in free space (preserve existing data)
  Use entire disk (ERASE ALL DATA)
  Manual partitioning (advanced)

[If "Create in free space" selected]
Available free space:
> 500GB after Windows partition
  100GB after /dev/sda1

[If "Use entire disk" selected - omarchy style]
⚠️  WARNING: This will ERASE ALL DATA on nvme0n1!
Confirm disk wipe: [type disk name to confirm]
```

**Step 3: Encryption Setup**
```
Enable LUKS encryption? [Yes] No

[If Yes]
Enter encryption password: ********
Confirm password: ********

Password strength: Strong ✓
- 16 characters
- Mix of letters, numbers, symbols

⚠️  CRITICAL: Forgotten password = permanent data loss!
```

**Step 4: User Account**
```
Username: january
Full name: January User
Password: ********
Confirm password: ********

Set root password? [Yes] No (lock root account)
```

**Step 5: System Settings**
```
Timezone:
> Europe/Warsaw
  America/New_York
  ...

Locale:
> en_US.UTF-8
  pl_PL.UTF-8
  ...

Hostname: archlinux

[Auto-detected]
✓ Hardware detected:
  CPU: AMD Ryzen 7 5800X → amd-ucode
  GPU: AMD Radeon RX 6800 → mesa drivers
```

**Step 6: Review Choices**
```
┌─────────────────────────────────────────┐
│  Installation Summary                   │
├─────────────────────────────────────────┤
│                                         │
│  Disk: /dev/nvme0n1                     │
│  Partition: Create in 500GB free space  │
│  Encryption: LUKS (enabled)             │
│                                         │
│  User: january                          │
│  Timezone: Europe/Warsaw                │
│  Locale: en_US.UTF-8                    │
│  Hostname: archlinux                    │
│                                         │
│  Hardware:                              │
│  • CPU: AMD Ryzen 7 5800X               │
│  • GPU: AMD Radeon RX 6800              │
│                                         │
│  Desktop: COSMIC                        │
│  Bootloader: systemd-boot               │
│                                         │
│       [Edit] [Proceed] [Cancel]         │
└─────────────────────────────────────────┘
```

**Step 7: Final Confirmation**
```
⚠️  Ready to install Arch Linux

The following actions will be performed:
1. Create partition on /dev/nvme0n1 (500GB)
2. Set up LUKS encryption
3. Create BTRFS filesystem with subvolumes
4. Install base system + COSMIC desktop
5. Configure system (timezone, locale, users)
6. Install systemd-boot bootloader

This process will take 10-30 minutes.

Type 'INSTALL' to proceed: _______
```

### Phase 2: Automated Installation

**Once confirmed, no more user input required!**

```
Installing Arch Linux...

[1/8] ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▱▱▱▱▱▱ 60%  Creating partitions
[2/8] ▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱  0%   Setting up LUKS
[3/8] ▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱  0%   Creating BTRFS
[4/8] ▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱  0%   Installing packages
[5/8] ▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱  0%   Configuring system
[6/8] ▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱  0%   Installing bootloader
[7/8] ▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱  0%   Setting up swap
[8/8] ▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱  0%   Finalizing

Current: Creating LUKS container...
```

## TUI Implementation

### Technology Stack

**Option 1: Python + urwid (like archinstall)**
- **Pros:** Rich TUI library, archinstall uses it
- **Cons:** Python dependency, more complex

**Option 2: Bash + dialog/whiptail**
- **Pros:** Simple, lightweight, no dependencies
- **Cons:** Basic UI, limited styling

**Option 3: Bash + gum (our current plan)**
- **Pros:** Modern, beautiful, simple commands
- **Cons:** External dependency (but small)

**Option 4: Rust + ratatui**
- **Pros:** Modern, performant, type-safe
- **Cons:** More development time, new language

**Recommendation:** Start with **gum** (Option 3)
- Consistent with our planning
- Beautiful modern UI
- Easy to prototype
- Can migrate to Rust later (V2) if needed

### State Management

**Store all choices in structured format:**

```bash
# /tmp/arch-install-config.json
{
  "disk": "/dev/nvme0n1",
  "partition_method": "free_space",
  "free_space_region": "500GB after nvme0n1p3",
  "luks_enabled": true,
  "luks_password": "[REDACTED]",
  "user": {
    "username": "january",
    "fullname": "January User",
    "password": "[REDACTED]"
  },
  "system": {
    "timezone": "Europe/Warsaw",
    "locale": "en_US.UTF-8",
    "hostname": "archlinux"
  },
  "hardware": {
    "cpu_vendor": "AMD",
    "gpu_vendor": "AMD",
    "microcode": "amd-ucode"
  },
  "desktop": "cosmic"
}
```

**Alternatively, shell variables:**
```bash
# /tmp/arch-install-config.sh
DISK="/dev/nvme0n1"
PARTITION_METHOD="free_space"
LUKS_ENABLED=true
USERNAME="january"
TIMEZONE="Europe/Warsaw"
CPU_VENDOR="AMD"
GPU_VENDOR="AMD"
DESKTOP="cosmic"
```

**Recommendation:** JSON for structure, easier to validate/edit

### Validation

**Validate before proceeding:**
- Disk exists and is accessible
- Free space is sufficient (min 20GB)
- Passwords match and meet minimum length
- Username is valid (lowercase, no spaces)
- Timezone exists
- Locale is available

**Show clear errors:**
```
❌ Invalid username: "User Name"
   Usernames must be lowercase, no spaces
   Example: username, user_name, user123
```

## Script Structure

### Directory Layout

```
install/
├── install.sh              # Main entry point (TUI launcher)
├── tui/
│   ├── main.sh            # TUI orchestrator
│   ├── 01-disk.sh         # Disk selection screen
│   ├── 02-partition.sh    # Partitioning screen
│   ├── 03-encryption.sh   # LUKS setup screen
│   ├── 04-user.sh         # User account screen
│   ├── 05-system.sh       # System settings screen
│   ├── 06-review.sh       # Review summary screen
│   └── 07-confirm.sh      # Final confirmation
├── lib/
│   ├── common.sh          # Shared functions
│   ├── ui.sh              # gum wrappers
│   ├── hardware.sh        # Detection functions
│   └── validation.sh      # Input validation
├── phases/
│   ├── 01-prepare.sh      # (from planning docs)
│   ├── 02-partition.sh
│   ├── 03-luks.sh
│   ├── 04-btrfs.sh
│   ├── 05-install.sh
│   ├── 06-configure.sh
│   ├── 07-bootloader.sh
│   └── 08-finalize.sh
└── config/
    └── state.json         # Generated during TUI
```

### Execution Flow

```bash
#!/bin/bash
# install.sh - Main entry point

# 1. Run TUI to gather information
./tui/main.sh

# Exits with state.json created

# 2. Load configuration
source lib/common.sh
load_config config/state.json

# 3. Run automated installation phases
run_phase "01-prepare"
run_phase "02-partition"
run_phase "03-luks"
run_phase "04-btrfs"
run_phase "05-install"
run_phase_in_chroot "06-configure"
run_phase_in_chroot "07-bootloader"
run_phase_in_chroot "08-finalize"

# 4. Success!
show_success_message
```

## Progress Indication

### During TUI

**Step progress:**
```
[Step 2/7] Partitioning
════════════════════▰▰▰▰▰▰▱▱▱▱▱▱▱▱ 29%
```

### During Installation

**Phase progress:**
```
[Phase 4/8] Installing packages (15-20 minutes)
████████████████▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱ 45%

Downloading packages... (1.2 GB)
▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▱▱ 457/1200 MB  [  5 min remaining]

Current: Installing cosmic-epoch...
```

**Detailed logs available:**
```
Press [L] to view detailed logs
Press [Ctrl+C] to cancel (will prompt for confirmation)
```

## Error Handling

### Recoverable Errors

**Show error, offer recovery:**
```
❌ Failed to create partition

Error: Insufficient free space (15GB available, 20GB required)

Options:
1. Select different free space region
2. Reduce partition size (not recommended)
3. Return to disk selection
4. Exit installer

Choose an option [1-4]:
```

### Fatal Errors

**Cleanup and exit gracefully:**
```
❌ Installation failed at phase 3/8 (LUKS setup)

Error: Failed to create LUKS container
Details: cryptsetup returned error code 5

Cleanup performed:
✓ Unmounted filesystems
✓ Closed LUKS containers
✓ Reverted partition changes

Recovery options:
1. View detailed error log
2. Return to TUI (fix configuration)
3. Exit to live environment

Log file: /var/log/arch-install-2025-01-15.log
```

## Testing Strategy

### TUI Testing

**Manual testing:**
- Navigate through all screens
- Test validation (invalid inputs)
- Test back/forward navigation
- Test configuration editing

**Automated testing (V2):**
- Mock user input
- Test all paths
- Validate state.json generation

### Installation Testing

**VM-based testing:**
- Different disk sizes
- Different free space scenarios
- Different hardware (AMD/Intel, AMD/NVIDIA)
- Dual-boot scenarios
- Fresh disk scenarios

## Omarchy Integration

### Code Review Checklist

**Before borrowing code from omarchy:**
1. Check license (MIT allows reuse with attribution)
2. Understand the code (don't blindly copy)
3. Adapt to our architecture
4. Add clear attribution comments
5. Test thoroughly

### Attribution Format

```bash
# Adapted from omarchy installer
# https://github.com/omarchy/omarchy
# License: MIT
# Original author: [name]
# Modified for: Flexible partitioning, /opt/arch architecture
```

## V1 Scope

**TUI Features:**
- ✅ All 7 information gathering screens
- ✅ Validation for all inputs
- ✅ Review and edit capability
- ✅ Clear progress indication
- ✅ Hardware auto-detection display

**Installation Features:**
- ✅ Automated execution (no user input after confirmation)
- ✅ Progress bars for each phase
- ✅ Error recovery with cleanup
- ✅ Detailed logging
- ✅ Success message with next steps

**Deferred to V2:**
- ⏳ Resume interrupted installation
- ⏳ Configuration presets/profiles
- ⏳ Non-interactive mode (config file input)
- ⏳ Advanced manual partitioning UI
- ⏳ Multiple desktop environment choices

## Next Steps

**Before implementation:**
1. Study omarchy codebase (identify reusable patterns)
2. Prototype TUI with gum (test user flow)
3. Finalize state management format
4. Create mock installation (dry-run mode)

**Implementation order:**
1. lib/ui.sh (gum wrappers)
2. lib/validation.sh (input validation)
3. TUI screens (01-07)
4. Integration with installation phases
5. Error handling and recovery
6. Testing in VMs

## References

- [archinstall source](https://github.com/archlinux/archinstall)
- [omarchy source](https://github.com/omarchy/omarchy) (if available)
- [gum documentation](https://github.com/charmbracelet/gum)
- [Pop!_OS installer](https://github.com/pop-os/distinst) (for UX inspiration)
