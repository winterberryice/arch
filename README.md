# Wintarch

An opinionated Arch Linux distribution featuring the COSMIC desktop environment, BTRFS snapshots, and simple system management.

Inspired by [Omarchy](https://github.com/basecamp/omarchy), but with COSMIC instead of Hyprland and dual-boot support.

## Features

- **COSMIC Desktop** - System76's modern, Rust-based desktop environment
- **BTRFS with Snapshots** - Automatic snapshots before updates, bootable rollback via Limine
- **LUKS Encryption** - Full disk encryption (mandatory)
- **Dual-Boot Friendly** - Preserve Windows, use free space, or existing partitions
- **Smart Swap** - Two-tier swap (zram + swapfile), hibernation-ready
- **Simple Updates** - One command (`wintarch-update`) handles everything safely
- **Pre-configured** - Ready to use out of the box

## What's Included

### Desktop & System
- COSMIC desktop + greeter
- PipeWire audio
- NetworkManager
- Bluetooth (bluez + bluez-utils, service enabled)
- Power profiles daemon

### Applications
- Firefox - Web browser
- Brave - Privacy-focused browser (AUR)
- VS Code - Code editor (AUR)
- Vim - Terminal editor

### Shell & Tools
- Zsh + Oh My Zsh - Modern shell with plugins (optional, via `wintarch-user-update`)
- Git - Version control
- yay - AUR helper

## Requirements

- UEFI system (Legacy BIOS not supported)
- Minimum 40GB free space
- Internet connection

## Installation

Boot from Arch Linux live USB, then:

```bash
# Connect to internet (if on WiFi)
iwctl
# station wlan0 scan
# station wlan0 connect <network>

# One-liner install (recommended)
curl -fsSL https://raw.githubusercontent.com/winterberryice/arch/master/boot.sh | bash

# Or clone manually
git clone https://github.com/winterberryice/arch.git
cd arch
./install/install.sh
```

The TUI installer will guide you through:
- Keyboard layout
- Username & password
- Hostname & timezone
- Disk selection (wipe, use free space, or existing partition)

## Partition Layout

| Partition | Size | Type | Encryption |
|-----------|------|------|------------|
| EFI | 2GB | FAT32 | No |
| Root | Remaining | BTRFS | LUKS2 |

### BTRFS Subvolumes

| Subvolume | Mountpoint | Purpose |
|-----------|------------|---------|
| @ | / | Root filesystem |
| @home | /home | User data |
| @log | /var/log | System logs |
| @pkg | /var/cache/pacman/pkg | Package cache |
| @swap | /swap | Swap storage |

## System Management

### Update System
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

### Manage Snapshots
```bash
wintarch-snapshot list              # List all snapshots
wintarch-snapshot create "message"  # Create manual snapshot
wintarch-snapshot delete 5          # Delete snapshot #5
wintarch-snapshot restore           # Restore from booted snapshot
```

### Package Management
```bash
wintarch-pkg-add package-name   # Install with verification
wintarch-pkg-drop package-name  # Remove (no error if missing)
```

### User Configuration
```bash
wintarch-user-update  # Setup/update user config (Oh My Zsh, dotfiles)
```

First run installs Oh My Zsh with plugins and sets zsh as default shell. Subsequent runs update OMZ and plugins.

### Other Commands
```bash
wintarch-version      # Show installed version
wintarch-migrations   # Check migration status
```

## Bootable Snapshots

If something breaks:
1. Reboot -> Limine menu -> "Snapshots" -> select one
2. System boots into snapshot (read-only overlay)
3. Run `wintarch-snapshot restore` to make it permanent
4. Reboot

Up to 5 snapshots appear in the boot menu via limine-snapper-sync.

## Swap Configuration

Wintarch uses a two-tier swap system for optimal performance:

### What's Configured

- **Zram** (50% of RAM, compressed) - Fast swap in RAM, used first
- **Swapfile** (same size as RAM) - Disk-based swap, used as fallback

### How It Works

The system prioritizes zram for fast swapping of inactive apps and browser tabs. When zram fills up, it overflows to the disk-based swapfile. This gives you the best of both worlds: speed and capacity.

### Checking Swap Status

```bash
swapon --show
# NAME           TYPE SIZE  USED PRIO
# /dev/zram0     zram  8G    2G  100   <- Used first (fast)
# /swap/swapfile file 16G   500M   1   <- Fallback
```

### Enabling Hibernation (Optional)

The swapfile is sized to support hibernation but it's not enabled by default. To enable:

1. Calculate the swapfile offset:
   ```bash
   sudo btrfs inspect-internal map-swapfile -r /swap/swapfile
   # Output: 123456 (save this number)
   ```

2. Add resume hook to mkinitcpio (after `encrypt`):
   ```bash
   sudo vim /etc/mkinitcpio.conf.d/arch-cosmic.conf
   # Change: HOOKS=(... block encrypt filesystems ...)
   # To:     HOOKS=(... block encrypt resume filesystems ...)
   ```

3. Update kernel parameters in Limine:
   ```bash
   sudo vim /etc/default/limine
   # Add to KERNEL_CMDLINE[default]:
   # resume=/dev/mapper/cryptroot resume_offset=123456
   ```

4. Rebuild initramfs and update bootloader:
   ```bash
   sudo mkinitcpio -P
   sudo limine-snapper-sync
   ```

5. Test hibernation:
   ```bash
   systemctl hibernate
   ```

**Note:** If you upgrade your RAM in the future, you'll need to recreate the swapfile and recalculate the offset.

## Differences from Omarchy

| Aspect | Omarchy | Wintarch |
|--------|---------|----------|
| Desktop | Hyprland | COSMIC |
| Disk mode | Wipe only | Dual-boot support |
| Auto-login | Yes | No (multi-user) |
| Target | Single user | General purpose |

## License

MIT

## Acknowledgments

Inspired by [Omarchy](https://omarchy.org) by DHH.

## Contributing

Want to contribute? See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, architecture overview, and how to submit changes.
