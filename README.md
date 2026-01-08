# Arch Linux Installer (COSMIC Edition)

**Status: Phase 2 (Wintarch System Management) In Progress 🚧**

A dual-boot capable Arch Linux installer with COSMIC desktop, LUKS encryption, BTRFS snapshots, and self-managing system updates.

## Features

- **Dual-boot support** - Install alongside Windows or other Linux distros
- **LUKS encryption** - Full disk encryption (mandatory)
- **BTRFS with snapshots** - Automatic snapshots via Snapper
- **Bootable snapshots** - Boot into previous system states via Limine
- **COSMIC desktop** - Modern, Rust-based desktop environment
- **Self-managing updates** - `wintarch-update` for safe system updates with automatic snapshots

## Requirements

- UEFI system (Legacy BIOS not supported)
- Minimum 40GB free space
- Internet connection
- Arch Linux live USB

## Installation

Boot from Arch Linux live USB, then:

```bash
# Connect to internet (if on WiFi)
iwctl
# station wlan0 scan
# station wlan0 connect <network>

# One-liner install
curl -fsSL https://raw.githubusercontent.com/winterberryice/arch/master/boot.sh | bash

# Or clone and run manually
git clone https://github.com/winterberryice/arch.git
cd arch
./install/install.sh
```

## What Gets Installed

- Arch Linux base system
- COSMIC desktop environment
- Limine bootloader (with snapshot boot support)
- Snapper for BTRFS snapshots
- NetworkManager
- PipeWire audio

## Partition Layout

| Partition | Size | Type | Encryption |
|-----------|------|------|------------|
| EFI | 2GB | FAT32 | No |
| Root | Remaining | BTRFS | LUKS2 |

### BTRFS Subvolumes

- `@` → `/`
- `@home` → `/home`
- `@log` → `/var/log`
- `@pkg` → `/var/cache/pacman/pkg`

## System Updates

After installation, use `wintarch-update` for safe system updates:

```bash
wintarch-update        # Update system (creates snapshot first)
wintarch-update -y     # Skip confirmation
```

The update process:
1. Creates BTRFS snapshot (for easy rollback)
2. Pulls latest wintarch from git
3. Updates system packages (pacman + yay)
4. Runs any new migrations
5. Prompts for reboot if kernel updated

### Other Commands

```bash
wintarch-snapshot create "before experiment"  # Manual snapshot
wintarch-snapshot list                        # List snapshots
wintarch-snapshot restore                     # Restore from booted snapshot
wintarch-migrations                           # Check migration status
wintarch-version                              # Show version
```

### Rollback

If something breaks:
1. Reboot → Limine menu → "Snapshots" → select one
2. System boots into snapshot
3. Run `wintarch-snapshot restore` to make it permanent
4. Reboot

## Acknowledgments

Inspired by [Omarchy](https://omarchy.org) by DHH.

## License

MIT
