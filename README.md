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

**Current**: Planning phase - Installation system design
**Next**: GPU detection, LUKS workflow, script implementation

## Installation Planning

The installer supports flexible dual-boot scenarios with Windows, full LUKS encryption, and BTRFS with snapshots.

**Key Features:**
- ✅ Dual-boot with Windows (either install order)
- ✅ Full LUKS encryption (except /boot)
- ✅ BTRFS with subvolumes (@, @home, @snapshots, @var_log, @swap)
- ✅ systemd-boot bootloader
- ✅ TUI-based partitioning (gum)
- ✅ AMD/NVIDIA GPU detection
- ✅ zram + swapfile (hibernation in V2)

**Documentation:**
- [`docs/001-partitioning.md`](docs/001-partitioning.md) - Partitioning strategy and dual-boot setup
- [`TODO.md`](TODO.md) - V1 roadmap and future features

## Reference Files

- `bin/` - Update script templates (stubs with TODOs)
- `system/` - Example system configs and package list
- `user/` - Example dotfiles and migration template
- `pre_install.sh`, `system_config.sh` - Original installation scripts
