# Arch Linux Installer (COSMIC Edition)

## Project Overview

A dual-boot capable Arch Linux installer inspired by [Omarchy](https://github.com/basecamp/omarchy), but with:
- **COSMIC desktop** instead of Hyprland
- **Dual-boot support** (preserve Windows, use free space, or existing partitions)
- **LUKS encryption** (mandatory, like omarchy)
- **BTRFS with snapshots** via Snapper + Limine bootable snapshots

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  1. CONFIGURATOR (TUI)                                          │
│     - Keyboard layout selection                                 │
│     - User account (username, password)                         │
│     - Hostname, timezone                                        │
│     - Disk selection with dual-boot options                     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  2. PARTITIONING (custom, for dual-boot)                        │
│     - Detect/reuse existing EFI partition                       │
│     - Create LUKS container on selected space                   │
│     - Create BTRFS with subvolumes (@, @home, @log, @pkg)       │
│     - Mount to /mnt/archinstall                                 │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  3. ARCHINSTALL (pinned version: 3.0.14-1)                      │
│     - pre_mounted_config mode (uses our mounts)                 │
│     - Handles: packages, user, locale, Limine, Snapper          │
│     - JSON config generated dynamically                         │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  4. POST-INSTALL (chroot)                                       │
│     - limine-snapper-sync + limine-mkinitcpio-hook              │
│     - Configure /etc/default/limine                             │
│     - mkinitcpio with btrfs-overlayfs hook                      │
│     - limine-update for boot entries                            │
│     - COSMIC greeter setup                                      │
└─────────────────────────────────────────────────────────────────┘
```

## Key Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| archinstall | 3.0.14-1 (pinned) | Base system installation |
| gum | latest | TUI prompts and styling |
| limine | latest | Bootloader with snapshot support |
| snapper | latest | BTRFS snapshot management |
| cosmic | latest | Desktop environment |

## File Structure

```
arch/
├── CLAUDE.md              # This file
├── README.md              # User-facing documentation
├── install.sh             # Main entry point
├── lib/
│   ├── helpers.sh         # Logging, errors, presentation (from omarchy)
│   ├── configurator.sh    # TUI for user input
│   ├── disk.sh            # Disk detection and selection
│   ├── partitioning.sh    # LUKS, BTRFS, mounting
│   ├── archinstall.sh     # JSON generation, archinstall invocation
│   └── post-install.sh    # Limine-snapper setup, COSMIC config
├── old/                   # Previous implementation (reference)
└── vendor/
    ├── omarchy/           # Omarchy post-install scripts (reference)
    └── omarchy-iso/       # Omarchy ISO installer (reference)
```

## Disk Installation Modes

1. **Wipe entire disk** - Like omarchy, erases everything
2. **Use free space** - Finds unallocated space >= 40GB
3. **Use existing partition** - Format a specific partition
4. **Reuse Windows EFI** - Detect and share Windows EFI partition

## BTRFS Subvolume Layout

| Subvolume | Mountpoint | Purpose |
|-----------|------------|---------|
| @ | / | Root filesystem |
| @home | /home | User data |
| @log | /var/log | System logs |
| @pkg | /var/cache/pacman/pkg | Package cache |

Note: Snapper creates its own snapshot subvolume automatically.

## Encryption

- **LUKS2** encryption on the main BTRFS partition
- Boot partition (/boot) is **NOT encrypted** (required for Limine)
- Same password for user, root, and LUKS (like omarchy)

## mkinitcpio Hooks

```
HOOKS=(base udev keyboard autodetect microcode modconf kms keymap consolefont block encrypt filesystems fsck btrfs-overlayfs)
```

## Snapper Configuration

- Timeline snapshots: disabled (like omarchy)
- Number limit: 5 snapshots
- Space limit: 30% max, 30% free
- Boot menu: up to 5 snapshot entries via limine-snapper-sync

## Differences from Omarchy

| Aspect | Omarchy | This Project |
|--------|---------|--------------|
| Desktop | Hyprland | COSMIC |
| Disk mode | Wipe only | Dual-boot support |
| Auto-login | Yes (after LUKS) | No (multi-user) |
| Post-install config | Extensive | Minimal |

## Development Notes

### Testing
- Use QEMU with OVMF for EFI testing
- Run `./test.sh` to create disk and boot ISO
- Run `./test.sh --boot-disk` to test installed system

### Updating Archinstall
When archinstall updates break compatibility:
1. Check new JSON schema: `archinstall --dry-run`
2. Update lib/archinstall.sh
3. Update pinned version in this file and install.sh

### TUI Library
We use [gum](https://github.com/charmbracelet/gum) for all TUI interactions:
- `gum input` - text input
- `gum input --password` - password input
- `gum choose` - selection menu
- `gum confirm` - yes/no confirmation
- `gum spin` - spinner animation
- `gum style` - styled text output

## Reference Sources

### Our Code vs Omarchy References

| Our File | Based On | Purpose |
|----------|----------|---------|
| `lib/helpers.sh` | `omarchy/install/helpers/*.sh` | Logging, errors, TUI |
| `lib/configurator.sh` | `omarchy-iso/.../configurator` | User input TUI |
| `lib/disk.sh` | Custom + old implementation | Dual-boot disk detection |
| `lib/partitioning.sh` | Custom + old implementation | LUKS, BTRFS, mounting |
| `lib/archinstall.sh` | `omarchy-iso/.../.automated_script.sh` | JSON generation, archinstall |
| `lib/post-install.sh` | `omarchy/install/login/limine-snapper.sh` | Limine-Snapper setup |

### Key Reference Files
```
vendor/omarchy-iso/
├── configs/airootfs/root/
│   ├── configurator              # TUI for user input (gum-based)
│   └── .automated_script.sh      # archinstall invocation flow

vendor/omarchy/
├── install/
│   ├── helpers/                  # Presentation, errors, logging
│   ├── preflight/
│   │   └── disable-mkinitcpio.sh # Speed optimization (we copy this)
│   └── login/
│       └── limine-snapper.sh     # Snapper + Limine config (main reference)

old/
└── install/                      # Previous partitioning implementation
```

### mkinitcpio Optimization
Like omarchy, we disable mkinitcpio hooks during package installation to avoid
rebuilding initramfs multiple times. Hooks are re-enabled and initramfs is
rebuilt once at the end. See `lib/post-install.sh:disable_mkinitcpio_hooks()`
