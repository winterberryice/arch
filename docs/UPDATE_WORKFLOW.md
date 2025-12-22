# Update Workflow

This document provides detailed workflows for updating my-distro systems and user configurations.

## Table of Contents

1. [System Update Workflow](#system-update-workflow)
2. [User Update Workflow](#user-update-workflow)
3. [First-Run Initialization](#first-run-initialization)
4. [Migration Script Execution](#migration-script-execution)
5. [Multi-User Scenarios](#multi-user-scenarios)
6. [Troubleshooting](#troubleshooting)

---

## System Update Workflow

### Overview

System updates are performed by administrators with sudo access. They update the system packages, pull the latest my-distro repository, and apply system-wide configurations.

### Command

```bash
sudo my-distro-update-system
```

### Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                  my-distro-update-system                        │
│                    (requires sudo)                              │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
                  ┌─────────────────────┐
                  │ Check for lock file │
                  │ /var/lock/          │
                  │ my-distro-update    │
                  │ .lock               │
                  └─────────────────────┘
                            │
                  ┌─────────┴─────────┐
                  │ Lock exists?      │
                  └─────────┬─────────┘
                            │
              ┌─────────────┴─────────────┐
              │ YES                       │ NO
              ▼                           ▼
    ┌─────────────────────┐     ┌─────────────────────┐
    │ ERROR: Another      │     │ Create lock file    │
    │ update in progress  │     │ trap 'rm lock' EXIT │
    │ Exit 1              │     └─────────────────────┘
    └─────────────────────┘               │
                                          ▼
                            ┌─────────────────────────┐
                            │ Update system packages  │
                            │ pacman -Syu             │
                            └─────────────────────────┘
                                          │
                                          ▼
                            ┌─────────────────────────┐
                            │ cd /opt/my-distro       │
                            │ git pull origin main    │
                            └─────────────────────────┘
                                          │
                                          ▼
                            ┌─────────────────────────┐
                            │ Read packages.list      │
                            │ Install new packages    │
                            │ pacman -S --needed ...  │
                            └─────────────────────────┘
                                          │
                                          ▼
                            ┌─────────────────────────┐
                            │ Copy system configs     │
                            │ rsync -av               │
                            │ system/configs/etc/xdg/ │
                            │ → /etc/xdg/             │
                            └─────────────────────────┘
                                          │
                                          ▼
                            ┌─────────────────────────┐
                            │ Remove lock file        │
                            │ (via trap)              │
                            └─────────────────────────┘
                                          │
                                          ▼
                            ┌─────────────────────────┐
                            │ Prompt user:            │
                            │ "Update your user       │
                            │  configs now? (y/n)"    │
                            └─────────────────────────┘
                                          │
                              ┌───────────┴───────────┐
                              │ YES                   │ NO
                              ▼                       ▼
                ┌─────────────────────────┐  ┌─────────────────┐
                │ Run as current user:    │  │ Done            │
                │ su $SUDO_USER -c        │  │ Exit 0          │
                │ my-distro-update-user   │  └─────────────────┘
                └─────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Done            │
                    │ Exit 0          │
                    └─────────────────┘
```

### Detailed Steps

#### 1. Lock File Check

```bash
LOCK_FILE="/var/lock/my-distro-update.lock"

if [[ -f "$LOCK_FILE" ]]; then
    echo "ERROR: Another system update is already in progress"
    echo "If you're sure no update is running, remove: $LOCK_FILE"
    exit 1
fi

# Set trap to ensure cleanup on any exit
trap 'rm -f "$LOCK_FILE"' EXIT INT TERM
touch "$LOCK_FILE"
```

**Why**: Prevents multiple simultaneous system updates which could corrupt package state or git repository.

#### 2. Update System Packages

```bash
echo "Updating system packages..."
pacman -Syu --noconfirm
```

**What this does**:
- Syncs package databases
- Updates all installed packages
- May require reboot if kernel updated

**Potential issues**:
- Network failure: Will retry or fail gracefully
- Disk space: Pacman will warn if insufficient space
- Package conflicts: Pacman will prompt (even with --noconfirm for conflicts)

#### 3. Update my-distro Repository

```bash
echo "Updating my-distro repository..."
cd /opt/my-distro || exit 1
git pull origin main
```

**What this does**:
- Pulls latest commits from origin/main
- Updates system configs, user dotfiles, migrations
- Updates version number

**Potential issues**:
- Network failure: Will error, no changes made
- Local modifications: Will error (shouldn't happen normally)
- Merge conflicts: Shouldn't happen (root owns repo, users don't modify)

**Handling local modifications**:
```bash
# Check for local modifications before pull
if ! git diff-index --quiet HEAD --; then
    echo "WARNING: Local modifications detected in /opt/my-distro"
    echo "Stashing changes..."
    git stash
fi

git pull origin main

# Optionally reapply stash
# git stash pop
```

#### 4. Install New Packages

```bash
echo "Installing/updating packages from packages.list..."
if [[ -f system/packages.list ]]; then
    mapfile -t packages < <(grep -v '^#' system/packages.list | grep -v '^$')
    if [[ ${#packages[@]} -gt 0 ]]; then
        pacman -S --needed --noconfirm "${packages[@]}"
    fi
fi
```

**What --needed does**:
- Skips packages already at current version
- Only installs new or outdated packages
- Idempotent: safe to run multiple times

**packages.list format**:
```
# Core utilities
base-devel
git
neovim
fish

# Terminal
kitty
tmux

# Development
python
nodejs
npm
```

#### 5. Copy System Configurations

```bash
echo "Updating system-wide configurations..."
if [[ -d system/configs/etc/xdg ]]; then
    rsync -av system/configs/etc/xdg/ /etc/xdg/
fi
```

**What rsync does**:
- Copies only changed files
- Preserves permissions
- Recursive (-r implied by -a)
- Verbose output (-v)

**Trailing slash important**:
```bash
rsync -av system/configs/etc/xdg/ /etc/xdg/
# Copies CONTENTS of xdg/ into /etc/xdg/

rsync -av system/configs/etc/xdg /etc/
# Copies xdg/ DIRECTORY into /etc/, creating /etc/xdg/
```

#### 6. Prompt for User Update

```bash
if [[ -n "$SUDO_USER" ]]; then
    read -p "Update your user configs now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        su "$SUDO_USER" -c "my-distro-update-user"
    fi
fi
```

**Why prompt**:
- Convenient: Admin can update immediately
- Optional: Admin might want to review changes first
- Safe: Runs as original user, not as root

### Example Run

```bash
$ sudo my-distro-update-system
[sudo] password for alice:
Updating system packages...
:: Synchronizing package databases...
 core is up to date
 extra is up to date
 community is up to date
:: Starting full system upgrade...
resolving dependencies...
looking for conflicting packages...

Packages (5) neovim-0.9.0-1  python-3.11.2-1  ...

Total Download Size:   45.23 MiB
Total Installed Size: 178.91 MiB
Net Upgrade Size:       2.34 MiB

:: Proceed with installation? [Y/n] Y
[... download and install ...]

Updating my-distro repository...
remote: Enumerating objects: 15, done.
remote: Counting objects: 100% (15/15), done.
remote: Compressing objects: 100% (8/8), done.
remote: Total 10 (delta 5), reused 7 (delta 2), pack-reused 0
Unpacking objects: 100% (10/10), 2.34 KiB | 598.00 KiB/s, done.
From https://github.com/user/my-distro
   7a3c9e1..9f2d4c6  main       -> origin/main
Updating 7a3c9e1..9f2d4c6
Fast-forward
 system/configs/etc/xdg/fish/config.fish | 5 +++++
 user/migrations/006-update-fish.sh      | 12 ++++++++++++
 version                                 | 2 +-
 3 files changed, 18 insertions(+), 1 deletion(-)

Installing/updating packages from packages.list...
resolving dependencies...
looking for conflicting packages...
Packages (2) fish-3.6.0-1  ripgrep-13.0.0-1
[... install ...]

Updating system-wide configurations...
sending incremental file list
fish/
fish/config.fish
      1,234 100%    0.00kB/s    0:00:00 (xfr#1, to-chk=0/5)

Done! System updated to version 6.

Update your user configs now? (y/n) y
Running user update for alice...
[... see user update flow ...]

All done!
```

---

## User Update Workflow

### Overview

User updates apply personal configurations from the my-distro repository. Users can run this without sudo, and each user's update is independent.

### Command

```bash
my-distro-update-user
```

### Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                   my-distro-update-user                         │
│                     (no sudo needed)                            │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
                ┌───────────────────────────┐
                │ Check state directory     │
                │ ~/.local/share/           │
                │ my-distro-state/          │
                └───────────────────────────┘
                            │
                ┌───────────┴───────────┐
                │ Exists?               │
                └───────────┬───────────┘
                            │
              ┌─────────────┴─────────────┐
              │ NO                        │ YES
              ▼                           ▼
    ┌─────────────────────┐     ┌─────────────────────┐
    │ Create directory    │     │ Read version file   │
    │ echo "0" > version  │     │ current=$(cat       │
    │                     │     │ version)            │
    └─────────────────────┘     └─────────────────────┘
              │                           │
              └───────────┬───────────────┘
                          ▼
                ┌─────────────────────┐
                │ Read latest version │
                │ latest=$(cat        │
                │ /opt/my-distro/     │
                │ version)            │
                └─────────────────────┘
                          │
                          ▼
                ┌─────────────────────┐
                │ Compare versions    │
                │ current vs latest   │
                └─────────────────────┘
                          │
          ┌───────────────┼───────────────┐
          │               │               │
          ▼               ▼               ▼
   ┌────────────┐  ┌────────────┐  ┌────────────┐
   │ current==0 │  │ current <  │  │ current == │
   │ First run  │  │ latest     │  │ latest     │
   │            │  │ Migrate    │  │ Up-to-date │
   └────────────┘  └────────────┘  └────────────┘
          │               │               │
          ▼               ▼               ▼
   ┌────────────┐  ┌────────────┐  ┌────────────┐
   │ Copy all   │  │ Run        │  │ Nothing    │
   │ dotfiles   │  │ migrations │  │ to do      │
   │ to         │  │ from       │  │ Exit 0     │
   │ ~/.config/ │  │ current+1  │  └────────────┘
   │            │  │ to latest  │
   └────────────┘  └────────────┘
          │               │
          └───────┬───────┘
                  ▼
        ┌─────────────────────┐
        │ Update version file │
        │ echo "$latest" >    │
        │ version             │
        └─────────────────────┘
                  │
                  ▼
        ┌─────────────────────┐
        │ Done                │
        │ Exit 0              │
        └─────────────────────┘
```

### Detailed Steps

#### 1. Initialize State Directory

```bash
STATE_DIR="$HOME/.local/share/my-distro-state"
VERSION_FILE="$STATE_DIR/version"

# Create state directory if needed
if [[ ! -d "$STATE_DIR" ]]; then
    mkdir -p "$STATE_DIR"
fi

# Initialize version to 0 if not exists
if [[ ! -f "$VERSION_FILE" ]]; then
    echo "0" > "$VERSION_FILE"
fi
```

**State directory purpose**:
- Tracks user's current version
- Independent per-user (~/. local/share/)
- Survives system updates

#### 2. Read Versions

```bash
current_version=$(cat "$VERSION_FILE")
latest_version=$(cat /opt/my-distro/version)

echo "Current user version: $current_version"
echo "Latest distro version: $latest_version"
```

#### 3. Determine Action

```bash
if [[ $current_version -eq 0 ]]; then
    # First run: copy all dotfiles
    first_run_setup
elif [[ $current_version -lt $latest_version ]]; then
    # Update needed: run migrations
    run_migrations "$current_version" "$latest_version"
else
    # Already up-to-date
    echo "Already at version $current_version (latest: $latest_version)"
    exit 0
fi
```

### Example Run (First Time)

```bash
$ my-distro-update-user
Current user version: 0
Latest distro version: 6

First run detected! Setting up your configs...

Copying dotfiles to ~/.config/...
  → neovim configuration
  → fish shell configuration
  → kitty terminal configuration
  → tmux configuration
  → git configuration

Done! Configs initialized at version 6.

Your configs are in ~/.config/ - feel free to customize!
```

### Example Run (Update)

```bash
$ my-distro-update-user
Current user version: 4
Latest distro version: 6

Update needed! Running migrations 5 to 6...

Running migration 005-add-aliases.sh...
  ✓ Added new shell aliases

Running migration 006-update-fish.sh...
  ✓ Updated fish prompt configuration

Done! Updated from version 4 to version 6.

Review changes in ~/.config/ if needed.
```

### Example Run (Up-to-date)

```bash
$ my-distro-update-user
Current user version: 6
Latest distro version: 6

Already at version 6. Nothing to do!
```

---

## First-Run Initialization

### Purpose

When a user runs `my-distro-update-user` for the first time, they need a complete set of dotfiles. This is detected by `version=0`.

### Flow

```
First Run (version == 0)
│
├─ Create ~/.config/ if not exists
│
├─ Copy all files from /opt/my-distro/user/dotfiles/
│  │
│  ├─ neovim/init.lua → ~/.config/nvim/init.lua
│  ├─ fish/config.fish → ~/.config/fish/config.fish
│  ├─ kitty/kitty.conf → ~/.config/kitty/kitty.conf
│  └─ ... (all dotfiles)
│
├─ Set permissions (already correct, user-owned)
│
└─ Update version to 1 (or latest)
```

### Implementation

```bash
first_run_setup() {
    echo "First run detected! Setting up your configs..."

    # Ensure ~/.config exists
    mkdir -p "$HOME/.config"

    # Copy all dotfiles
    local dotfiles_dir="/opt/my-distro/user/dotfiles"

    if [[ ! -d "$dotfiles_dir" ]]; then
        echo "ERROR: Dotfiles directory not found: $dotfiles_dir"
        exit 1
    fi

    # Copy with rsync to handle subdirectories
    rsync -av "$dotfiles_dir/" "$HOME/.config/"

    # Update to latest version (skip to current version)
    echo "$latest_version" > "$VERSION_FILE"

    echo "Done! Configs initialized at version $latest_version."
    echo "Your configs are in ~/.config/ - feel free to customize!"
}
```

### Why Skip to Latest Version?

On first run, we set user version directly to latest, not to 1:

```bash
# Option A: Set to version 1
echo "1" > "$VERSION_FILE"
# Next update will run migrations 2, 3, 4, 5, 6
# Redundant! Dotfiles already include all changes

# Option B: Set to latest version (6)
echo "$latest_version" > "$VERSION_FILE"
# No migrations needed, dotfiles already current
# ✅ Correct approach
```

**Rationale**: Migrations are for updating existing configs. First-time users get complete, current configs, so no migrations needed.

### Handling Existing Configs

What if user already has some configs in ~/.config/?

```bash
first_run_setup() {
    # ... (setup as above)

    # Check for existing configs
    if [[ -d "$HOME/.config/nvim" ]]; then
        echo "WARNING: ~/.config/nvim already exists"
        echo "Skipping nvim config to preserve your settings"
        # Or: prompt user, or backup, or merge
    fi

    # Copy only if not exists
    for config_dir in "$dotfiles_dir"/*; do
        local dir_name=$(basename "$config_dir")
        if [[ ! -d "$HOME/.config/$dir_name" ]]; then
            cp -r "$config_dir" "$HOME/.config/"
            echo "  → $dir_name configuration"
        else
            echo "  ⊗ $dir_name already exists, skipping"
        fi
    done
}
```

**Decision**: For now, my-distro assumes first run means clean slate. Advanced handling can be added later.

---

## Migration Script Execution

### Purpose

Migrations incrementally update user configs from one version to the next. They add features, fix bugs, or adjust configs without overwriting user customizations.

### Flow

```
Migrations (current < latest)
│
├─ For each version from (current + 1) to latest:
│  │
│  ├─ Find migration script: NNN-description.sh
│  │
│  ├─ Check if script exists
│  │  │
│  │  ├─ YES: Execute script
│  │  │  ├─ Script modifies ~/.config/ incrementally
│  │  │  └─ Script is idempotent (safe to run multiple times)
│  │  │
│  │  └─ NO: Skip (no migration for this version)
│  │
│  └─ Continue to next version
│
└─ Update version file to latest
```

### Implementation

```bash
run_migrations() {
    local from_version=$1
    local to_version=$2

    echo "Running migrations from v$from_version to v$to_version..."

    for ((version = from_version + 1; version <= to_version; version++)); do
        # Find migration script for this version
        # Format: XXX-description.sh where XXX is zero-padded version
        local migration_pattern="/opt/my-distro/user/migrations/$(printf '%03d' "$version")-*.sh"
        local migration_scripts=( $migration_pattern )

        if [[ -f "${migration_scripts[0]}" ]]; then
            local script="${migration_scripts[0]}"
            echo "Running migration $(basename "$script")..."

            # Execute migration script
            if bash "$script"; then
                echo "  ✓ Migration $version completed"
            else
                echo "  ✗ Migration $version failed!"
                echo "  Your configs may be in an inconsistent state."
                echo "  Please check ~/.config/ and report this issue."
                exit 1
            fi
        else
            echo "No migration script for version $version (optional)"
        fi
    done

    # Update version file
    echo "$to_version" > "$VERSION_FILE"
    echo "Done! Updated to version $to_version."
}
```

### Migration Script Guidelines

Migrations should be:

1. **Idempotent**: Safe to run multiple times
2. **Non-destructive**: Don't delete user data
3. **Additive**: Add features, don't remove user customizations
4. **Defensive**: Check before modifying

### Example Migration Scripts

#### Migration 002: Add tmux configuration

```bash
#!/bin/bash
# migrations/002-add-tmux-conf.sh
# Add tmux configuration if not exists

set -e  # Exit on error

echo "Adding tmux configuration..."

TMUX_DIR="$HOME/.config/tmux"
TMUX_CONF="$TMUX_DIR/tmux.conf"

# Check if already exists
if [[ -f "$TMUX_CONF" ]]; then
    echo "  tmux.conf already exists, skipping"
    exit 0
fi

# Create directory
mkdir -p "$TMUX_DIR"

# Copy from dotfiles
cp /opt/my-distro/user/dotfiles/tmux/tmux.conf "$TMUX_CONF"

echo "  ✓ Added tmux configuration"
```

#### Migration 003: Update fish shell aliases

```bash
#!/bin/bash
# migrations/003-update-fish-aliases.sh
# Add new fish shell aliases

set -e

echo "Updating fish shell aliases..."

FISH_CONFIG="$HOME/.config/fish/config.fish"

# Ensure fish config exists
if [[ ! -f "$FISH_CONFIG" ]]; then
    echo "  fish config not found, creating..."
    mkdir -p "$HOME/.config/fish"
    touch "$FISH_CONFIG"
fi

# Check if aliases already added (idempotent)
if grep -q "# my-distro aliases v3" "$FISH_CONFIG"; then
    echo "  Aliases already present, skipping"
    exit 0
fi

# Append new aliases
cat >> "$FISH_CONFIG" << 'EOF'

# my-distro aliases v3
alias ll='ls -lah'
alias gs='git status'
alias gd='git diff'
alias gc='git commit'
EOF

echo "  ✓ Added new aliases"
```

#### Migration 004: Fix neovim plugin configuration

```bash
#!/bin/bash
# migrations/004-fix-nvim-plugins.sh
# Fix neovim plugin configuration format

set -e

echo "Fixing neovim plugin configuration..."

NVIM_CONFIG="$HOME/.config/nvim/init.lua"

if [[ ! -f "$NVIM_CONFIG" ]]; then
    echo "  nvim config not found, skipping"
    exit 0
fi

# Use sed to fix old plugin syntax
# Old: use 'plugin-name'
# New: use 'author/plugin-name'
if grep -q "use 'telescope'" "$NVIM_CONFIG"; then
    sed -i "s/use 'telescope'/use 'nvim-telescope\/telescope.nvim'/" "$NVIM_CONFIG"
    echo "  ✓ Fixed telescope plugin syntax"
else
    echo "  Already up-to-date, skipping"
fi
```

#### Migration 005: Add completions directory

```bash
#!/bin/bash
# migrations/005-add-completions.sh
# Add shell completions directory and files

set -e

echo "Adding shell completions..."

COMP_DIR="$HOME/.config/fish/completions"

# Create completions directory
mkdir -p "$COMP_DIR"

# Copy all completion files
cp -r /opt/my-distro/user/dotfiles/fish/completions/* "$COMP_DIR/" 2>/dev/null || true

echo "  ✓ Added completions directory"
```

### Rollback Support (Future Enhancement)

Migrations currently are forward-only. Future versions could support rollback:

```bash
# migrations/006-update-feature.sh
migrate_forward() {
    # Apply changes...
}

migrate_backward() {
    # Revert changes...
}

case "${1:-forward}" in
    forward) migrate_forward ;;
    backward) migrate_backward ;;
esac
```

---

## Multi-User Scenarios

### Scenario 1: Admin Updates System, Users Update Independently

```
System: v5
Users: alice (v5), bob (v3), charlie (v2)

Admin runs: sudo my-distro-update-system
  → System updates to v6
  → /opt/my-distro/ now at v6
  → /etc/xdg/ updated with v6 configs
  → Admin prompted to update own user (alice)
  → alice updates to v6

Later, bob logs in:
  bob$ my-distro-update-user
  → bob runs migrations 004, 005, 006
  → bob updates from v3 to v6

Later, charlie logs in:
  charlie$ my-distro-update-user
  → charlie runs migrations 003, 004, 005, 006
  → charlie updates from v2 to v6
```

**Key points**:
- System update doesn't force user updates
- Each user updates at their own pace
- Users can be on different versions temporarily
- No conflicts between users

### Scenario 2: New User on Existing System

```
System: v7 (already installed and updated)
New user: diane (first login)

diane$ my-distro-update-user
  → Detects version=0 (first run)
  → Copies all dotfiles from /opt/my-distro/user/dotfiles/
  → Sets version to 7 (current)
  → No migrations needed (dotfiles already v7)

Result: diane has fully current configs immediately
```

### Scenario 3: Multiple Admins

```
System: v5
Admins: alice, bob

Alice runs: sudo my-distro-update-system
  → System updates to v6
  → alice updates her user configs to v6

Bob runs: sudo my-distro-update-system
  → git pull shows "Already up-to-date"
  → No system changes needed
  → bob prompted to update his user configs
  → bob updates from v5 to v6
```

**Concurrent system updates prevented by lock file.**

### Scenario 4: Batch Update All Users

Admin wants to update all users after system update:

```bash
sudo my-distro-update-system

# Update all users with login shells
for user in $(cut -d: -f1,7 /etc/passwd | grep '/bin/\|/usr/bin/' | cut -d: -f1); do
    echo "Updating user: $user"
    sudo -u "$user" my-distro-update-user
done
```

**Use with caution**: Users might have customizations that could be affected.

### Scenario 5: User Without System Update

```
System: v5
User alice: v5

# Admin hasn't run system update yet, but alice tries user update
alice$ my-distro-update-user
  → current=5, latest=5 (reading from /opt/my-distro/version)
  → "Already up-to-date"

# Admin updates system
sudo my-distro-update-system
  → System now v6
  → /opt/my-distro/version now 6

# Alice updates again
alice$ my-distro-update-user
  → current=5, latest=6
  → Runs migration 006
  → Updates to v6
```

**Users can only update up to the version on the system.**

### Scenario 6: Skipping Versions

```
User bob: v2
System updates: v3 → v4 → v5 (bob doesn't update)
System now at: v5

bob$ my-distro-update-user
  → Runs migrations: 003, 004, 005
  → Updates from v2 directly to v5

Migrations must be cumulative and handle multi-version jumps.
```

---

## Troubleshooting

### System Update Issues

#### Lock File Won't Clear

```
Error: Another system update is already in progress
```

**Check**:
```bash
ps aux | grep my-distro-update-system
# If no process found:
sudo rm /var/lock/my-distro-update.lock
```

#### Git Pull Fails (Network)

```
fatal: unable to access 'https://github.com/...': Could not resolve host
```

**Solution**: Check network connectivity, try again later.

#### Git Pull Fails (Local Modifications)

```
error: Your local changes to the following files would be overwritten by merge:
	system/packages.list
```

**Solution**:
```bash
cd /opt/my-distro
sudo git status  # Check what's modified
sudo git diff    # Review changes
sudo git stash   # Temporarily stash changes
sudo git pull
# Manually reapply changes if needed
```

#### Package Installation Fails

```
error: failed to commit transaction (conflicting files)
package: /usr/bin/foo exists in filesystem
```

**Solution**:
```bash
# Check which package owns the file
pacman -Qo /usr/bin/foo

# Either remove the file or force install
sudo rm /usr/bin/foo
sudo pacman -S package-name
```

### User Update Issues

#### No Permission to Read /opt/my-distro/

```
cat: /opt/my-distro/version: Permission denied
```

**Check permissions**:
```bash
ls -la /opt/my-distro/
# Should be: drwxr-xr-x root root

# Fix if needed:
sudo chmod -R a+rX /opt/my-distro/
```

#### Migration Script Fails

```
Running migration 005-add-completions.sh...
  ✗ Migration 5 failed!
```

**Investigate**:
```bash
# Run migration manually to see error
bash -x /opt/my-distro/user/migrations/005-add-completions.sh

# Check migration script for issues
cat /opt/my-distro/user/migrations/005-add-completions.sh
```

**Recovery**:
```bash
# Fix the issue manually, then update version:
echo "5" > ~/.local/share/my-distro-state/version
# Try again
my-distro-update-user
```

#### Stuck at Old Version

```
Already at version 3
# But system is at version 6
```

**Force re-run migrations**:
```bash
# Manually set to version before stuck point
echo "2" > ~/.local/share/my-distro-state/version
my-distro-update-user
```

#### Want to Reset to Fresh State

```bash
# Backup existing configs
cp -r ~/.config ~/.config.backup.$(date +%Y%m%d)

# Reset version to trigger first-run
rm -rf ~/.local/share/my-distro-state
echo "0" > ~/.local/share/my-distro-state/version

# Run update (will copy all dotfiles fresh)
my-distro-update-user

# Manually merge back any customizations from backup
```

### Common Questions

**Q: Can I run user update without system update?**

A: Yes, but you'll only get features up to the system's version. System must be updated first to get latest features.

**Q: What if I customize a file that a migration wants to modify?**

A: Well-written migrations check before modifying and preserve user customizations. If a migration overwrites your changes, report it as a bug.

**Q: Can I skip a migration?**

A: Not recommended. Migrations may depend on previous ones. If you must, manually set your version:
```bash
echo "6" > ~/.local/share/my-distro-state/version
```

**Q: How do I see what a migration will do before running it?**

A: Read the migration script:
```bash
cat /opt/my-distro/user/migrations/006-update-feature.sh
```

**Q: Can I run my-distro-update-user multiple times?**

A: Yes! If you're already up-to-date, it does nothing. Migrations should be idempotent.

**Q: What if I accidentally run system update twice?**

A: Safe! Git pull will say "Already up-to-date". Packages with --needed won't reinstall. System configs will re-copy (no harm).

---

## Summary

### System Update

```bash
sudo my-distro-update-system
```

- Updates packages (pacman -Syu)
- Pulls latest repo (git pull)
- Installs new packages
- Copies system configs to /etc/xdg/
- Optionally updates admin's user configs

### User Update

```bash
my-distro-update-user
```

- Reads current and latest versions
- First run (v0): Copies all dotfiles
- Update (v < latest): Runs migrations
- Up-to-date: Does nothing

### Key Principles

- System and user updates are independent
- Multiple users can be on different versions
- Migrations are incremental and idempotent
- First-run users get complete, current configs
- Updates are explicit, not automatic
