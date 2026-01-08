# Phase 2 Specification: Wintarch System Management

## Overview

**Wintarch** is a git-based system management layer for the Arch Linux installer, inspired by [omarchy](https://github.com/basecamp/omarchy). It provides:

- Centralized system updates with automatic BTRFS snapshots
- Migration system for evolving installed systems
- Custom commands for system management

## Design Decisions

### Naming
- **Name**: wintarch (winter + arch, from maintainer handle @winterberryice)
- **Commands**: `wintarch-*` prefix (e.g., `wintarch-update`)

### File Locations

| Path | Purpose |
|------|---------|
| `/opt/wintarch/` | Git repository (source of truth) |
| `/opt/wintarch/bin/` | Command scripts |
| `/opt/wintarch/migrations/` | Migration scripts |
| `/var/lib/wintarch/` | Persistent state |
| `/var/lib/wintarch/migrations/` | Migration completion markers |
| `/var/lib/wintarch/version` | Currently installed version |
| `/var/log/wintarch-install.log` | Installation log |
| `/var/log/wintarch-update.log` | Update operations log |
| `/usr/local/bin/wintarch-*` | Symlinks to commands |

### Versioning
- **Format**: Semantic versioning (semver)
- **Examples**: `v0.1.0`, `v0.2.0`, `v1.0.0`
- **Tracked via**: Git tags

### Migration Naming
- **Format**: Unix timestamp (seconds since epoch)
- **Example**: `1704067200.sh` (January 1, 2024 00:00:00 UTC)
- **Generate with**: `date +%s`
- **Rationale**: Auto-sortable, no merge conflicts, used by omarchy

## Architecture

### Directory Structure

```
/opt/wintarch/
├── bin/
│   ├── wintarch-update          # Main update command
│   ├── wintarch-snapshot        # Snapshot management
│   ├── wintarch-migrations      # Migration status
│   ├── wintarch-rollback        # Rollback assistance
│   └── wintarch-version         # Show version
├── migrations/
│   ├── 1704067200.sh            # Example migration
│   └── 1706745600.sh            # Another migration
├── lib/
│   └── helpers.sh               # Shared functions
└── version                      # Current version file

/var/lib/wintarch/
├── migrations/
│   ├── 1704067200.sh            # Marker: migration completed
│   └── 1706745600.sh            # Marker: migration completed
└── version                      # Installed version

/usr/local/bin/
├── wintarch-update -> /opt/wintarch/bin/wintarch-update
├── wintarch-snapshot -> /opt/wintarch/bin/wintarch-snapshot
└── ...                          # Symlinks to all commands
```

## Commands

### wintarch-update

Main system update command. **Creates snapshot first, always.**

**Flow:**
```
wintarch-update
├── 1. Confirm with user (skip with -y flag)
├── 2. Create BTRFS snapshot (pre-update-v0.1.0-to-v0.2.0)
├── 3. git pull /opt/wintarch
├── 4. Run pending migrations
├── 5. System package update (yay -Syyu)
├── 6. Remove orphan packages
├── 7. Update command symlinks (if new commands added)
├── 8. Log to /var/log/wintarch-update.log
└── 9. Check if reboot needed (kernel update)
```

**Flags:**
- `-y` : Skip confirmation prompt
- `--no-snapshot` : Skip snapshot (not recommended)

### wintarch-snapshot

BTRFS snapshot management.

**Usage:**
```bash
wintarch-snapshot create [description]  # Create snapshot
wintarch-snapshot list                  # List snapshots
wintarch-snapshot delete <number>       # Delete snapshot
```

### wintarch-migrations

Check migration status.

**Usage:**
```bash
wintarch-migrations              # Show pending migrations
wintarch-migrations --status     # Show all (pending + completed)
wintarch-migrations --run        # Run pending migrations manually
```

### wintarch-rollback

Assist with system rollback.

**Usage:**
```bash
wintarch-rollback                # List available snapshots
wintarch-rollback <snapshot>     # Instructions for rollback
```

### wintarch-version

Show version information.

**Usage:**
```bash
wintarch-version                 # Show installed version
wintarch-version --check         # Check for updates
```

## Migration System

### How Migrations Work

Migrations are one-time scripts that transform an installed system from one state to another. They only run on **existing installations**, never on fresh installs.

**Key Insight**: Fresh installs don't need migrations because the installation scripts already create the current desired state.

### Migration Script Structure

```bash
#!/bin/bash
# Migration: 1704067200.sh
# Description: Replace foo with bar
# Date: 2024-01-01

set -euo pipefail

# Migration logic here
pacman -Rs --noconfirm foo
pacman -S --noconfirm bar

echo "Migration complete: replaced foo with bar"
```

### Migration Runner Logic

```bash
run_migrations() {
    local state_dir="/var/lib/wintarch/migrations"
    mkdir -p "$state_dir"

    for migration in /opt/wintarch/migrations/*.sh; do
        [[ -f "$migration" ]] || continue

        local name=$(basename "$migration")
        local marker="$state_dir/$name"

        # Skip if already run
        [[ -f "$marker" ]] && continue

        echo "Running migration: $name"
        if bash "$migration"; then
            touch "$marker"
            echo "Migration completed: $name"
        else
            # Failed - prompt to skip (omarchy style)
            if gum confirm "Migration failed. Skip and continue?"; then
                touch "$marker"  # Mark as done to prevent retry
                echo "Skipped: $name"
            else
                echo "Aborting migrations"
                return 1
            fi
        fi
    done
}
```

### Fresh Install Initialization

On fresh install, mark all existing migrations as completed:

```bash
initialize_migration_state() {
    local state_dir="/var/lib/wintarch/migrations"
    mkdir -p "$state_dir"

    # Mark all current migrations as "already applied"
    for migration in /opt/wintarch/migrations/*.sh; do
        [[ -f "$migration" ]] || continue
        touch "$state_dir/$(basename "$migration")"
    done
}
```

This is called during Phase 1 post-install, ensuring fresh systems start clean.

### Creating New Migrations

```bash
# Helper command (optional)
wintarch-dev-add-migration "description of change"

# Or manually:
timestamp=$(date +%s)
cat > "/opt/wintarch/migrations/${timestamp}.sh" << 'EOF'
#!/bin/bash
# Migration description here
set -euo pipefail

# Migration logic
EOF
chmod +x "/opt/wintarch/migrations/${timestamp}.sh"
```

## Snapshot Naming

Pre-update snapshots use descriptive names:

```
pre-update-v0.1.0-to-v0.2.0
pre-update-v0.2.0-to-v0.3.0
```

This makes it easy to identify which update a snapshot was created before.

**Implementation:**
```bash
create_pre_update_snapshot() {
    local current_version=$(cat /var/lib/wintarch/version)
    local new_version=$(cat /opt/wintarch/version)
    local description="pre-update-${current_version}-to-${new_version}"

    snapper -c root create --description "$description"
}
```

## Command Installation

Commands are installed via symlinks to `/usr/local/bin/`:

```bash
install_commands() {
    for cmd in /opt/wintarch/bin/wintarch-*; do
        [[ -x "$cmd" ]] || continue
        local name=$(basename "$cmd")
        ln -sf "$cmd" "/usr/local/bin/$name"
    done
}
```

**Rationale for symlinks over PATH:**
- `/usr/local/bin` is already in PATH for all users/shells
- Works in non-login shells, scripts, cron jobs
- No need to modify shell init files
- Standard Linux practice for system-wide tools

## Logging

### Install Log
- **Path**: `/var/log/wintarch-install.log`
- **Created by**: Phase 1 installer
- **Contains**: Full installation output

### Update Log
- **Path**: `/var/log/wintarch-update.log`
- **Appended by**: Each `wintarch-update` run
- **Format**: Timestamped entries

```bash
# In wintarch-update:
exec > >(tee -a /var/log/wintarch-update.log) 2>&1
echo "=== Update started: $(date) ==="
```

## Update Confirmation

Updates require confirmation by default:

```bash
if [[ "${1:-}" != "-y" ]]; then
    gum confirm "Run system update?" || exit 0
fi
```

User documentation should explain this is the recommended way to update the system.

## Failed Migration Handling

When a migration fails:

1. Show error output
2. Prompt: "Migration failed. Skip and continue?"
3. If skip: Mark as completed (prevents retry loops), continue to next
4. If no: Abort update, user can fix and retry

This is the omarchy approach - flexible and non-blocking.

## Integration with Phase 1

### During Fresh Install

Phase 1 `post-install.sh` should:

1. Clone/copy wintarch repo to `/opt/wintarch/`
2. Create `/var/lib/wintarch/` directory
3. Call `initialize_migration_state()` to mark all migrations done
4. Call `install_commands()` to create symlinks
5. Write version to `/var/lib/wintarch/version`

### Post-Install Flow

```
Phase 1 Install
      ↓
post-install.sh
      ↓
┌─────────────────────────────┐
│ Setup wintarch:             │
│ 1. Copy to /opt/wintarch/   │
│ 2. Create state dirs        │
│ 3. Mark migrations done     │
│ 4. Install command symlinks │
│ 5. Write version            │
└─────────────────────────────┘
      ↓
System ready with wintarch
```

## Future Considerations

### User-Level Updates (Not in Scope)

A future `wintarch-user-update` could handle per-user configurations:
- Dotfiles sync
- User-specific packages
- Theme preferences

This is separate from system-level wintarch and not planned for initial implementation.

### Package Groups

Could add package group management:
```bash
wintarch-packages desktop   # Install desktop package group
wintarch-packages dev       # Install dev tools
```

This would be optional post-install customization.

## Reference

### Omarchy Files for Reference

| Omarchy File | Relevant For |
|--------------|--------------|
| `bin/omarchy-update*` | Update command structure |
| `bin/omarchy-migrate` | Migration runner |
| `migrations/*.sh` | Migration examples |
| `install.sh` | PATH setup, initialization |
| `bin/omarchy-snapshot` | Snapshot integration |

### Key Differences from Omarchy

| Aspect | Omarchy | Wintarch |
|--------|---------|----------|
| Location | `~/.local/share/omarchy` (per-user) | `/opt/wintarch/` (system-wide) |
| Commands | PATH modification | Symlinks to `/usr/local/bin/` |
| Desktop | Hyprland | COSMIC |
| State | `~/.local/state/omarchy/` | `/var/lib/wintarch/` |
