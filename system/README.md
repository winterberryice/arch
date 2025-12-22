# System Directory

This directory contains system-wide configurations and package lists.

## Structure

```
system/
├── configs/
│   └── etc/
│       └── xdg/          # System-wide XDG defaults
│           ├── fish/     # Fish shell system defaults
│           ├── nvim/     # Neovim system defaults
│           └── ...
│
└── packages.list         # Packages to install system-wide
```

## System Configs

Files in `configs/etc/xdg/` are copied to `/etc/xdg/` during system updates.

### XDG Base Directory Hierarchy

```
Priority (highest to lowest):
1. ~/.config/          # User configs (user customizations)
2. /etc/xdg/           # System defaults (my-distro)
3. /usr/share/         # Package defaults (from pacman packages)
```

This means:
- Users can override any system default in their `~/.config/`
- System defaults in `/etc/xdg/` apply to all users
- Package defaults in `/usr/share/` are lowest priority

### Why /etc/xdg/?

- ✅ Avoids .pacnew conflicts (packages rarely touch /etc/xdg/)
- ✅ System-wide defaults for all users
- ✅ Users can override in ~/.config/
- ✅ Standard XDG search path

### Adding System Config

1. Create directory: `configs/etc/xdg/myapp/`
2. Add config files: `configs/etc/xdg/myapp/config.conf`
3. During system update, this will be copied to `/etc/xdg/myapp/`
4. Applications that support XDG will find it automatically

### Guidelines for System Configs

Keep system configs **minimal**:
- Only include settings that should apply to ALL users
- Don't include user-specific settings (usernames, emails, etc.)
- Prefer sensible defaults over opinionated choices
- Document why each setting is needed

**Bad example** (too opinionated):
```fish
# /etc/xdg/fish/config.fish
alias gc='git commit -S --signoff'  # Forces signed commits
set -gx EDITOR nano                  # Forces nano for everyone
```

**Good example** (sensible defaults):
```fish
# /etc/xdg/fish/config.fish
# Add my-distro bin to PATH
set -gx PATH /opt/my-distro/bin $PATH

# Disable fish greeting (users can re-enable)
set fish_greeting ""
```

### Testing System Configs

Before committing:

1. Test in /etc/xdg/:
   ```bash
   sudo cp configs/etc/xdg/fish/config.fish /etc/xdg/fish/
   ```

2. Test as new user (should work with defaults):
   ```bash
   sudo useradd -m testuser
   sudo -u testuser fish  # Should work with system defaults
   ```

3. Test user override:
   ```bash
   echo "set fish_greeting 'Custom greeting'" > ~/.config/fish/config.fish
   fish  # Should show custom greeting
   ```

## Packages List

`packages.list` contains packages to install system-wide.

### Format

```
# Comments are allowed
# One package per line
# Blank lines are ignored

base-devel
git
neovim
```

### Package Selection Guidelines

Include packages that are:
- ✅ Essential for the distro's purpose
- ✅ Required by your configs (e.g., if you config nvim, include neovim)
- ✅ Commonly needed by target users

Don't include:
- ❌ Rarely used packages (users can install themselves)
- ❌ Large packages without clear benefit
- ❌ Packages with security implications (unless necessary)

### Example packages.list

```
# Core development tools
base-devel
git

# Editors
neovim

# Shells
fish

# Terminal emulators
kitty

# Multiplexers
tmux

# System utilities
rsync
wget
curl
ripgrep
fd
bat
```

### Package Installation

During `my-distro-update-system`:
```bash
pacman -S --needed $(cat system/packages.list | grep -v '^#' | grep -v '^$')
```

The `--needed` flag means:
- Only install if not already installed
- Only update if newer version available
- Idempotent: safe to run multiple times

### Testing Package Installation

```bash
# Test in Docker (fast)
docker run --rm -it archlinux:latest bash
# Inside container:
pacman -Syu --noconfirm
cat packages.list | grep -v '^#' | xargs pacman -S --needed --noconfirm
```

## Update Flow

During system update (`my-distro-update-system`):

1. **Update packages**: `pacman -Syu`
2. **Pull repo**: `cd /opt/my-distro && git pull`
3. **Install packages**: Read packages.list, install with --needed
4. **Sync configs**: `rsync -av configs/etc/xdg/ /etc/xdg/`

### Config Sync Details

Using `rsync`:
```bash
rsync -av system/configs/etc/xdg/ /etc/xdg/
```

This:
- Copies only changed files (efficient)
- Preserves permissions
- Creates directories as needed
- Doesn't delete files not in source (safe)

### Verifying System Update

After system update:

```bash
# Check version
cat /opt/my-distro/version

# Check packages installed
pacman -Qq | grep -E 'neovim|fish|kitty'

# Check system configs
ls -la /etc/xdg/
cat /etc/xdg/fish/config.fish
```

## Handling /etc/ Configs (Non-XDG)

Some applications don't support XDG and require `/etc/` configs:

### Strategy 1: Avoid if possible
Many apps have XDG support or allow config path override.

### Strategy 2: Document manual steps
Instead of automating, document in README:
```markdown
## Manual Configuration

After installing, edit `/etc/pacman.conf` and add:
```

### Strategy 3: Accept .pacnew files
For critical configs, modify `/etc/` directly and accept occasional .pacnew merges.

### Strategy 4: Patch system configs
Keep patches in `system/patches/` and apply during updates:
```bash
# system/patches/pacman.conf.patch
patch /etc/pacman.conf < system/patches/pacman.conf.patch
```

## Summary

- **System configs** go in `configs/etc/xdg/` (XDG-compliant only)
- **Packages** go in `packages.list` (one per line)
- Keep system defaults **minimal** and **sensible**
- Users can override everything in their `~/.config/`
- Test before committing!
