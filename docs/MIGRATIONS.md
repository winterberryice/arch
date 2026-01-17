# Wintarch Migrations - Implementation Guide

Quick reference for implementing migrations when you need to make system or user-level changes.

## When to Use Migrations

Create a migration when you need to:
- Enable/configure new systemd services
- Modify system configuration files on existing installations
- Update user dotfiles or shell configurations
- Install additional packages or dependencies
- Fix issues that require changes on already-installed systems

**Don't use migrations for**:
- Changes that only affect new installations (add to `install/post-install.sh` instead)
- Package updates (handled by `pacman`/`yay` automatically)

## Quick Start

### System Migration

```bash
# 1. Create migration file
timestamp=$(date +%s)
sudo touch "/opt/wintarch/migrations/$timestamp.sh"
sudo chmod +x "/opt/wintarch/migrations/$timestamp.sh"

# 2. Edit the file
sudo vim "/opt/wintarch/migrations/$timestamp.sh"
```

Template:
```bash
#!/bin/bash
# Migration: Brief description of what this does
# Date: YYYY-MM-DD
# Why: Reason for this change

set -e  # Exit on error

# Your changes here

echo "Migration completed"
```

### User Migration

Same process, but in `/opt/wintarch/user/migrations/` and runs as user (no sudo in the script).

## File Naming

**Use Unix timestamp**: `date +%s` gives you a sortable, unique filename like `1704067200.sh`

Why timestamps?
- Automatically sorted chronologically
- Always unique
- No version numbering conflicts

## Writing Good Migrations

### 1. Make It Idempotent

**Bad**:
```bash
echo "source /opt/wintarch/user/dotfiles/zshrc" >> ~/.zshrc
systemctl enable myservice.service
```

**Good**:
```bash
# Check before adding
if ! grep -q "source /opt/wintarch/user/dotfiles/zshrc" ~/.zshrc; then
    echo "source /opt/wintarch/user/dotfiles/zshrc" >> ~/.zshrc
fi

# Check if service exists and isn't already enabled
if systemctl list-unit-files | grep -q "myservice.service"; then
    if ! systemctl is-enabled myservice.service &>/dev/null; then
        systemctl enable myservice.service
    fi
fi
```

### 2. Handle Missing Dependencies

```bash
# Don't assume a file/command exists
if [[ ! -f /path/to/config ]]; then
    echo "Config not found, skipping"
    exit 0
fi

if ! command -v some-tool &>/dev/null; then
    echo "Tool not installed, skipping"
    exit 0
fi
```

### 3. Use set -e

Always add `set -e` at the top so the script fails fast on any error.

### 4. Test Before Deploying

```bash
# Test system migration manually
sudo bash /opt/wintarch/migrations/1704067200.sh

# Check status
wintarch-migrations --status
```

## Common Patterns

### Check if already done
```bash
if [[ -f ~/.config/myapp/migrated ]]; then
    echo "Already migrated"
    exit 0
fi
```

### Backup before modifying
```bash
CONFIG="$HOME/.config/app/config.json"
if [[ -f "$CONFIG" ]]; then
    cp "$CONFIG" "$CONFIG.backup-$(date +%s)"
fi
```

### Add to config file safely
```bash
CONFIG="$HOME/.zshrc"
LINE="export MY_VAR=value"

if ! grep -qF "$LINE" "$CONFIG"; then
    echo "$LINE" >> "$CONFIG"
fi
```

### Enable systemd service
```bash
SERVICE="myapp.service"

if systemctl list-unit-files | grep -q "$SERVICE"; then
    if ! systemctl is-enabled "$SERVICE" &>/dev/null; then
        systemctl enable "$SERVICE"
    fi
fi
```

## How Migrations Run

### System Migrations
- **Command**: `wintarch-migrations --run` (or via `wintarch-update`)
- **Location**: `/opt/wintarch/migrations/*.sh`
- **State**: `/var/lib/wintarch/migrations/` (completed) and `skipped/` (skipped)
- **Runs as**: root

### User Migrations
- **Command**: `wintarch-user-update` (calls `user/scripts/migrations.sh`)
- **Location**: `/opt/wintarch/user/migrations/*.sh`
- **State**: `~/.local/state/wintarch/migrations/` (completed) and `skipped/` (skipped)
- **Runs as**: regular user

### On Fresh Install
All existing migrations are automatically marked as completed during `install/post-install.sh`. Only migrations created *after* installation will run.

## Troubleshooting

### Migration Failed
```bash
# Run manually to see error details
sudo bash /opt/wintarch/migrations/1704067200.sh

# Fix the script and run migrations again
wintarch-migrations --run
```

### Retry a Skipped Migration
```bash
# Remove skip marker
sudo rm /var/lib/wintarch/migrations/skipped/1704067200.sh

# Run again
wintarch-migrations --run
```

### Check Migration Status
```bash
# System migrations
wintarch-migrations --status

# Shows:
# - Pending (will run next)
# - Completed (already done)
# - Skipped (failed and user chose to skip)
```

## Real Examples

### Example 1: Enable New Service

```bash
#!/bin/bash
# Migration: Enable wintarch-update-check timer
# Date: 2024-01-15
# Why: New auto-update feature needs background timer

set -e

TIMER="wintarch-update-check.timer"

if ! systemctl list-unit-files | grep -q "$TIMER"; then
    echo "Timer not found, skipping"
    exit 0
fi

if ! systemctl is-enabled "$TIMER" &>/dev/null; then
    systemctl enable "$TIMER"
    echo "Enabled $TIMER"
else
    echo "$TIMER already enabled"
fi

echo "Migration completed"
```

### Example 2: Update User Config (User Migration)

```bash
#!/bin/bash
# User Migration: Add zsh-syntax-highlighting plugin
# Date: 2024-01-20
# Why: Better shell experience for all users

set -e

PLUGIN_DIR="$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"

if [[ -d "$PLUGIN_DIR" ]]; then
    echo "Plugin already installed"
    exit 0
fi

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    echo "Oh My Zsh not installed, skipping"
    exit 0
fi

git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$PLUGIN_DIR"

echo "User migration completed"
```

### Example 3: Fix Config File

```bash
#!/bin/bash
# Migration: Fix mkinitcpio hooks order
# Date: 2024-02-01
# Why: btrfs-overlayfs must come after filesystems

set -e

CONFIG="/etc/mkinitcpio.conf"
BACKUP="$CONFIG.backup-$(date +%s)"

if [[ ! -f "$CONFIG" ]]; then
    echo "Config not found"
    exit 0
fi

# Check if fix is already applied
if grep -q "HOOKS=.*filesystems.*btrfs-overlayfs" "$CONFIG"; then
    echo "Already fixed"
    exit 0
fi

# Backup
cp "$CONFIG" "$BACKUP"

# Fix the order (example - adjust regex as needed)
sed -i 's/HOOKS=\(.*btrfs-overlayfs.*filesystems.*\)/HOOKS=\1/' "$CONFIG"

# Rebuild initramfs
mkinitcpio -P

echo "Migration completed"
```

## Development Workflow

When building a feature that needs migration:

1. **Develop feature** in your branch
2. **Create migration** with `date +%s`
3. **Test migration** manually in VM
4. **Commit together** - feature code + migration in same commit
5. **Document in commit message** that migration is included

Example commit message:
```
feat: Add automatic update checking

- Add wintarch-update-check service and timer
- Includes migration (1704067200.sh) to enable timer on existing systems
- Timer runs daily at 2am to check for updates
```

## Summary

- **Timestamp filenames**: `date +%s`
- **Idempotent**: Check before changing
- **set -e**: Fail fast
- **Test manually**: Before committing
- **Fresh installs skip**: Migrations auto-marked complete on new installs
