# my-distro Architecture

## Overview

**my-distro** is an Arch Linux-based distribution designed for quick, disposable, and easily reinstallable systems with full multi-user support. The architecture prioritizes simplicity, reproducibility, and minimal maintenance overhead while avoiding the complexity of .pacnew file management.

## Core Philosophy

1. **Disposable Systems**: Easy to reinstall from scratch with minimal effort
2. **Multi-User First**: System-wide defaults that work for all users, not just a single user
3. **Minimal .pacnew Conflicts**: Avoid touching package-managed /etc/ paths
4. **Version Tracking**: Explicit version management with migration scripts
5. **Two-Tier Updates**: Separate system and user update paths with appropriate permissions

## Directory Structure

```
/opt/my-distro/                           # Single git repository (root-owned, world-readable)
├── bin/
│   ├── my-distro-update-system          # System updater (requires sudo)
│   └── my-distro-update-user            # User updater (no sudo required)
├── system/
│   ├── configs/
│   │   └── etc/
│   │       └── xdg/                     # System-wide XDG defaults
│   │           ├── nvim/
│   │           ├── fish/
│   │           └── ...
│   ├── packages.list                    # Packages to install
│   └── scripts/                         # System setup scripts
├── user/
│   ├── dotfiles/                        # Initial user configs
│   │   ├── nvim/
│   │   ├── fish/
│   │   └── ...
│   └── migrations/                      # User-level migration scripts
│       ├── 001-initial.sh
│       ├── 002-add-fish-config.sh
│       └── ...
└── version                              # Current distribution version

~/.local/share/my-distro-state/          # Per-user state directory
└── version                              # User's current version (0 = first run)

~/.config/                               # User configurations (highest XDG priority)
├── nvim/
├── fish/
└── ...

/etc/xdg/                                # System-wide XDG defaults (lower priority)
├── nvim/
├── fish/
└── ...
```

## XDG Base Directory Hierarchy

The system leverages the XDG Base Directory Specification for configuration management:

```
Priority (highest to lowest):
1. ~/.config/          # User-specific configs (user can override anything)
2. /etc/xdg/           # System-wide defaults (my-distro controlled)
3. /usr/share/         # Package defaults (managed by pacman)
```

### Why This Matters

- **User Freedom**: Users can override any system default in their ~/.config/
- **System Consistency**: New users get sensible defaults from /etc/xdg/
- **.pacnew Avoidance**: /etc/xdg/ is typically NOT managed by Arch packages, avoiding conflicts
- **Clear Separation**: System configs vs user configs vs package defaults are clearly delineated

## The Two-Utility Architecture

### Why Two Scripts?

This is the key architectural decision that enables multi-user support:

```
┌─────────────────────────────────────────────────────────────┐
│                  my-distro-update-system                    │
│                    (requires sudo)                          │
├─────────────────────────────────────────────────────────────┤
│  1. pacman -Syu (update system packages)                    │
│  2. cd /opt/my-distro && git pull (update repo)            │
│  3. Install packages from packages.list                     │
│  4. Copy system/configs/etc/xdg/* → /etc/xdg/              │
│  5. Run system-level hooks (optional)                       │
│  6. Optionally prompt to update current user                │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
                   /opt/my-distro/ updated
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   my-distro-update-user                     │
│                     (no sudo needed)                        │
├─────────────────────────────────────────────────────────────┤
│  1. Read ~/.local/share/my-distro-state/version             │
│  2. Read /opt/my-distro/version                             │
│  3. If user_version == 0: First run initialization          │
│     → Copy user/dotfiles/* to ~/.config/                    │
│  4. If user_version < latest: Run migrations                │
│     → Execute migrations/XXX-*.sh sequentially              │
│  5. Update ~/.local/share/my-distro-state/version           │
└─────────────────────────────────────────────────────────────┘
```

### Key Benefits

1. **Privilege Separation**: System updates require sudo, user updates don't
2. **Multi-User Safe**: Each user runs their own update independently
3. **No Conflicts**: Users can update at their own pace
4. **Atomic Per-User**: User updates are atomic per-user, won't affect others
5. **System Consistency**: System-wide defaults updated once, available to all

## Version Tracking System

### Version File Format

```bash
# /opt/my-distro/version
5

# ~/.local/share/my-distro-state/version
4  # This user is one version behind
```

### First-Run Detection

When a user runs `my-distro-update-user` for the first time:

```bash
if [[ ! -f ~/.local/share/my-distro-state/version ]]; then
    # First run: create version file with 0
    mkdir -p ~/.local/share/my-distro-state
    echo "0" > ~/.local/share/my-distro-state/version
fi

current_version=$(cat ~/.local/share/my-distro-state/version)

if [[ $current_version -eq 0 ]]; then
    # First run: copy all initial dotfiles
    cp -r /opt/my-distro/user/dotfiles/* ~/.config/
    echo "1" > ~/.local/share/my-distro-state/version
fi
```

### Migration System

Migrations are executed sequentially for versions between user's current and latest:

```bash
current_version=3
latest_version=5

# Run migrations 004-*.sh and 005-*.sh
for migration in /opt/my-distro/user/migrations/{004..005}-*.sh; do
    if [[ -f $migration ]]; then
        bash "$migration"
    fi
done

# Update user version
echo "$latest_version" > ~/.local/share/my-distro-state/version
```

### Migration Script Example

```bash
# /opt/my-distro/user/migrations/003-add-fish-aliases.sh
#!/bin/bash
# Migration: Add new fish shell aliases

FISH_CONFIG="$HOME/.config/fish/config.fish"

# Ensure fish config exists
mkdir -p "$HOME/.config/fish"

# Add new aliases if not already present
if ! grep -q "alias ll" "$FISH_CONFIG" 2>/dev/null; then
    cat >> "$FISH_CONFIG" << 'EOF'

# my-distro aliases (v3)
alias ll='ls -lah'
alias gs='git status'
EOF
fi
```

## Git Repository Strategy

### Public Repository Model

```
Repository: https://github.com/username/my-distro (public)
Install Location: /opt/my-distro/
Ownership: root:root
Permissions: 755 (world-readable)
```

### Why Public?

1. **No Credentials Needed**: Any sudo user can `git pull` without authentication
2. **Simple Updates**: Just `cd /opt/my-distro && git pull`
3. **Transparency**: Users can inspect what they're installing
4. **Community Sharing**: Others can fork and adapt

### Alternative: Private Repository

If you need private configs:

```bash
# Install GitHub token or SSH key for root user
sudo git clone git@github.com:username/my-distro-private.git /opt/my-distro

# Updates still work as root
sudo my-distro-update-system  # Uses root's credentials
```

## Update Flow Details

### System Update Flow

```
Admin runs: sudo my-distro-update-system

1. Lock File Check
   └─ if /var/lock/my-distro-update.lock exists → abort

2. Create Lock File
   └─ touch /var/lock/my-distro-update.lock

3. Update System Packages
   └─ pacman -Syu --noconfirm

4. Update Git Repository
   ├─ cd /opt/my-distro
   └─ git pull origin main

5. Install New Packages
   ├─ Read system/packages.list
   └─ pacman -S --needed $(cat system/packages.list)

6. Update System Configs
   └─ rsync -av system/configs/etc/xdg/ /etc/xdg/

7. Remove Lock File
   └─ rm /var/lock/my-distro-update.lock

8. Prompt Current User (optional)
   └─ "Update your user configs now? (y/n)"
       └─ if yes: exec su $SUDO_USER -c my-distro-update-user
```

### User Update Flow

```
User runs: my-distro-update-user

1. Read Current Version
   └─ current=$(cat ~/.local/share/my-distro-state/version || echo 0)

2. Read Latest Version
   └─ latest=$(cat /opt/my-distro/version)

3. Version Check
   ├─ if current == 0 → First Run
   │   ├─ mkdir -p ~/.config
   │   ├─ cp -r /opt/my-distro/user/dotfiles/* ~/.config/
   │   └─ echo "1" > ~/.local/share/my-distro-state/version
   │
   ├─ if current < latest → Run Migrations
   │   ├─ for v in {current+1..latest}
   │   │   └─ bash /opt/my-distro/user/migrations/${v}-*.sh
   │   └─ echo "$latest" > ~/.local/share/my-distro-state/version
   │
   └─ if current == latest → Already Up-to-Date
       └─ echo "Already at version $current"

4. Done
```

## Multi-User Scenarios

### Scenario 1: Multiple Admins

```
User alice: sudo my-distro-update-system
  → Updates /opt/my-distro/ to v5
  → Updates /etc/xdg/ with new configs
  → Optionally updates alice's ~/.config/

Later, user bob: sudo my-distro-update-system
  → Checks git, already at v5
  → No changes needed
  → Optionally updates bob's ~/.config/
```

### Scenario 2: Users Update Independently

```
System at v5, three users:

alice: v5 (up-to-date)
bob: v3 (two versions behind)
charlie: v0 (never run user update)

bob runs: my-distro-update-user
  → Runs migrations 004-*.sh and 005-*.sh
  → Updates to v5
  → alice and charlie unaffected

charlie runs: my-distro-update-user
  → Detects first run (v0)
  → Copies all dotfiles
  → Sets version to latest (v5)
  → No migrations needed on first run
```

### Scenario 3: New User on Existing System

```
System: my-distro v7 installed

New user diane logs in for first time:
  → ~/.local/share/my-distro-state/ doesn't exist
  → ~/.config/ may be empty or have some configs

diane runs: my-distro-update-user
  → Creates ~/.local/share/my-distro-state/version = 0
  → Detects first run
  → Copies /opt/my-distro/user/dotfiles/* to ~/.config/
  → Sets version to 7
  → Done! diane has all current configs
```

## Avoiding .pacnew Complexity

### The .pacnew Problem

Arch Linux tracks /etc/ file modifications via MD5 hashes in package databases. When a package updates a config file:

```
1. Package wants to update /etc/foo.conf
2. Pacman checks MD5 of current /etc/foo.conf
3. If modified by user → creates /etc/foo.conf.pacnew instead
4. User must manually merge .pacnew files
```

### How my-distro Avoids This

```
✗ AVOID: Putting configs in /etc/ that packages also manage
  /etc/pacman.conf        # Managed by pacman package → .pacnew hell
  /etc/nginx/nginx.conf   # Managed by nginx package → .pacnew hell
  /etc/ssh/sshd_config    # Managed by openssh package → .pacnew hell

✓ USE: XDG paths that packages typically don't touch
  /etc/xdg/nvim/          # my-distro managed, nvim doesn't touch this
  /etc/xdg/fish/          # my-distro managed, fish doesn't touch this
  /etc/xdg/kitty/         # my-distro managed, kitty doesn't touch this

✓ USE: User-level configs (highest priority anyway)
  ~/.config/nvim/         # User's personal config, overrides all
  ~/.config/fish/         # User's personal config, overrides all
```

### XDG Compliance

Most modern applications follow XDG Base Directory spec:

```
Application: neovim
Search path: ~/.config/nvim/ → /etc/xdg/nvim/ → /usr/share/nvim/

Application: fish
Search path: ~/.config/fish/ → /etc/xdg/fish/ → /usr/share/fish/

Application: kitty
Search path: ~/.config/kitty/ → /etc/xdg/kitty/ → /usr/share/kitty/
```

By placing configs in `/etc/xdg/`, my-distro provides system-wide defaults without conflicting with package-managed paths.

### Handling Non-XDG Applications

Some applications don't support XDG paths. For these:

```bash
# Option 1: User dotfiles only (no system-wide defaults)
# Place in user/dotfiles/.bashrc, copied to ~/.bashrc on first run

# Option 2: Wrapper scripts
# Create /opt/my-distro/bin/my-app that sets env vars and calls real app

# Option 3: Symlinks in user migration scripts
# migrations/005-link-bashrc.sh creates ~/.bashrc → ~/.config/bash/bashrc
```

## Concurrency and Safety

### System Update Locking

```bash
LOCK_FILE="/var/lock/my-distro-update.lock"

if [[ -f $LOCK_FILE ]]; then
    echo "Another system update is in progress"
    exit 1
fi

trap 'rm -f $LOCK_FILE' EXIT
touch $LOCK_FILE

# Perform update...
```

### User Update Isolation

No locking needed for user updates because:
1. Each user has separate `~/.local/share/my-distro-state/version`
2. Each user modifies only their own `~/.config/`
3. Reading from `/opt/my-distro/` is safe (read-only for users)
4. Multiple users can update simultaneously without conflicts

## Filesystem Permissions

```
/opt/my-distro/                   root:root   755
/opt/my-distro/bin/*              root:root   755
/opt/my-distro/version            root:root   644
/opt/my-distro/user/dotfiles/     root:root   755 (recursive)
/opt/my-distro/user/migrations/*  root:root   755

/etc/xdg/                         root:root   755 (system managed)
/etc/xdg/*/                       root:root   644/755

~/.local/share/my-distro-state/   user:user   700
~/.local/share/.../version        user:user   600
~/.config/                        user:user   700
```

## Comparison with Other Approaches

### vs Omarchy (single-user focus)

```
Omarchy:
  ✓ Simple user-level installation
  ✓ No root required
  ✗ Single user only (~/.local/share/omarchy/)
  ✗ No system-wide defaults
  ✗ Each user maintains separate copy

my-distro:
  ✓ Multi-user from ground up
  ✓ System-wide defaults (/etc/xdg/)
  ✓ Single source of truth (/opt/my-distro/)
  ✓ Per-user customization (~/. config/)
  ⚠ Requires initial sudo for system setup
```

### vs Traditional /etc/ Heavy Approach

```
Traditional:
  ✓ Familiar to sysadmins
  ✗ Heavy .pacnew maintenance
  ✗ No version tracking
  ✗ Hard to update atomically
  ✗ Manual per-user setup

my-distro:
  ✓ Minimal .pacnew conflicts
  ✓ Explicit version tracking
  ✓ Atomic user updates
  ✓ Automated user setup
  ⚠ Requires XDG-compliant applications
```

## Testing and Development

See [TESTING.md](TESTING.md) for detailed testing strategies including:
- QEMU full system testing
- Docker for rapid iteration
- Snapshot-based testing
- Multi-user test scenarios

## Future Enhancements

### Potential Additions

1. **Rollback Support**: Keep previous versions in user state
2. **Config Validation**: Pre-flight checks before applying migrations
3. **Dry-Run Mode**: Preview what update will do
4. **Change Tracking**: Log what each migration modified
5. **Templating System**: Per-user variables in configs (username, email, etc.)
6. **Hook System**: Pre/post update hooks for custom logic
7. **Remote Secrets**: Fetch secrets from password manager during updates

### Plugin Architecture

```
/opt/my-distro/plugins/
├── development/
│   ├── packages.list
│   ├── configs/
│   └── migrations/
└── gaming/
    ├── packages.list
    ├── configs/
    └── migrations/

# Enable plugins in user state
~/.local/share/my-distro-state/enabled-plugins
development
```

## Summary

**my-distro** achieves multi-user support through:

1. **Single git repository** at `/opt/my-distro/` (system-wide, read-only for users)
2. **Two update utilities** with appropriate privilege separation
3. **XDG-based configs** in `/etc/xdg/` to avoid .pacnew conflicts
4. **Per-user versioning** and migration system for controlled updates
5. **Clear separation** between system defaults and user customizations

This architecture enables:
- ✅ Quick system reinstalls (just git clone and run update-system)
- ✅ Multiple users with independent configurations
- ✅ System-wide sensible defaults
- ✅ Minimal .pacnew maintenance overhead
- ✅ Version-tracked, reproducible configurations
- ✅ No credentials needed for public repo model
