# User Directory

This directory contains user-level configurations and migrations.

## Structure

```
user/
├── dotfiles/          # Initial user configurations (copied on first run)
│   ├── fish/          # Fish shell config
│   ├── nvim/          # Neovim config
│   └── kitty/         # Kitty terminal config
│
└── migrations/        # Version-based migration scripts
    └── NNN-description.sh  # Migration for version NNN
```

## Dotfiles

Files in `dotfiles/` are copied to user's `~/.config/` on first run (when version=0).

**Important**: These files should contain complete, working configurations for new users.

### Adding a New Application Config

1. Create directory: `dotfiles/myapp/`
2. Add config files: `dotfiles/myapp/config.conf`
3. Test: Ensure it works when copied to `~/.config/myapp/`

## Migrations

Migration scripts update existing user configs from one version to the next.

### Naming Convention

```
NNN-description.sh

Where:
- NNN = zero-padded version number (001, 002, etc.)
- description = short kebab-case description
```

Examples:
- `002-add-tmux-config.sh` - Adds tmux configuration
- `003-update-fish-aliases.sh` - Updates fish aliases
- `010-fix-nvim-plugins.sh` - Fixes neovim plugin configuration

### Migration Guidelines

Migrations must be:

1. **Idempotent**: Safe to run multiple times
   ```bash
   # Check before modifying
   if ! grep -q "my marker" ~/.config/fish/config.fish; then
       echo "content" >> ~/.config/fish/config.fish
   fi
   ```

2. **Non-destructive**: Don't delete user data
   ```bash
   # BAD: rm ~/.config/fish/config.fish
   # GOOD: Append or modify specific sections
   ```

3. **Additive**: Add features, don't remove user customizations
   ```bash
   # Add new aliases, but keep user's existing ones
   cat >> ~/.config/fish/config.fish << 'EOF'
   alias new='some command'
   EOF
   ```

4. **Defensive**: Check conditions before acting
   ```bash
   if [[ -f ~/.config/nvim/init.lua ]]; then
       # Modify existing file
   else
       echo "nvim config not found, skipping"
   fi
   ```

### Migration Template

```bash
#!/bin/bash
# migrations/NNN-description.sh
# Brief description of what this migration does

set -e  # Exit on error

echo "Running migration NNN: description"

# Check if migration already applied (idempotent)
if [[ -f ~/.config/marker-for-migration-NNN ]]; then
    echo "  Migration already applied, skipping"
    exit 0
fi

# Perform migration
# ... your migration logic here ...

# Mark as completed (optional, for idempotency)
touch ~/.config/marker-for-migration-NNN

echo "  ✓ Migration NNN complete"
```

### Testing Migrations

Before committing a migration:

1. Test on fresh user (version 0):
   ```bash
   sudo -u testuser my-distro-update-user
   ```

2. Test incremental update:
   ```bash
   echo "N-1" > ~/.local/share/my-distro-state/version
   my-distro-update-user
   ```

3. Test idempotency (run twice):
   ```bash
   bash user/migrations/NNN-your-migration.sh
   bash user/migrations/NNN-your-migration.sh  # Should not error
   ```

## Version Tracking

User version is stored in:
```
~/.local/share/my-distro-state/version
```

When a user updates:
1. Current version is read from state file
2. Latest version is read from `/opt/my-distro/version`
3. Migrations from `current+1` to `latest` are executed
4. Version is updated to latest

### Special Versions

- **Version 0**: First run, never updated
  - Triggers: Copy all dotfiles to `~/.config/`
  - No migrations run
  - Version set to latest

- **Version < Latest**: Update needed
  - Triggers: Run migrations sequentially
  - Version updated after all migrations succeed

- **Version == Latest**: Up-to-date
  - Triggers: Nothing, already current
