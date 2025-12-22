# Design Decisions

This document explains the rationale behind key architectural decisions in my-distro.

## Table of Contents

1. [Why Not Omarchy's User-Only Approach?](#why-not-omarchys-user-only-approach)
2. [Why Not Traditional /etc/ Heavy Approach?](#why-not-traditional-etc-heavy-approach)
3. [Why Single Repository?](#why-single-repository)
4. [Why Two Separate Update Scripts?](#why-two-separate-update-scripts)
5. [Why /opt/my-distro/ for Installation?](#why-optmy-distro-for-installation)
6. [Why Public Repository?](#why-public-repository)
7. [Why Version Numbers Instead of Git Hashes?](#why-version-numbers-instead-of-git-hashes)
8. [Why /etc/xdg/ for System Configs?](#why-etcxdg-for-system-configs)
9. [Why First-Run Copy Instead of Symlinks?](#why-first-run-copy-instead-of-symlinks)
10. [Why No Automatic System Updates?](#why-no-automatic-system-updates)

---

## Why Not Omarchy's User-Only Approach?

### Omarchy's Design

```
~/.local/share/omarchy/           # User-level only
├── dotfiles/
├── packages.list
└── update-omarchy                # Single user script
```

**Strengths:**
- ✅ No root required
- ✅ Simple single-user setup
- ✅ User has full control
- ✅ Easy to test and develop

**Limitations for Multi-User:**
- ❌ Each user must install separately (~/.local/share/omarchy/)
- ❌ No system-wide defaults (new users get nothing)
- ❌ Package installation requires each user to run `pacman` with sudo
- ❌ Duplicate storage (each user has full copy of configs)
- ❌ Updates must be run by each user independently
- ❌ No centralized system consistency

### my-distro's Multi-User Design

```
/opt/my-distro/                   # System-wide, single copy
├── system/
│   └── configs/etc/xdg/          # System-wide defaults
└── user/
    └── dotfiles/                 # Per-user initial configs

~/.config/                        # Per-user overrides
```

**Benefits:**
- ✅ System-wide defaults for all users
- ✅ Single source of truth
- ✅ New users get sensible defaults immediately
- ✅ Efficient storage (one copy of configs)
- ✅ Admin controls system packages and updates
- ✅ Users still have full override capability

### Use Case Comparison

| Scenario | Omarchy | my-distro |
|----------|---------|-----------|
| Single user workstation | ✅ Perfect fit | ⚠️ Overkill |
| Multi-user server | ❌ Each user separate | ✅ Designed for this |
| New user onboarding | ❌ Manual setup per user | ✅ Automatic defaults |
| Corporate/shared systems | ❌ No central control | ✅ System admin control |
| Personal laptop | ✅ Simple and sufficient | ⚠️ More complexity |

### Decision

**my-distro chooses multi-user architecture** because:

1. **Target use case**: Disposable multi-user systems (servers, shared workstations, containers)
2. **System-wide consistency**: All users get same baseline experience
3. **Efficient management**: One system update applies to all users
4. **New user experience**: Fresh users immediately have working environment

**When to use Omarchy instead**: Single-user personal systems where you don't need system-wide defaults.

---

## Why Not Traditional /etc/ Heavy Approach?

### Traditional Linux Config Management

```
/etc/
├── pacman.conf              # Package-managed
├── nginx/nginx.conf         # Package-managed
├── ssh/sshd_config          # Package-managed
├── nvim/                    # NOT package-managed (free to use)
└── custom-app.conf          # Your config here
```

**The .pacnew Problem:**

When Arch updates a package that includes `/etc/` configs:

```bash
# Original install
pacman -S nginx
# Creates /etc/nginx/nginx.conf (MD5: abc123)

# You modify it
vim /etc/nginx/nginx.conf  # (MD5: def456)

# Package updates
pacman -Syu
# nginx wants to update /etc/nginx/nginx.conf
# Detects modification (MD5 mismatch)
# Creates /etc/nginx/nginx.conf.pacnew instead
# Now you must manually merge!
```

**The .pacnew Maintenance Burden:**

```bash
# After system updates, you get:
/etc/pacman.conf.pacnew
/etc/nginx/nginx.conf.pacnew
/etc/ssh/sshd_config.pacnew
/etc/sudoers.d/custom.pacnew
...

# Manual merge required for EACH file:
vimdiff /etc/pacman.conf{,.pacnew}
# Tedious, error-prone, time-consuming
```

### my-distro's Approach: Avoid Package-Managed Paths

```
/etc/xdg/                    # XDG system configs (NOT package-managed)
├── nvim/
├── fish/
└── kitty/

/opt/my-distro/system/configs/etc/xdg/  # Source of truth
```

**Why This Works:**

1. **Packages don't touch /etc/xdg/**: Most packages install defaults to `/usr/share/` not `/etc/xdg/`
2. **XDG precedence**: `~/.config/` > `/etc/xdg/` > `/usr/share/` → users can still override
3. **Full control**: my-distro owns `/etc/xdg/`, no conflicts with packages
4. **Clean updates**: `rsync system/configs/etc/xdg/ /etc/xdg/` → no .pacnew files

### What About Package-Managed /etc/ Files?

For files that packages DO manage in /etc/:

```bash
# Option 1: Don't modify them - accept package defaults
# (simplest, least maintenance)

# Option 2: Maintain separate patches
# Keep your modifications as patch files, reapply after updates

# Option 3: Pin package versions
# Use pacman's IgnorePkg for critical configs you must customize

# Option 4: Accept .pacnew and handle it
# For the few files you truly need to customize
```

**my-distro philosophy**: Minimize /etc/ modifications, prefer XDG paths.

### Decision

**my-distro avoids /etc/ heavy approach** because:

1. **.pacnew maintenance is high overhead** on frequently updated systems
2. **XDG paths provide same functionality** without conflicts
3. **Disposable systems shouldn't require manual merging** on updates
4. **User overrides work better** with XDG hierarchy

---

## Why Single Repository?

### Alternative: Multiple Repositories

```
Option A: Separate repos
https://github.com/user/my-distro-system
https://github.com/user/my-distro-user
https://github.com/user/my-distro-packages
```

**Problems:**
- ❌ Version synchronization across repos
- ❌ Multiple git pulls needed
- ❌ Harder to maintain consistency
- ❌ More complex branching/tagging
- ❌ Split documentation

### my-distro: Single Repository

```
https://github.com/user/my-distro
/opt/my-distro/ (single clone)
├── system/
├── user/
└── version (single version number)
```

**Benefits:**
- ✅ Single version number applies to everything
- ✅ One git pull updates all components
- ✅ Atomic commits across system and user configs
- ✅ Easier to maintain and reason about
- ✅ Single documentation location

### Version Synchronization Example

```bash
# Scenario: Add fish shell support

# Single repo (my-distro):
git commit -m "Add fish shell support (v5)"
# Modified:
#   system/packages.list (+ fish)
#   system/configs/etc/xdg/fish/config.fish
#   user/dotfiles/fish/config.fish
#   user/migrations/005-add-fish.sh
#   version (4 → 5)

# Multiple repos:
# Repo 1: my-distro-system
git commit -m "Add fish system config"
# Repo 2: my-distro-user
git commit -m "Add fish user dotfiles"
# Repo 3: my-distro-packages
git commit -m "Add fish package"
# Now: How do you know which versions match?
# Need complex version mapping or git submodules
```

### Decision

**Single repository** because:

1. **Atomic updates**: One git pull gets everything
2. **Single version number**: Simplifies tracking
3. **Easier maintenance**: One place to make changes
4. **Better DX**: Clone once, everything works

---

## Why Two Separate Update Scripts?

### Alternative: Single Update Script

```bash
# Option: Single script my-distro-update

#!/bin/bash
if [[ $EUID -eq 0 ]]; then
    # Running as root: do system updates
    pacman -Syu
    git pull
    rsync system/configs/etc/xdg/ /etc/xdg/
else
    # Running as user: do user updates
    cp user/dotfiles/* ~/.config/
fi
```

**Problems with single script:**

1. **Confusing invocation**:
   ```bash
   sudo my-distro-update      # System update
   my-distro-update           # User update
   # Same command, totally different behavior!
   ```

2. **Permission errors**:
   ```bash
   my-distro-update  # User runs without sudo
   # Fails when trying to update system packages
   # Error messages confusing
   ```

3. **Safety concerns**:
   ```bash
   sudo my-distro-update  # Admin runs
   # Which user's ~/.config/ gets updated?
   # $HOME might be /root/ or /home/admin/ depending on sudo flags
   ```

4. **Multi-user complexity**:
   ```bash
   # How do other users update?
   # Must run same script but behavior differs based on privilege
   ```

### my-distro: Two Separate Scripts

```bash
# my-distro-update-system: Clear purpose
sudo my-distro-update-system
# Always updates system, never touches user configs
# Can optionally prompt to run user update for current user

# my-distro-update-user: Clear purpose
my-distro-update-user
# Always updates current user's ~/.config/
# Never requires sudo, never touches system
```

**Benefits:**

1. **Clear intent**: Script name tells you what it does
2. **Appropriate permissions**: Each script requests what it needs
3. **No confusion**: Can't accidentally run wrong operation
4. **Multi-user safe**: Each user runs their own update independently
5. **Flexible timing**: System admin updates system, users update when ready

### Usage Patterns

```bash
# Scenario 1: Admin updates system, then self
sudo my-distro-update-system
# [Updates system]
# "Update your user configs now? (y/n)"
# [Runs my-distro-update-user as $SUDO_USER]

# Scenario 2: User updates self (system already current)
my-distro-update-user
# [Updates own ~/.config/]

# Scenario 3: Admin updates system for all
sudo my-distro-update-system
for user in alice bob charlie; do
    sudo -u $user my-distro-update-user
done

# Scenario 4: User doesn't have sudo, just updates self
my-distro-update-user
# Works! No sudo needed
```

### Decision

**Two separate scripts** because:

1. **Clear responsibility**: Each script has one job
2. **Privilege separation**: Explicit about what needs sudo
3. **Multi-user safety**: No confusion about which user updates
4. **Better UX**: Names clearly indicate purpose
5. **Flexibility**: System and user updates can be run independently

---

## Why /opt/my-distro/ for Installation?

### Directory Options Considered

| Location | Pros | Cons |
|----------|------|------|
| `/usr/local/my-distro/` | Traditional for local installs | Often used for manual compiles |
| `/opt/my-distro/` | Standard for self-contained apps | Perfect fit |
| `/var/lib/my-distro/` | For application state | Not for code/configs |
| `/etc/my-distro/` | For configuration only | Not for scripts/dotfiles |
| `/usr/share/my-distro/` | For read-only data | Pacman-managed path |
| `/home/my-distro/` | User-like structure | Weird for system install |

### Filesystem Hierarchy Standard (FHS)

From [FHS 3.0 spec](https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html):

> `/opt` : Add-on application software packages
>
> `/opt` is reserved for the installation of add-on application software packages.
> A package to be installed in `/opt` must locate its static files in a separate
> `/opt/<package>` directory tree, where `<package>` is a name that describes the
> software package.

**my-distro fits this perfectly:**
- ✅ Add-on software package (not part of base system)
- ✅ Self-contained in `/opt/my-distro/`
- ✅ Single directory tree
- ✅ Optional (system works without it)

### Structure Benefits

```
/opt/my-distro/               # Self-contained
├── bin/                      # Executables
├── system/                   # System configs
├── user/                     # User templates
└── version                   # Version file

# Easy to:
- Backup: tar czf my-distro.tar.gz /opt/my-distro/
- Remove: rm -rf /opt/my-distro/
- Inspect: cd /opt/my-distro/ && ls
- Clone: git clone ... /opt/my-distro/
```

### PATH Management

```bash
# Add to /etc/profile.d/my-distro.sh
export PATH="/opt/my-distro/bin:$PATH"

# Now users can run:
my-distro-update-user  # Instead of /opt/my-distro/bin/my-distro-update-user
```

### Decision

**/opt/my-distro/** because:

1. **FHS compliant**: Correct location per standard
2. **Self-contained**: Everything in one directory
3. **Clear ownership**: Obviously not package-managed
4. **Easy management**: Simple to backup/remove/inspect
5. **Standard practice**: Matches other self-contained tools

---

## Why Public Repository?

### Public vs Private Repository

| Aspect | Public Repo | Private Repo |
|--------|-------------|--------------|
| **Credentials** | None needed | SSH key or token required |
| **Git pull** | `git pull` (anyone) | `git pull` (needs auth) |
| **Transparency** | Full visibility | Hidden from public |
| **Sharing** | Easy to fork | Must grant access |
| **Secrets** | ❌ Can't include | ✅ Can include |
| **Setup complexity** | ✓ Simple | ⚠️ More complex |

### my-distro Default: Public Repository

```bash
# Initial install (anyone can clone)
sudo git clone https://github.com/user/my-distro.git /opt/my-distro

# Updates (any sudo user can pull)
sudo my-distro-update-system
# Internally: cd /opt/my-distro && git pull
# No credentials needed!
```

**Benefits:**

1. **Zero credential management**: No SSH keys or tokens to configure
2. **Simple updates**: Just `git pull`, no auth prompts
3. **Multi-admin friendly**: Any sudo user can update system
4. **Shareable**: Others can inspect, fork, learn from your setup
5. **Transparency**: Users see exactly what they're installing

**Constraints:**

- ❌ Cannot include secrets (API keys, passwords, tokens)
- ❌ Cannot include private/proprietary configs
- ⚠️ Anyone can see your config choices

### Private Repository Pattern

If you need private configs with secrets:

```bash
# Option 1: Root-owned credentials
# Setup once during install:
sudo mkdir -p /root/.ssh
sudo ssh-keyscan github.com >> /root/.ssh/known_hosts
# Add deploy key to GitHub repo
sudo vi /root/.ssh/id_ed25519

# Clone with SSH
sudo git clone git@github.com:user/my-distro-private.git /opt/my-distro

# Updates work with root's credentials
sudo my-distro-update-system
# Uses /root/.ssh/id_ed25519 automatically
```

```bash
# Option 2: HTTPS with token
# Store token in root-readable location
sudo vi /opt/my-distro/.git/config
# [remote "origin"]
#   url = https://TOKEN@github.com/user/my-distro-private.git

# Updates work
sudo my-distro-update-system
```

### Hybrid Pattern: Public Repo + Secret Management

```bash
# Public repo: my-distro (no secrets)
# Secrets: Separate secret management system

# In migration scripts:
# user/migrations/010-fetch-api-keys.sh
#!/bin/bash
# Fetch API keys from password manager
pass show api/github-token > ~/.config/gh/token
pass show api/openai-key > ~/.config/openai/key
```

**Tools for secret management:**
- [pass](https://www.passwordstore.org/) - CLI password manager
- [gopass](https://www.gopass.pw/) - Team password manager
- [Bitwarden CLI](https://bitwarden.com/help/cli/) - Bitwarden integration
- [Vault](https://www.vaultproject.io/) - HashiCorp Vault
- [SOPS](https://github.com/mozilla/sops) - Encrypted files in git

### Decision

**Public repository by default** because:

1. **Simplicity**: No credential management needed
2. **Accessibility**: Anyone can git pull
3. **Multi-admin**: All sudo users can update
4. **Sharing**: Easy for others to adopt/fork
5. **Secret handling**: Use separate secret management tools

**Use private** when:
- You have proprietary configurations
- You want to include API keys directly (not recommended)
- Privacy is more important than convenience

---

## Why Version Numbers Instead of Git Hashes?

### Alternative: Git Hash-Based Versioning

```bash
# Using git commit hashes
current=$(cat ~/.local/share/my-distro-state/version)
# 7a3c9e1f2b4d8a6c

latest=$(cd /opt/my-distro && git rev-parse HEAD)
# 9f2d4c6a8b3e7d1f

# How do you know which migrations to run?
# Need to check git log and determine commits between
```

**Problems:**

1. **Non-sequential**: Can't easily compare "is A newer than B?"
2. **Migration complexity**: Hard to determine which migrations to run
3. **Not human-friendly**: "Version 7a3c9e1" vs "Version 5"
4. **Branch complexity**: Hashes don't map cleanly across branches
5. **Merge conflicts**: Version number conflicts are easy to resolve

### my-distro: Sequential Integer Versions

```bash
# Simple integer versions
current=$(cat ~/.local/share/my-distro-state/version)
# 3

latest=$(cat /opt/my-distro/version)
# 5

# Easy to compare: 3 < 5, need to run migrations 4 and 5
```

**Benefits:**

1. **Sequential**: Easy to compare (3 < 5)
2. **Simple migration logic**: Run migrations from current+1 to latest
3. **Human-friendly**: "Version 5" is clear
4. **Branch-safe**: Can merge version bumps easily
5. **Predictable**: Always incrementing

### Version Bumping Strategy

```bash
# Version file at repo root
/opt/my-distro/version
---
5
---

# When you make changes requiring user migration:
echo "6" > version
git add version user/migrations/006-change-fish-prompt.sh
git commit -m "v6: Change fish prompt style"
git tag v6
git push --tags
```

### Migration Naming Convention

```
user/migrations/
├── 001-initial.sh          # Version 1: Initial setup
├── 002-add-nvim-plugins.sh # Version 2: Added nvim plugins
├── 003-update-fish.sh      # Version 3: Updated fish config
├── 004-add-tmux.sh         # Version 4: Added tmux config
└── 005-new-aliases.sh      # Version 5: New shell aliases

# Convention: NNN-description.sh where NNN matches version number
```

### Handling Branches and Development

```bash
# Main branch: production versions
main: v1 → v2 → v3 → v4 → v5

# Development branch: test versions
dev: v5 → v6-dev → v7-dev

# Use version file + git tags
# main: version = 5
# dev: version = 7-dev (string comparison still works)
```

### Semantic Versioning Alternative

Could use semantic versioning (MAJOR.MINOR.PATCH):

```
1.0.0 → 1.1.0 → 1.2.0 → 2.0.0
```

**Pros:**
- Conveys breaking changes (major bump)
- Standard in software industry
- Tooling support

**Cons:**
- More complex migration logic
- Overkill for config management
- Need to track three numbers

**Decision**: Simple integers are sufficient for config versioning.

### Decision

**Sequential integer versions** because:

1. **Simple comparison**: Easy to determine if update needed
2. **Clear migration logic**: Run migrations from X to Y
3. **Human-readable**: "Version 5" is clearer than "7a3c9e1"
4. **Predictable**: Always incrementing, no surprises
5. **Sufficient**: Config management doesn't need semantic versioning

---

## Why /etc/xdg/ for System Configs?

### XDG Base Directory Specification

The [XDG Base Directory Spec](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html) defines:

```
$XDG_CONFIG_HOME (default: ~/.config/)
  User-specific configurations

$XDG_CONFIG_DIRS (default: /etc/xdg/)
  System-wide configuration directories (preference-ordered)

Search order: $XDG_CONFIG_HOME > $XDG_CONFIG_DIRS > application defaults
```

### Why This Matters for my-distro

```
User runs: nvim

Neovim searches for config in order:
1. ~/.config/nvim/init.lua         # User's personal config (HIGHEST PRIORITY)
2. /etc/xdg/nvim/init.lua          # System-wide default (my-distro)
3. /usr/share/nvim/runtime/        # Package defaults (LOWEST PRIORITY)
```

**Perfect for multi-user:**
- ✅ All users get sensible defaults from `/etc/xdg/nvim/`
- ✅ Any user can override in their `~/.config/nvim/`
- ✅ No package conflicts (packages use `/usr/share/`)

### Alternative Paths Considered

| Path | Pros | Cons |
|------|------|------|
| `/etc/app/` | Traditional | ⚠️ Risk of package conflicts |
| `/usr/local/etc/app/` | FHS compliant | Not in XDG search path |
| `/etc/xdg/app/` | XDG compliant | ✅ Perfect |
| `/opt/my-distro/configs/` | Self-contained | Not in app search paths |
| `/usr/share/my-distro/` | Standard location | Not in XDG precedence |

### Application Support

**XDG-compliant applications** (use /etc/xdg/):
- Neovim: `~/.config/nvim/` → `/etc/xdg/nvim/`
- Fish shell: `~/.config/fish/` → `/etc/xdg/fish/`
- Kitty terminal: `~/.config/kitty/` → `/etc/xdg/kitty/`
- i3 window manager: `~/.config/i3/` → `/etc/xdg/i3/`
- sway: `~/.config/sway/` → `/etc/xdg/sway/`
- Most modern CLI tools following XDG spec

**Non-XDG applications** (special handling needed):
- Bash: Uses `~/.bashrc` (no system-wide user config in XDG)
- Vim: Uses `~/.vimrc` and `/etc/vimrc` (predates XDG)
- Tmux: Uses `~/.tmux.conf` (no XDG support yet)
- SSH: Uses `~/.ssh/config` (security reasons)

### Handling Non-XDG Applications

```bash
# Strategy 1: User dotfiles only (no system default)
# Put in user/dotfiles/.bashrc
# Copied to ~/.bashrc on first run

# Strategy 2: /etc/ with .pacnew acceptance
# Some /etc/ configs are unavoidable
# Accept occasional .pacnew files for these

# Strategy 3: Wrapper scripts
# Create wrapper that sets XDG vars
/opt/my-distro/bin/my-vim
#!/bin/bash
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
exec vim -u "${XDG_CONFIG_HOME}/vim/vimrc" "$@"

# Strategy 4: Migration script creates symlink
# migrations/008-link-bashrc.sh
ln -sf ~/.config/bash/bashrc ~/.bashrc
```

### Package Conflict Reality Check

```bash
# Check what packages provide /etc/xdg/ files
pacman -Qlq | grep '/etc/xdg/' | sort -u

# Typical results: Very few packages!
# /etc/xdg/autostart/       # Desktop autostart files
# /etc/xdg/menus/           # Desktop menu files
# /etc/xdg/user-dirs.defaults

# Most CLI tools DON'T ship /etc/xdg/ configs
# They ship /usr/share/ defaults only
```

**Reality**: /etc/xdg/ is mostly empty on fresh Arch install, perfect for my-distro!

### Decision

**/etc/xdg/ for system configs** because:

1. **XDG compliant**: Standard config search path
2. **User overrides work**: `~/.config/` takes precedence
3. **No package conflicts**: Packages rarely use `/etc/xdg/`
4. **Multi-user perfect**: All users inherit defaults
5. **Modern application support**: Most CLI tools follow XDG spec

---

## Why First-Run Copy Instead of Symlinks?

### Alternative: Symlink Approach

```bash
# Symlink user configs to system repo
~/.config/nvim -> /opt/my-distro/user/dotfiles/nvim
~/.config/fish -> /opt/my-distro/user/dotfiles/fish
~/.config/kitty -> /opt/my-distro/user/dotfiles/kitty
```

**Problems with symlinks:**

1. **No user customization**:
   ```bash
   # User tries to customize:
   echo "set fish_greeting" >> ~/.config/fish/config.fish
   # Actually modifies /opt/my-distro/user/dotfiles/fish/config.fish
   # Now system repo is dirty!
   # Affects ALL users!
   ```

2. **Git complications**:
   ```bash
   cd /opt/my-distro
   git status
   # modified: user/dotfiles/fish/config.fish
   # User's personal changes pollute system repo
   ```

3. **Permission issues**:
   ```bash
   # User can read /opt/my-distro/user/dotfiles/
   # But can't write (root-owned)
   # Symlinks would be read-only for users
   ```

4. **Update conflicts**:
   ```bash
   sudo my-distro-update-system
   cd /opt/my-distro && git pull
   # Overwrites user's customizations!
   ```

### my-distro: Copy on First Run

```bash
# First run: Copy files to user's ~/.config/
cp -r /opt/my-distro/user/dotfiles/* ~/.config/

# Now user owns their configs
ls -la ~/.config/fish/
# drwxr-xr-x user user ~/.config/fish/

# User can freely modify
echo "set fish_greeting" >> ~/.config/fish/config.fish
# No impact on /opt/my-distro/ or other users
```

**Benefits:**

1. **User ownership**: User owns and can modify their configs
2. **Independence**: Changes don't affect system repo or other users
3. **Customization**: Users can freely customize without conflicts
4. **Clean git**: System repo stays clean
5. **Updates work**: Git pull doesn't overwrite user configs

### How Updates Work with Copy Approach

```bash
# Initial setup (v1): User copies dotfiles
my-distro-update-user
# → cp /opt/my-distro/user/dotfiles/* ~/.config/

# User customizes
echo "alias ll='ls -la'" >> ~/.config/fish/config.fish

# System updates to v2 with new dotfile feature
sudo my-distro-update-system
# → /opt/my-distro/ now at v2

# User updates
my-distro-update-user
# → Doesn't recopy dotfiles (user at v1, not v0)
# → Runs migration script: migrations/002-add-new-feature.sh
# → Migration script adds ONLY the new feature
```

### Migration Script Pattern

```bash
# migrations/002-add-tmux-conf.sh
#!/bin/bash
# Add tmux configuration if not exists

if [[ ! -f ~/.config/tmux/tmux.conf ]]; then
    mkdir -p ~/.config/tmux
    cp /opt/my-distro/user/dotfiles/tmux/tmux.conf ~/.config/tmux/
    echo "Added tmux configuration"
else
    echo "tmux configuration already exists, skipping"
fi
```

**Key principle**: Migrations are additive and idempotent, don't overwrite user customizations.

### Comparison

| Approach | User Owns Configs | Can Customize | Clean Git | Updates Easy |
|----------|-------------------|---------------|-----------|--------------|
| **Symlinks** | ❌ No | ❌ Breaks system | ❌ Dirty | ⚠️ Overwrites |
| **Copy** | ✅ Yes | ✅ Yes | ✅ Clean | ✅ Migrations |
| **Stow-style** | ⚠️ Partial | ⚠️ Complex | ✅ Clean | ⚠️ Complex |

### Stow-Style Alternative

[GNU Stow](https://www.gnu.org/software/stow/) creates symlinks intelligently:

```bash
# Could use stow
cd /opt/my-distro/user
stow -t ~/.config dotfiles

# Creates symlinks per-file, not per-directory
~/.config/fish/config.fish -> /opt/my-distro/user/dotfiles/fish/config.fish
```

**Better than naive symlinks** but still:
- ⚠️ User can't edit files (read-only)
- ⚠️ Requires stow installed
- ⚠️ More complex mental model
- ⚠️ Still pollutes git if user somehow edits

### Decision

**Copy on first run** because:

1. **User ownership**: Users own and control their configs
2. **Customization friendly**: Users can modify freely
3. **Clean separation**: User changes don't affect system
4. **Simple model**: Easy to understand (copy once, then migrate)
5. **Update friendly**: Migrations add features without overwriting

---

## Why No Automatic System Updates?

### Alternative: Automatic Updates via Systemd Timer

```bash
# Option: Auto-update system daily
/etc/systemd/system/my-distro-update.timer
/etc/systemd/system/my-distro-update.service

# Runs: my-distro-update-system automatically
```

**Problems with automatic updates:**

1. **Surprise breakage**:
   ```bash
   # User is working
   # Auto-update runs in background
   # Packages update, breaking dependencies
   # User's session suddenly broken
   ```

2. **Network usage**:
   ```bash
   # Auto-update during important video call
   # Bandwidth consumed by pacman -Syu
   # User didn't choose timing
   ```

3. **No review opportunity**:
   ```bash
   # Auto-update applies system config changes
   # User didn't review what's changing
   # Potentially unwanted changes applied
   ```

4. **Rolling release risk**:
   ```bash
   # Arch is rolling release
   # Updates can occasionally break things
   # Auto-update means no chance to wait for fixes
   ```

### my-distro: Manual System Updates Only

```bash
# Admin explicitly runs:
sudo my-distro-update-system

# Admin controls:
- When to update (timing)
- Whether to update (can skip if busy)
- Can review changes first (git log)
```

**Benefits:**

1. **User control**: Admin chooses when to update
2. **Review opportunity**: Can check `git log` before pulling
3. **No surprises**: Updates only when explicitly requested
4. **Stability**: Can delay updates if needed
5. **Resource control**: No unexpected network usage

### Optional: Notification System

Could add update notification without auto-updating:

```bash
# Check for updates, don't apply
/opt/my-distro/bin/my-distro-check-updates

# Could run via cron/systemd timer:
# - Checks if /opt/my-distro/ has upstream changes
# - Sends notification if updates available
# - Doesn't actually update anything
# - User decides when to run my-distro-update-system
```

### User Updates Are Also Manual

```bash
# Users run explicitly:
my-distro-update-user

# Benefits:
- User chooses when to apply config changes
- Can review what will change (cat /opt/my-distro/user/migrations/*)
- No surprise config modifications during work
```

### Decision

**Manual updates only** because:

1. **User control**: Both admins and users control timing
2. **Stability**: No surprise breakage
3. **Rolling release safety**: Can wait before updating if needed
4. **Transparency**: Updates are explicit, not hidden
5. **Optional notifications**: Can add non-intrusive update checks later

---

## Summary of Key Decisions

| Decision | Rationale |
|----------|-----------|
| **Multi-user architecture** | System-wide defaults + per-user customization |
| **Single git repository** | Atomic updates, single version number, simpler |
| **Two update scripts** | Clear responsibility, privilege separation, safety |
| **/opt/my-distro/** | FHS compliant, self-contained, clear ownership |
| **Public repo default** | No credentials needed, simple updates, shareable |
| **Integer versions** | Simple comparison, easy migrations, human-friendly |
| **/etc/xdg/ for configs** | XDG compliant, no package conflicts, user overrides work |
| **Copy on first run** | User ownership, customization friendly, clean git |
| **Manual updates** | User control, stability, no surprises |

These decisions work together to create a system that is:
- ✅ Multi-user capable
- ✅ Easy to maintain
- ✅ Low .pacnew overhead
- ✅ User-customizable
- ✅ Reproducible and disposable
- ✅ Simple to understand

---

## Questions or Concerns?

If you disagree with any of these decisions or have alternative approaches, please open an issue or PR to discuss! These decisions are documented to be transparent and open to refinement.
