# Wintarch

An opinionated Arch Linux distribution featuring the COSMIC desktop environment, BTRFS snapshots, and simple system management.

Inspired by [Omarchy](https://github.com/basecamp/omarchy), but with COSMIC instead of Hyprland and dual-boot support.

## Features

- **COSMIC Desktop** - System76's modern, Rust-based desktop environment
- **BTRFS with Snapshots** - Automatic snapshots before updates, bootable rollback via Limine
- **LUKS Encryption** - Full disk encryption (mandatory)
- **Dual-Boot Friendly** - Preserve Windows, use free space, or existing partitions
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

## Development & Release

This project uses a semi-automated release process managed by GitHub Actions. A maintainer triggers the process, and the action handles the repetitive tasks of versioning and creating the release commit.

### Release Process

To create a new release, a project maintainer must post a specific comment on an approved pull request. This action triggers a workflow that will automatically merge the PR, bump the version, create a Git tag, and publish a new GitHub Release.

**1. Comment on the Pull Request**

Use one of the following commands in a comment on the PR you want to release:

-   `/release patch` - For bugfixes and small changes (e.g., v0.1.0 -> v0.1.1).
-   `/release minor` - For new features (e.g., v0.1.1 -> v0.2.0).
-   `/release major` - For significant, breaking changes (e.g., v0.2.0 -> v1.0.0).

**2. Specify a Merge Strategy (Optional)**

By default, the action will create a merge commit. To perform a squash merge instead, add the `--squash` flag to your command:

-   `/release patch --squash`

**3. Let the Automation Handle the Rest**

The GitHub Action will:
1.  Merge the pull request using your chosen strategy.
2.  Bump the version number in the `version` file.
3.  Create a single, clean commit on the `master` branch (e.g., `chore(release): v0.2.0`).
4.  Tag that commit.
5.  Close the pull request with a comment linking to the new release.
6.  A second workflow will see the new tag and publish a formal GitHub Release with auto-generated notes.

### Setup

For the release workflow to function, a **Personal Access Token (PAT)** must be created and added to the repository's secrets.

1.  **Create a PAT:**
    *   Go to your GitHub account's **Settings > Developer settings > Personal access tokens (classic)**.
    *   Generate a new token with the `repo` scope.
2.  **Add the secret to the repository:**
    *   In the Wintarch repository, go to **Settings > Secrets and variables > Actions**.
    *   Create a new repository secret named `PAT_TOKEN`.
    *   Paste your PAT as the value.

The workflow requires this token to have the necessary permissions to push the release commit and the new tag back to the `master` branch.
