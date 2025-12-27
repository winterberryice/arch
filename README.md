# arch

Arch Linux distribution for disposable, multi-user systems.

## Problem & Solution

**Problem**: Omarchy is single-user only, traditional /etc/ configs create .pacnew hell
**Solution**: System-wide XDG defaults + per-user configs + version migrations

## Architecture

```
/opt/arch/
├── bin/
│   ├── arch-update-system   # System updater (sudo)
│   └── arch-update-user     # User updater (no sudo)
├── system/
│   ├── configs/etc/xdg/     # System defaults → /etc/xdg/
│   └── packages.list        # Packages to install
├── user/
│   ├── dotfiles/            # Initial configs → ~/.config/
│   └── migrations/          # Version-based updates
└── version                  # Current version

~/.local/share/arch-state/version  # User's version
~/.config/                         # User configs (overrides system)
```

## Config Priority

```
~/.config/ > /etc/xdg/ > /usr/share/
(user)       (arch)      (packages)
```

Users can override system defaults. Packages rarely touch /etc/xdg/ → minimal .pacnew conflicts.

## Update Flow

**System**: `sudo arch-update-system`
1. Update packages (`pacman -Syu`)
2. Pull repo (`git pull`)
3. Install packages from list
4. Sync configs to /etc/xdg/

**User**: `arch-update-user`
1. If version=0: Copy dotfiles (first run)
2. If version<latest: Run migrations
3. Update version file

## Key Decisions

- Single repo at /opt/arch/
- Two scripts (system vs user, privilege separation)
- /etc/xdg/ for system configs (avoid .pacnew)
- Integer versions with migrations
- Copy dotfiles (users own their configs)

## Status

**Phase 0: COMPLETE ✅** - Automated installer tested and working in QEMU
**Phase 1: PLANNING** - Interactive configuration and real hardware safety

See [`docs/PHASE-0-COMPLETE.md`](docs/PHASE-0-COMPLETE.md) for Phase 0 summary and results.

## Phase 0 - MVP Installer (✅ COMPLETE)

**Goal:** Bare Arch + COSMIC Desktop, testable in QEMU
**Status:** Complete and tested (2025-12-27)

**Achieved:**
- ✅ BTRFS with subvolumes (@, @home, @snapshots, @var_log, @swap)
- ✅ systemd-boot bootloader with PARTUUID
- ✅ Hardware auto-detection (AMD/Intel CPU, AMD/NVIDIA/Intel GPU)
- ✅ Full COSMIC desktop environment (24 packages)
- ✅ PipeWire audio stack
- ✅ Automated installation (no prompts)
- ✅ Modular architecture (lib/, phases/)
- ✅ Mirror optimization with retry logic
- ✅ Boots successfully in QEMU
- ✅ Clean, formatted output

**Known Limitations (by design):**
- ⚠️ Hardcoded test credentials (username: january, password: test123)
- ⚠️ Auto-wipes first detected disk (no selection)
- ⚠️ No security hardening
- ⚠️ QEMU testing only - not safe for real hardware yet

## Phase 1 - Interactive & Safe (NEXT)

Making the installer safe for real hardware.

**Planned Features:**
- 🔲 Interactive disk selection
- 🔲 Interactive configuration (passwords, username, hostname, timezone)
- 🔲 Safety prompts and confirmations
- 🔲 Security hardening (permissions, firewall)
- 🔲 User-friendly TUI (gum or dialog)
- 🔲 Better error recovery

**Deferred to Later Phases:**
- ⏳ Full LUKS encryption
- ⏳ Dual-boot with Windows
- ⏳ Flexible partitioning
- ⏳ Snapshot configuration

**Getting Started:**
- [`install/README.md`](install/README.md) - Installation instructions
- [`test/qemu-test.sh`](test/qemu-test.sh) - QEMU testing helper

**Planning Documentation:**
- [`docs/001-partitioning.md`](docs/001-partitioning.md) - Partitioning strategy and dual-boot setup
- [`docs/002-gpu-detection.md`](docs/002-gpu-detection.md) - GPU detection and driver installation
- [`docs/003-luks-setup.md`](docs/003-luks-setup.md) - LUKS encryption workflow
- [`docs/004-systemd-boot.md`](docs/004-systemd-boot.md) - systemd-boot bootloader configuration
- [`docs/005-installation-flow.md`](docs/005-installation-flow.md) - Installation script architecture
- [`docs/006-implementation-strategy.md`](docs/006-implementation-strategy.md) - Implementation approach
- [`TODO.md`](TODO.md) - V1 roadmap and future features

## Quick Start

### Installation (⚠️ QEMU Testing Only)

```bash
# From Arch Linux live environment
git clone https://github.com/winterberryice/arch.git
cd arch/install
sudo ./install.sh
```

**⚠️ WARNING:** Phase 0 wipes the first detected disk and uses hardcoded passwords!
See [install/README.md](install/README.md) for details.

### QEMU Testing

```bash
# Install QEMU
sudo pacman -S qemu-full edk2-ovmf

# Download Arch ISO to test/ directory
cd test
wget https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso

# Run installer in QEMU
./qemu-test.sh install
```

## Repository Structure

```
arch/
├── install/              # Phase 0 installer (IMPLEMENTED)
│   ├── install.sh       # Main orchestrator
│   ├── lib/             # Common libraries
│   │   ├── common.sh   # Error handling, logging
│   │   ├── hardware.sh # GPU/CPU detection
│   │   └── ui.sh       # Output functions
│   └── phases/          # Installation phases
│       ├── 01-prepare.sh
│       ├── 02-partition.sh
│       ├── 03-btrfs.sh
│       ├── 04-install.sh
│       ├── 05-configure.sh
│       ├── 06-bootloader.sh
│       └── 07-finalize.sh
├── test/                # Testing utilities
│   └── qemu-test.sh    # QEMU helper script
├── docs/                # Planning documentation
├── archive/             # Old scripts (reference)
└── README.md           # This file
```
