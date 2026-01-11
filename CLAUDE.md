# Wintarch - Development Guide

Technical documentation for developing and maintaining Wintarch.

## Project Status

- **Phase 1: Installer** - Complete
- **Phase 2: System Management (wintarch-*)** - Complete
- **Phase 3: User Configuration** - In Progress

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  1. CONFIGURATOR (TUI)                                          │
│     - Keyboard layout, user account, hostname, timezone         │
│     - Disk selection with dual-boot options                     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  2. PARTITIONING                                                │
│     - Detect/reuse existing EFI partition                       │
│     - Create LUKS container, BTRFS with subvolumes              │
│     - Mount to /mnt/archinstall                                 │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  3. ARCHINSTALL (pinned version: 3.0.9-1)                       │
│     - pre_mounted_config mode (uses our mounts)                 │
│     - JSON config generated dynamically                         │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  4. POST-INSTALL (chroot)                                       │
│     - mkinitcpio with encrypt + btrfs-overlayfs hooks           │
│     - Limine bootloader configuration                           │
│     - Snapper setup, AUR packages (yay, brave, vscode)          │
│     - Wintarch setup (/opt/wintarch/, symlinks, state)          │
└─────────────────────────────────────────────────────────────────┘
```

## File Structure

```
arch/
├── bin/                   # Wintarch commands (symlinked to /usr/local/bin/)
│   ├── wintarch-update    # System update command
│   ├── wintarch-user-update # User configuration (OMZ, dotfiles)
│   ├── wintarch-snapshot  # BTRFS snapshot management
│   ├── wintarch-migrations # Migration runner
│   ├── wintarch-pkg-add   # Safe package install
│   ├── wintarch-pkg-drop  # Safe package removal
│   └── wintarch-version   # Show version
├── user/                  # User-level configuration
│   ├── scripts/           # Setup/update scripts (omz.sh)
│   └── dotfiles/          # Managed dotfiles (zshrc, aliases)
├── install/               # Installer scripts
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
│   └── PHASE2-SPEC.md     # Wintarch system management spec
├── test/                  # Test scripts
└── vendor/                # Vendored dependencies (omarchy reference)
```

## Key Implementation Details

### Packages (install/archinstall.sh)

Base packages via archinstall JSON:
- base-devel, git, curl, less, vim, networkmanager
- snapper, limine, cosmic, cosmic-greeter
- xdg-desktop-portal-cosmic, power-profiles-daemon
- firefox, zsh, bluez, bluez-utils

AUR packages via yay (install/post-install.sh):
- limine-snapper-sync, limine-mkinitcpio-hook
- brave-bin, visual-studio-code-bin

### Services Enabled

- NetworkManager.service
- cosmic-greeter.service
- power-profiles-daemon.service
- bluetooth.service
- limine-snapper-sync.service

### mkinitcpio Hooks

```
HOOKS=(base udev keyboard autodetect microcode modconf kms keymap consolefont block encrypt filesystems fsck btrfs-overlayfs)
```

### mkinitcpio Optimization

We disable mkinitcpio hooks during post-install to avoid multiple rebuilds:
- `install/post-install.sh:disable_mkinitcpio_hooks()` - disables before package installs
- `install/post-install.sh:enable_mkinitcpio_hooks()` - re-enables at the end
- Single `mkinitcpio -P` at the end

### Wintarch Locations

| Path | Purpose |
|------|---------|
| `/opt/wintarch/` | Full repo (bin/, migrations/, install/) |
| `/var/lib/wintarch/` | State directory |
| `/var/lib/wintarch/version` | Installed version |
| `/var/lib/wintarch/migrations/` | Completed migration markers |
| `/usr/local/bin/wintarch-*` | Symlinks to /opt/wintarch/bin/ |

### Migrations

- Filename format: Unix timestamp (e.g., `1704067200.sh`)
- Fresh installs mark all existing migrations as completed
- `wintarch-update` runs pending migrations after package updates

## Development

### Testing
```bash
./test/test.sh              # Create disk and boot ISO
./test/test.sh --boot-disk  # Test installed system
```

Uses QEMU with OVMF for EFI testing.

### Updating Archinstall

When archinstall updates break compatibility:
1. Check new JSON schema: `archinstall --dry-run`
2. Update `install/archinstall.sh`
3. Update pinned version (currently 3.0.9-1)

### TUI Library

Uses [gum](https://github.com/charmbracelet/gum):
- `gum input` / `gum input --password`
- `gum choose` / `gum confirm`
- `gum spin` / `gum style`

## Reference Sources

### Code Origins

| Our File | Based On |
|----------|----------|
| `install/helpers.sh` | `omarchy/install/helpers/*.sh` |
| `install/configurator.sh` | `omarchy-iso/.../configurator` |
| `install/archinstall.sh` | `omarchy-iso/.../.automated_script.sh` |
| `install/post-install.sh` | `omarchy/install/login/limine-snapper.sh` |
| `bin/wintarch-*` | `omarchy/bin/omarchy-*` |

### Omarchy Reference Files
```
vendor/omarchy-iso/configs/airootfs/root/
├── configurator              # TUI for user input
└── .automated_script.sh      # archinstall flow

vendor/omarchy/install/
├── helpers/                  # Presentation, errors, logging
├── preflight/disable-mkinitcpio.sh  # Speed optimization
└── login/limine-snapper.sh   # Snapper + Limine config
```

## User Configuration

Per-user configuration separate from system updates. Designed for on-demand use.

### Commands

| Command | Purpose |
|---------|---------|
| `wintarch-update` | System updates (packages, migrations). Optionally runs user update. |
| `wintarch-user-update` | User config (OMZ, dotfiles). Self-bootstrapping on first run. |

### User State

| Path | Purpose |
|------|---------|
| `~/.local/state/wintarch/` | Per-user state directory |
| `~/.local/state/wintarch/user-setup-done` | Marker for first-run completion |
| `~/.oh-my-zsh/` | Oh My Zsh installation |

### What `wintarch-user-update` Does

**First run**: Installs OMZ, plugins, configures zshrc, sets zsh as default shell
**Subsequent runs**: Updates OMZ and plugins

### Dotfiles Strategy

Uses source pattern - user's `~/.zshrc` sources managed config:
```bash
# ~/.zshrc
source /opt/wintarch/user/dotfiles/zshrc  # Managed by wintarch
# User customizations below...
```

This allows updates without overwriting user customizations.
