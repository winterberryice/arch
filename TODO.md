# TODO

## V1 - Core Installation System

### Planning Phase (In Progress)

- [x] Partitioning strategy
  - [x] EFI handling (use existing or create new)
  - [x] LUKS encryption architecture
  - [x] BTRFS subvolume layout
  - [x] Swap strategy (zram + swapfile)
  - [x] TUI design (gum-based)
  - [x] Dual-boot scenarios (Windows first/Arch first)

- [ ] GPU Detection & Driver Installation
  - [ ] AMD vs NVIDIA detection logic
  - [ ] Microcode selection (amd-ucode vs intel-ucode)
  - [ ] Driver package selection
  - [ ] Handle hybrid GPU scenarios (integrated + discrete)

- [ ] LUKS Setup Workflow
  - [ ] Password handling (prompt, confirmation, strength check)
  - [ ] cryptsetup configuration
  - [ ] Key management strategy
  - [ ] /etc/crypttab configuration
  - [ ] initramfs hooks (encrypt, keyboard, keymap)

- [ ] systemd-boot Configuration
  - [ ] Boot entry creation
  - [ ] Windows detection and chainloading
  - [ ] Kernel parameter configuration (cryptdevice, root)
  - [ ] Fallback entries
  - [ ] Boot menu customization

- [ ] Installation Script Architecture
  - [ ] Script structure and organization
  - [ ] Error handling and recovery
  - [ ] Logging strategy
  - [ ] User interaction flow
  - [ ] Idempotency considerations

### Implementation Phase (Not Started)

- [ ] Partitioning Script
  - [ ] gum TUI implementation
  - [ ] Free space detection (parted wrapper)
  - [ ] ESP detection and validation
  - [ ] Partition creation (sgdisk commands)
  - [ ] Partition mode selection (free space vs reformat)

- [ ] LUKS & BTRFS Setup Script
  - [ ] LUKS container creation
  - [ ] BTRFS filesystem creation
  - [ ] Subvolume creation (@, @home, @snapshots, @var_log, @swap)
  - [ ] Mount point setup
  - [ ] fstab generation

- [ ] Base System Installation
  - [ ] pacstrap with essential packages
  - [ ] GPU-specific driver installation
  - [ ] Microcode installation
  - [ ] systemd-boot installation
  - [ ] Boot entry configuration

- [ ] System Configuration
  - [ ] Timezone and locale
  - [ ] Hostname setup
  - [ ] User creation
  - [ ] Network configuration (NetworkManager)
  - [ ] initramfs configuration (mkinitcpio.conf)
  - [ ] Bootloader finalization

- [ ] Swap Configuration
  - [ ] zram setup (systemd service)
  - [ ] BTRFS swapfile creation
  - [ ] CoW attribute disabling for @swap
  - [ ] Swap priority configuration

- [ ] Post-Install Integration
  - [ ] /opt/arch structure setup
  - [ ] arch-update-system script
  - [ ] arch-update-user script
  - [ ] Initial system snapshot (snapper)

### Testing Phase (Not Started)

- [ ] Test Scenarios
  - [ ] Windows-first dual boot
  - [ ] Arch-first dual boot
  - [ ] Arch-only fresh install
  - [ ] Reformat existing partition
  - [ ] Multiple free space regions
  - [ ] AMD system
  - [ ] NVIDIA system
  - [ ] Hybrid GPU system

- [ ] Error Handling Tests
  - [ ] Partition creation failures
  - [ ] LUKS password mismatch
  - [ ] Insufficient disk space
  - [ ] Missing ESP
  - [ ] Boot configuration errors

### Documentation (Partial)

- [x] docs/001-partitioning.md
- [ ] docs/002-gpu-detection.md
- [ ] docs/003-luks-setup.md
- [ ] docs/004-systemd-boot.md
- [ ] docs/005-installation-flow.md
- [ ] Installation guide (user-facing)
- [ ] Troubleshooting guide

---

## V2 - Advanced Features

### Hibernation Support
- [ ] Swapfile offset calculation for BTRFS
- [ ] LUKS resume configuration
- [ ] systemd-boot resume parameters
- [ ] Testing and validation

### Enhanced Partitioning
- [ ] Automatic Windows partition shrinking (from Linux)
- [ ] Interactive partition resizing
- [ ] LVM on LUKS option
- [ ] Multiple LUKS container support

### Multi-Distro Support
- [ ] Multiple BTRFS subvolumes for different distros
- [ ] Shared /home across distros (optional)
- [ ] Bootloader entry management for multiple distros

### Security Enhancements
- [ ] Encrypted /boot with GRUB
- [ ] TPM2 auto-unlock
- [ ] Secure Boot support
- [ ] YubiKey LUKS unlock

### Automation & Convenience
- [ ] Automated snapshot management
- [ ] Pre-upgrade snapshots
- [ ] Rollback functionality integration
- [ ] Configuration profiles (minimal, desktop, gaming, etc.)

---

## Ideas / Future Considerations

- Declarative configuration (NixOS-inspired)
- Remote unlock via SSH (dropbear in initramfs)
- Automated backup to external drive
- ZFS as alternative to BTRFS
- Wayland-only configuration option
- Minimal base system option (no DE)
- Custom kernel configuration
- Performance optimizations (tuned, auto-cpufreq)

---

## Next Immediate Steps

1. **GPU Detection Planning** - Define detection logic and driver selection
2. **LUKS Workflow Planning** - Password handling, encryption setup
3. **systemd-boot Planning** - Boot entry structure, Windows detection
4. **Script Architecture** - Overall structure, error handling, user flow
5. **Begin Implementation** - Start with partitioning TUI prototype
