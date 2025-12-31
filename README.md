# Arch Linux Installer (COSMIC Edition)

A dual-boot capable Arch Linux installer with COSMIC desktop, LUKS encryption, and BTRFS snapshots.

## Features

- **Dual-boot support** - Install alongside Windows or other Linux distros
- **LUKS encryption** - Full disk encryption (mandatory)
- **BTRFS with snapshots** - Automatic snapshots via Snapper
- **Bootable snapshots** - Boot into previous system states via Limine
- **COSMIC desktop** - Modern, Rust-based desktop environment

## Requirements

- UEFI system (Legacy BIOS not supported)
- Minimum 40GB free space
- Internet connection
- Arch Linux live USB

## Usage

Boot from Arch Linux live USB, then:

```bash
# Connect to internet (if on WiFi)
iwctl
# station wlan0 scan
# station wlan0 connect <network>

# Download and run installer
curl -fsSL https://raw.githubusercontent.com/winterberryice/arch/main/install.sh | bash

# Or clone and run
git clone https://github.com/winterberryice/arch.git
cd arch
./install.sh
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

## Acknowledgments

Inspired by [Omarchy](https://omarchy.org) by DHH.

## License

MIT
