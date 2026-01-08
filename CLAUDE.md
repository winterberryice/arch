# Arch Linux Installer (COSMIC Edition)

## Project Status

### ✅ Phase 1: Base Installer - **COMPLETE**
The base system installer is fully functional and tested:
- LUKS encryption with BTRFS subvolumes
- Limine bootloader with snapshot support
- COSMIC desktop environment
- Dual-boot partitioning support
- Snapper snapshot management

### 🚧 Phase 2: Wintarch System Management - **IN PROGRESS**
Git-based system management layer (like omarchy):
- `wintarch-update`: Snapshot-first system updates
- `wintarch-snapshot`: BTRFS snapshot management
- `wintarch-migrations`: Migration system for evolving installs
- `wintarch-pkg-add/drop`: Safe package helpers

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
| archinstall | 3.0.9-1 (pinned) | Base system installation |
| gum | latest | TUI prompts and styling |
| limine | latest | Bootloader with snapshot support |
| snapper | latest | BTRFS snapshot management |
| cosmic | latest | Desktop environment |

## File Structure

```
arch/
├── bin/                   # Wintarch commands (symlinked to /usr/local/bin/)
│   ├── wintarch-update    # Main update command
│   ├── wintarch-snapshot  # BTRFS snapshot management
│   ├── wintarch-migrations # Migration runner
│   ├── wintarch-pkg-add   # Safe package install
│   ├── wintarch-pkg-drop  # Safe package removal
│   └── wintarch-version   # Show version
├── install/               # Phase 1 installer scripts
│   ├── install.sh         # Main entry point
│   ├── helpers.sh         # Logging, errors, presentation
│   ├── configurator.sh    # TUI for user input
│   ├── disk.sh            # Disk detection and selection
│   ├── partitioning.sh    # LUKS, BTRFS, mounting
│   ├── archinstall.sh     # JSON generation, archinstall invocation
│   └── post-install.sh    # Limine-snapper setup, wintarch setup
├── migrations/            # Wintarch migrations (timestamp-named .sh files)
├── version                # Wintarch version (e.g., v0.1.0)
├── docs/                  # Documentation
├── test/                  # Test scripts
├── old/                   # Previous implementation (reference)
└── vendor/                # Vendored dependencies (omarchy reference)
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
- Run `./test/test.sh` to create disk and boot ISO
- Run `./test/test.sh --boot-disk` to test installed system

### Updating Archinstall
When archinstall updates break compatibility:
1. Check new JSON schema: `archinstall --dry-run`
2. Update install/archinstall.sh
3. Update pinned version in this file and install/install.sh

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
| `install/helpers.sh` | `omarchy/install/helpers/*.sh` | Logging, errors, TUI |
| `install/configurator.sh` | `omarchy-iso/.../configurator` | User input TUI |
| `install/disk.sh` | Custom + old implementation | Dual-boot disk detection |
| `install/partitioning.sh` | Custom + old implementation | LUKS, BTRFS, mounting |
| `install/archinstall.sh` | `omarchy-iso/.../.automated_script.sh` | JSON generation, archinstall |
| `install/post-install.sh` | `omarchy/install/login/limine-snapper.sh` | Limine-Snapper setup |
| `bin/wintarch-*` | `omarchy/bin/omarchy-*` | System management commands |

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
rebuilt once at the end. See `install/post-install.sh:disable_mkinitcpio_hooks()`

## Phase 2: Wintarch System Management

Phase 2 introduces **wintarch** - a git-based system management layer inspired by omarchy.

### Key Decisions
| Aspect | Decision |
|--------|----------|
| Name | wintarch |
| Repo location | `/opt/wintarch/` (whole repo cloned here) |
| State location | `/var/lib/wintarch/` |
| Commands | Symlinks in `/usr/local/bin/` → `/opt/wintarch/bin/` |
| Versioning | Semver (v0.1.0, v0.2.0, ...) |
| Migrations | Unix timestamp filenames (e.g., `1704067200.sh`) |

### Wintarch Commands
| Command | Description |
|---------|-------------|
| `wintarch-update` | Main update: snapshot → git pull → packages → migrations |
| `wintarch-snapshot` | Create/list/delete BTRFS snapshots via snapper |
| `wintarch-migrations` | Show pending/completed migrations, run manually |
| `wintarch-pkg-add` | Safe package install with verification |
| `wintarch-pkg-drop` | Safe package removal (no error if missing) |
| `wintarch-version` | Show installed version |

### Update Flow
```
wintarch-update
├── 1. Confirm with user (skip with -y)
├── 2. Create BTRFS snapshot (pre-update-v0.1.0-to-v0.2.0)
├── 3. git pull /opt/wintarch
├── 4. Update system packages (pacman + yay)
├── 5. Remove orphan packages
├── 6. Run pending migrations
├── 7. Update command symlinks
└── 8. Check if reboot needed (kernel update)
```

### Fresh Install Setup
During Phase 1 post-install:
1. Clone repo to `/opt/wintarch/`
2. Create `/var/lib/wintarch/` state directory
3. Mark all existing migrations as completed (fresh install = current state)
4. Create symlinks in `/usr/local/bin/`
5. Write version to `/var/lib/wintarch/version`

### Full Specification
See **[docs/PHASE2-SPEC.md](docs/PHASE2-SPEC.md)** for complete architecture and rationale.

