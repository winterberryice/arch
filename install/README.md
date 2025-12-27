# Arch Linux Installer - Phase 0 MVP

Automated Arch Linux installer inspired by [omarchy](https://github.com/basecamp/omarchy).

## Features (Phase 0)

✅ **Automated installation** - No prompts, fast testing
✅ **BTRFS with subvolumes** - @, @home, @snapshots, @var_log, @swap
✅ **systemd-boot** - Modern UEFI bootloader
✅ **COSMIC desktop** - Beautiful tiling desktop environment
✅ **Hardware detection** - Auto-detects GPU/CPU for driver installation
✅ **Compression** - zstd compression for all subvolumes
✅ **Swap** - zram + BTRFS swapfile

## ⚠️ Warnings

**This is Phase 0 MVP for QEMU testing:**
- ⚠️ **Wipes the first detected disk completely**
- ⚠️ **Hardcoded passwords** (change immediately after install)
- ⚠️ **No LUKS encryption** (Phase 1 feature)
- ⚠️ **No dual-boot support** (Phase 1 feature)
- ⚠️ **No interactive TUI** (Phase 1 feature)

**DO NOT use in production without changing passwords!**

## Installation

### From Arch Linux Live USB

1. **Boot Arch Linux live environment** (UEFI mode required)

2. **Connect to internet:**
   ```bash
   # Wired (automatic)
   # WiFi
   iwctl
   device list
   station wlan0 scan
   station wlan0 get-networks
   station wlan0 connect "SSID"
   exit
   ```

3. **Download installer:**
   ```bash
   # Option A: Clone repository
   pacman -Sy git
   git clone https://github.com/youruser/arch.git
   cd arch/install

   # Option B: Direct download
   curl -O https://raw.githubusercontent.com/youruser/arch/main/install/install.sh
   # Download other files...
   ```

4. **Run installer:**
   ```bash
   cd install
   sudo ./install.sh
   ```

5. **Wait for completion** (10-30 minutes depending on internet speed)

6. **Reboot:**
   ```bash
   reboot
   ```

### Default Credentials

**⚠️ CHANGE THESE IMMEDIATELY!**

```
Username: january
Password: test123

Root password: root123
```

### After First Boot

1. **Change passwords:**
   ```bash
   passwd              # Change user password
   sudo passwd root    # Change root password
   rm ~/CHANGE_PASSWORDS.txt
   ```

2. **Update system:**
   ```bash
   sudo pacman -Syu
   ```

3. **Install COSMIC desktop (optional):**
   ```bash
   # Clone the repo if you haven't already
   git clone https://github.com/winterberryice/arch.git
   cd arch
   bash install-cosmic.sh
   ```

   Note: COSMIC installation takes 10-30 minutes and needs 8GB+ RAM to build.
   See: https://wiki.archlinux.org/title/COSMIC

4. **Install additional software:**
   ```bash
   sudo pacman -S firefox chromium
   ```

## Testing in QEMU

### Prerequisites

```bash
sudo pacman -S qemu-full edk2-ovmf
```

### Download Arch Linux ISO

```bash
cd test
wget https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso
```

### Run Installation Test

```bash
cd test
./qemu-test.sh install
```

This will:
1. Create a 20GB virtual disk
2. Launch QEMU with Arch ISO
3. You can then run the installer inside QEMU

### Test Installed System

After installation completes:

```bash
./qemu-test.sh test
```

### Clean Up

```bash
./qemu-test.sh clean
```

## Architecture

```
install/
├── install.sh              # Main orchestrator
├── lib/
│   ├── common.sh          # Error handling, logging, utilities
│   ├── hardware.sh        # GPU/CPU detection
│   └── ui.sh              # Output functions
└── phases/
    ├── 01-prepare.sh      # Requirements check, hardware detection
    ├── 02-partition.sh    # Auto-partition disk (EFI + BTRFS)
    ├── 03-btrfs.sh        # BTRFS subvolumes and mounting
    ├── 04-install.sh      # pacstrap base system
    ├── 05-configure.sh    # System config (chroot)
    ├── 06-bootloader.sh   # systemd-boot setup (chroot)
    └── 07-finalize.sh     # Swap, services (chroot)
```

## Partition Layout

```
/dev/sdX1 (512MB)     - EFI System Partition (FAT32)
/dev/sdX2 (remaining) - BTRFS
  ├── @              -> /
  ├── @home          -> /home
  ├── @snapshots     -> /.snapshots
  ├── @var_log       -> /var/log
  └── @swap          -> /swap
```

## Installed Packages

**Base:**
- base, linux, linux-firmware
- btrfs-progs, networkmanager
- sudo, vim, git

**CPU-specific:**
- amd-ucode OR intel-ucode

**GPU-specific:**
- NVIDIA: nvidia, nvidia-utils, nvidia-settings
- AMD/Intel: mesa, vulkan-radeon/vulkan-intel

**Desktop:**
- cosmic-epoch, cosmic-greeter
- pipewire, pipewire-pulse, wireplumber

## Logs

Installation logs are saved to:
```
/var/log/arch-install.log
```

## Troubleshooting

### Installation fails

Check the log:
```bash
cat /var/log/arch-install.log
```

### Can't boot after install

1. Boot from Arch USB
2. Mount system:
   ```bash
   mount /dev/sdX2 -o subvol=@ /mnt
   mount /dev/sdX1 /mnt/boot
   arch-chroot /mnt
   ```
3. Reinstall bootloader:
   ```bash
   bootctl install
   ```

### COSMIC doesn't start

Check logs:
```bash
journalctl -u cosmic-greeter
```

## Next Steps (Future Phases)

**Phase 1:**
- LUKS encryption
- Interactive TUI (gum)
- Flexible partitioning
- Dual-boot support

**Phase 2:**
- /opt/arch architecture
- arch-update-system/user scripts
- Multi-user support
- Version migrations

## Credits

Inspired by:
- [omarchy](https://github.com/basecamp/omarchy) - Beautiful, opinionated Linux by DHH
- [archinstall](https://github.com/archlinux/archinstall) - Official Arch installer

## License

MIT License - See LICENSE file
