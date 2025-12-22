# my-distro

An Arch Linux-based distribution designed for quick, disposable, and easily reinstallable systems with full multi-user support.

## Overview

**my-distro** is a configuration management system for Arch Linux that:
- ✅ Provides system-wide defaults for multiple users
- ✅ Allows per-user customization
- ✅ Avoids .pacnew file complexity
- ✅ Uses version-tracked migrations for updates
- ✅ Supports quick system reinstalls

## Quick Start

### Installation

```bash
# Clone repository to /opt/my-distro
sudo git clone https://github.com/YOUR-USERNAME/my-distro.git /opt/my-distro

# Add to PATH (optional, for convenience)
echo 'export PATH="/opt/my-distro/bin:$PATH"' | sudo tee /etc/profile.d/my-distro.sh

# Run initial system setup
sudo /opt/my-distro/bin/my-distro-update-system
```

### For Users

After system is set up, each user should run:

```bash
my-distro-update-user
```

This will:
- Copy dotfiles to `~/.config/` (first run)
- Or run migrations to update configs (subsequent runs)

## Architecture

```
/opt/my-distro/                    # System-wide installation
├── bin/                           # Update utilities
│   ├── my-distro-update-system   # System updater (sudo)
│   └── my-distro-update-user     # User updater (no sudo)
├── system/
│   ├── configs/etc/xdg/          # System-wide defaults
│   └── packages.list             # Packages to install
├── user/
│   ├── dotfiles/                 # Initial user configs
│   └── migrations/               # Version-based updates
└── version                       # Current version

~/.local/share/my-distro-state/   # Per-user state
└── version                       # User's version

~/.config/                        # User configs (overrides system)
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed architecture.

## Documentation

- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Technical architecture and design
- **[DESIGN_DECISIONS.md](docs/DESIGN_DECISIONS.md)** - Why we made specific choices
- **[UPDATE_WORKFLOW.md](docs/UPDATE_WORKFLOW.md)** - How updates work with flowcharts
- **[TESTING.md](docs/TESTING.md)** - Testing strategies and workflows

## Key Features

### Multi-User Support

Unlike single-user dotfile managers (like Omarchy), my-distro provides:
- System-wide defaults in `/etc/xdg/` for all users
- Per-user customization in `~/.config/`
- Independent update schedules per user

### Minimal .pacnew Conflicts

By using `/etc/xdg/` instead of package-managed `/etc/` paths:
- Arch packages rarely touch `/etc/xdg/`
- No manual .pacnew file merging needed
- System configs update cleanly

### Version-Tracked Updates

- Explicit version numbers (not git hashes)
- Sequential migrations for incremental updates
- First-run detection for new users
- Each user tracks their own version

### Two-Tier Updates

**System Update** (requires sudo):
```bash
sudo my-distro-update-system
```
- Updates system packages (pacman -Syu)
- Pulls latest repository (git pull)
- Installs packages from list
- Updates system configs in /etc/xdg/

**User Update** (no sudo needed):
```bash
my-distro-update-user
```
- Copies dotfiles on first run
- Runs migrations for version updates
- Updates user's version tracking

## Usage Examples

### Admin: Update System

```bash
# Update system and packages
sudo my-distro-update-system

# Optionally update your own user configs
my-distro-update-user
```

### User: Update Configs

```bash
# Update your personal configs
my-distro-update-user

# Check your current version
cat ~/.local/share/my-distro-state/version
```

### Admin: Update All Users

```bash
# Update system first
sudo my-distro-update-system

# Update all users (optional)
for user in alice bob charlie; do
    sudo -u $user my-distro-update-user
done
```

## Directory Structure

### `/opt/my-distro/bin/`

Update utilities:
- `my-distro-update-system` - System updater (requires sudo)
- `my-distro-update-user` - User updater (no sudo)

### `/opt/my-distro/system/`

System-wide configuration:
- `configs/etc/xdg/` - System defaults (copied to `/etc/xdg/`)
- `packages.list` - Packages to install

See [system/README.md](system/README.md) for details.

### `/opt/my-distro/user/`

User configuration:
- `dotfiles/` - Initial configs (copied to `~/.config/` on first run)
- `migrations/` - Version-based update scripts

See [user/README.md](user/README.md) for details.

## Development Status

**Current Status**: Documentation and planning phase

This repository currently contains:
- ✅ Complete documentation
- ✅ Architecture planning
- ✅ Directory structure
- ⚠️ Stub scripts (not yet implemented)

### TODO: Implementation

- [ ] Implement `my-distro-update-system` script
- [ ] Implement `my-distro-update-user` script
- [ ] Add example migrations
- [ ] Add complete dotfile examples
- [ ] Set up testing infrastructure (Docker, QEMU)
- [ ] Test on real Arch Linux system

See [CONTRIBUTING.md](#contributing) for development guidelines.

## Testing

### Quick Testing (Docker)

```bash
# Build test image
docker build -t my-distro-test testing/

# Run tests
./testing/docker-test.sh
```

### Full System Testing (QEMU)

```bash
# Set up QEMU VM with Arch Linux
# See docs/TESTING.md for detailed instructions

# Run full system tests
./testing/qemu-test.sh
```

See [docs/TESTING.md](docs/TESTING.md) for complete testing guide.

## Contributing

Contributions welcome! This project is in active development.

### Development Setup

1. Fork this repository
2. Clone your fork
3. Create a branch: `git checkout -b feature/your-feature`
4. Make changes
5. Test in Docker/QEMU
6. Commit: `git commit -am 'Add feature'`
7. Push: `git push origin feature/your-feature`
8. Create Pull Request

### Guidelines

- Follow existing code style
- Update documentation for changes
- Test before submitting PR
- Keep commits atomic and well-described

## FAQ

**Q: Why not use Omarchy?**

A: Omarchy is excellent for single-user systems, but my-distro is designed for multi-user environments with system-wide defaults.

**Q: Why not use Ansible/Chef/Puppet?**

A: Those are great for managing fleets of servers. my-distro is simpler and focused on disposable, reinstallable single systems.

**Q: Will this work on non-Arch distros?**

A: Not currently. The system update script uses pacman. Could be adapted for other distros.

**Q: What if I want private configs?**

A: Use a private GitHub repository. You'll need to set up SSH keys for the root user. See [docs/DESIGN_DECISIONS.md](docs/DESIGN_DECISIONS.md#why-public-repository).

**Q: Can I skip migrations?**

A: Not recommended. Migrations may depend on previous ones. Manually setting your version is possible but unsupported.

See [docs/UPDATE_WORKFLOW.md#troubleshooting](docs/UPDATE_WORKFLOW.md#troubleshooting) for more Q&A.

## Inspiration

This project is inspired by:
- **[Omarchy](https://github.com/seanh/omarchy)** - User-level Arch configuration management
- **XDG Base Directory Specification** - Standard config hierarchy
- **Arch Linux philosophy** - Simplicity and user control

## License

MIT License - See [LICENSE](LICENSE) file for details

## Contact

- GitHub: [YOUR-USERNAME/my-distro](https://github.com/YOUR-USERNAME/my-distro)
- Issues: [Report a bug](https://github.com/YOUR-USERNAME/my-distro/issues)

---

**Status**: Planning phase - documentation complete, implementation pending.
