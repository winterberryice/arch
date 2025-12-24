# arch

Arch Linux distribution for disposable, multi-user systems. Minimal .pacnew conflicts, version-tracked configs.

## Core Idea

**Problem**: Omarchy is single-user only, traditional /etc/ configs create .pacnew hell
**Solution**: System-wide XDG defaults + per-user configs + version migrations

## Architecture

```
/opt/arch/                   # Git repo (root-owned, world-readable)
├── bin/
│   ├── arch-update-system   # Updates system (needs sudo)
│   └── arch-update-user     # Updates user configs (no sudo)
├── system/
│   ├── configs/etc/xdg/     # System defaults (→ /etc/xdg/)
│   └── packages.list        # Packages to install
├── user/
│   ├── dotfiles/            # Initial configs (→ ~/.config/)
│   └── migrations/NNN-name.sh  # Version update scripts
└── version                  # Current version number

~/.local/share/arch-state/version  # User's version
~/.config/                         # User configs (overrides system)
```

## Config Priority

```
~/.config/      >  /etc/xdg/      >  /usr/share/
(user)             (arch)            (packages)
```

Users can override anything. System provides defaults. Packages rarely touch /etc/xdg/ → no .pacnew conflicts.

## Update Flow

### System Update (admin)

```bash
sudo arch-update-system
```

1. Lock file check (prevent concurrent updates)
2. `pacman -Syu` (update packages)
3. `cd /opt/arch && git pull` (update repo)
4. Install packages from packages.list
5. Sync `system/configs/etc/xdg/` → `/etc/xdg/`
6. Prompt admin to update their user configs

### User Update (any user)

```bash
arch-update-user
```

1. Read versions: current (`~/.local/share/arch-state/version`) vs latest (`/opt/arch/version`)
2. If current=0: **First run** → copy all `user/dotfiles/` to `~/.config/`, set version to latest
3. If current<latest: **Update** → run `migrations/{current+1..latest}-*.sh`, update version
4. If current=latest: Already up-to-date

## Key Decisions

| Decision | Why |
|----------|-----|
| Single repo | Atomic updates, one version number |
| Two scripts | Clear privilege separation, multi-user safe |
| /opt/arch/ | FHS-compliant, self-contained |
| /etc/xdg/ | Avoid .pacnew (packages don't use it) |
| Public repo | No credentials needed for updates |
| Integer versions | Simple comparison, easy migrations |
| Copy dotfiles | Users own configs, can customize freely |

## Multi-User Example

```
System at v5, three users:
- alice: v5 (up-to-date)
- bob: v3 (needs migration 4,5)
- charlie: v0 (never updated, first run)

Admin: sudo arch-update-system  # Updates system to v6
alice: arch-update-user         # Runs migration 6
bob: arch-update-user           # Runs migrations 4,5,6
charlie: arch-update-user       # Copies all dotfiles, skips to v6
```

Each user updates independently, no conflicts.

## Migration Example

```bash
# user/migrations/003-add-fish-aliases.sh
#!/bin/bash
set -e

FISH_CONFIG="$HOME/.config/fish/config.fish"

# Idempotent: check if already applied
if grep -q "# arch v3 aliases" "$FISH_CONFIG" 2>/dev/null; then
    echo "Already applied, skipping"
    exit 0
fi

# Add new content
cat >> "$FISH_CONFIG" << 'EOF'

# arch v3 aliases
alias ll='ls -lah'
alias gs='git status'
EOF

echo "✓ Added aliases"
```

**Migrations must be**:
- Idempotent (safe to run twice)
- Non-destructive (don't delete user data)
- Additive (add features, preserve customizations)

## Quick Start

```bash
# Install
sudo git clone https://github.com/winterberryice/arch.git /opt/arch
sudo /opt/arch/bin/arch-update-system

# Each user runs
arch-update-user
```

## Status

**Current**: Documentation and stubs only
**TODO**: Implement update scripts, test in QEMU/Docker

## Next Tasks

1. Implement `bin/arch-update-system`
2. Implement `bin/arch-update-user`
3. Add more example dotfiles and migrations
4. Test in Docker, then QEMU
5. Handle edge cases (network failures, migration errors, etc.)
