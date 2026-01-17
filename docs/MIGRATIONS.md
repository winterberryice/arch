# Wintarch Migrations

Wintarch uses a migration system to handle system and user-level changes that need to be applied after installation or updates. This document explains how migrations work and how to create them.

## Overview

There are two types of migrations in Wintarch:

1. **System Migrations** - Applied system-wide, require root privileges
2. **User Migrations** - Applied per-user, run in user context

## System Migrations

### Location
- Scripts: `/opt/wintarch/migrations/`
- State: `/var/lib/wintarch/migrations/`
- Skipped: `/var/lib/wintarch/migrations/skipped/`

### Management
System migrations are managed via the `wintarch-migrations` command:

```bash
wintarch-migrations              # Show pending migrations
wintarch-migrations --status     # Show all migrations (pending, completed, skipped)
wintarch-migrations --run        # Run pending migrations
```

### When They Run
- **During installation**: All existing migrations are marked as completed (`install/post-install.sh`)
- **During updates**: `wintarch-update` automatically runs pending migrations after package updates

### Creating System Migrations

1. **Filename Format**: Unix timestamp with `.sh` extension
   ```bash
   # Get current timestamp
   date +%s
   # Example: 1704067200.sh
   ```

2. **File Location**: Place in `/opt/wintarch/migrations/`

3. **Template**:
   ```bash
   #!/bin/bash
   # Migration: <Short description>
   # Date: YYYY-MM-DD
   # Why: <Reason for this migration>

   set -e  # Exit on error

   # Your migration code here

   echo "Migration completed successfully"
   ```

4. **Best Practices**:
   - Always use `set -e` to fail fast on errors
   - Make migrations idempotent (safe to run multiple times)
   - Check if changes are already applied before making them
   - Add clear comments explaining what and why
   - Test migrations in a VM before deploying

### Example System Migration

```bash
#!/bin/bash
# Migration: Enable new systemd service for background updates
# Date: 2024-01-01
# Why: New feature requires background update checking

set -e

SERVICE="wintarch-update-check.service"
TIMER="wintarch-update-check.timer"

# Check if service exists
if ! systemctl list-unit-files | grep -q "$SERVICE"; then
    echo "Service $SERVICE not found, skipping"
    exit 0
fi

# Enable timer if not already enabled
if ! systemctl is-enabled "$TIMER" &>/dev/null; then
    systemctl enable "$TIMER"
    echo "Enabled $TIMER"
else
    echo "$TIMER already enabled"
fi

echo "Migration completed successfully"
```

## User Migrations

### Location
- Scripts: `/opt/wintarch/user/migrations/`
- State: `~/.local/state/wintarch/migrations/`
- Skipped: `~/.local/state/wintarch/migrations/skipped/`

### Management
User migrations are managed via `user/scripts/migrations.sh`:

```bash
# These are called by wintarch-user-update, not directly
migrations.sh status      # Show all migrations
migrations.sh run         # Run pending migrations
migrations.sh mark-done   # Mark all as completed (fresh setup)
```

### When They Run
- **First run of wintarch-user-update**: All existing migrations are marked as completed
- **Subsequent runs**: `wintarch-user-update` runs pending migrations after Oh My Zsh updates

### Creating User Migrations

1. **Filename Format**: Same as system migrations - Unix timestamp with `.sh` extension

2. **File Location**: Place in `/opt/wintarch/user/migrations/`

3. **Template**:
   ```bash
   #!/bin/bash
   # User Migration: <Short description>
   # Date: YYYY-MM-DD
   # Why: <Reason for this migration>

   set -e  # Exit on error

   # Your migration code here (runs as user, not root)

   echo "User migration completed successfully"
   ```

4. **Best Practices**:
   - No sudo commands (runs in user context)
   - Make migrations idempotent
   - Check if user files/configs already exist
   - Use `$HOME` instead of hardcoded paths
   - Safe for multiple users on same system

### Example User Migration

```bash
#!/bin/bash
# User Migration: Add new zsh plugin to user configuration
# Date: 2024-01-15
# Why: New syntax highlighting plugin improves shell experience

set -e

PLUGIN_DIR="$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"

# Check if plugin already installed
if [[ -d "$PLUGIN_DIR" ]]; then
    echo "Plugin already installed"
    exit 0
fi

# Clone plugin
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$PLUGIN_DIR"

echo "User migration completed successfully"
```

## Migration Workflow

### System Migration Flow
```
wintarch-update
    ↓
Package updates
    ↓
wintarch-migrations --run
    ↓
For each migration in /opt/wintarch/migrations/*.sh:
    ├─ Already completed? → Skip
    ├─ Already skipped? → Skip
    └─ Run migration
        ├─ Success → Mark completed
        └─ Failure → Prompt to skip or abort
```

### User Migration Flow
```
wintarch-user-update
    ↓
First run? → Mark all existing migrations complete
    ↓
Oh My Zsh updates
    ↓
user/scripts/migrations.sh run
    ↓
For each migration in /opt/wintarch/user/migrations/*.sh:
    ├─ Already completed? → Skip
    ├─ Already skipped? → Skip
    └─ Run migration
        ├─ Success → Mark completed
        └─ Failure → Prompt to skip or abort
```

## State Management

### Completed Migrations
When a migration runs successfully, a marker file is created:
- System: `/var/lib/wintarch/migrations/<timestamp>.sh`
- User: `~/.local/state/wintarch/migrations/<timestamp>.sh`

### Skipped Migrations
If a migration fails and the user chooses to skip it:
- System: `/var/lib/wintarch/migrations/skipped/<timestamp>.sh`
- User: `~/.local/state/wintarch/migrations/skipped/<timestamp>.sh`

### Fresh Installations
During installation (`install/post-install.sh`), all existing migrations are marked as completed. This prevents new installations from running historical migrations that are only relevant for upgrades from older versions.

## Common Patterns

### Checking if a Command Exists
```bash
if command -v some-command &>/dev/null; then
    # Command exists
fi
```

### Checking if a File Exists
```bash
if [[ -f /path/to/file ]]; then
    # File exists
fi
```

### Making Changes Idempotent
```bash
# Bad: Always appends
echo "source /some/file" >> ~/.zshrc

# Good: Check first
if ! grep -q "source /some/file" ~/.zshrc; then
    echo "source /some/file" >> ~/.zshrc
fi
```

### Backing Up Files
```bash
CONFIG_FILE="$HOME/.config/some-app/config"

if [[ -f "$CONFIG_FILE" ]]; then
    cp "$CONFIG_FILE" "$CONFIG_FILE.backup-$(date +%s)"
fi
```

### Conditional Changes Based on System State
```bash
# Only run if service exists
if systemctl list-unit-files | grep -q "myservice.service"; then
    systemctl enable myservice.service
fi
```

## Testing Migrations

### System Migrations
```bash
# Test in a VM or container
sudo bash /opt/wintarch/migrations/1704067200.sh

# Check state
wintarch-migrations --status
```

### User Migrations
```bash
# Test as regular user
bash /opt/wintarch/user/migrations/1704067200.sh

# Check state (via wintarch-user-update)
wintarch-user-update --dry-run  # If such flag exists
```

## Troubleshooting

### Migration Failed
1. Check the migration script for errors
2. Run manually to see detailed output:
   ```bash
   sudo bash /opt/wintarch/migrations/<timestamp>.sh
   ```
3. Fix the issue and run again
4. Or skip the migration if it's no longer relevant

### Migration Stuck in Skipped State
Remove the skip marker to retry:
```bash
# System migration
sudo rm /var/lib/wintarch/migrations/skipped/<timestamp>.sh

# User migration
rm ~/.local/state/wintarch/migrations/skipped/<timestamp>.sh
```

Then run migrations again:
```bash
# System
wintarch-migrations --run

# User
wintarch-user-update
```

## Development Workflow

When developing new features that require migration:

1. **Create the migration script** with proper timestamp
2. **Test in VM** to ensure it works
3. **Commit together** with the feature that requires it
4. **Document** in commit message that migration is required

### Helper for Creating Migrations

While there's no official tool yet, you can use this snippet:

```bash
# Create system migration
timestamp=$(date +%s)
cat > "/opt/wintarch/migrations/$timestamp.sh" <<'EOF'
#!/bin/bash
# Migration: <description>
# Date: $(date +%Y-%m-%d)
# Why: <reason>

set -e

# Your migration code here

echo "Migration completed successfully"
EOF
chmod +x "/opt/wintarch/migrations/$timestamp.sh"
```

## Best Practices Summary

1. ✅ **Use timestamps** for filenames (sortable, unique)
2. ✅ **Make idempotent** - safe to run multiple times
3. ✅ **Add comments** - explain what and why
4. ✅ **Use `set -e`** - fail fast on errors
5. ✅ **Test in VM** before deploying
6. ✅ **Check before changing** - don't assume state
7. ✅ **Backup before modifying** critical files
8. ❌ **Don't hardcode paths** - use variables
9. ❌ **Don't skip error handling** - handle failures gracefully
10. ❌ **Don't make irreversible changes** without confirmation

## Future Improvements

Potential enhancements to the migration system:

- **Rollback support** - Ability to undo migrations
- **Migration generator** - Tool to create migration templates
- **Dry-run mode** - Preview what migrations will do
- **Migration versioning** - Track which version introduced each migration
- **Better error reporting** - Detailed logs of migration failures
