# systemd-boot Configuration

## Overview

This document describes the systemd-boot bootloader setup for the Arch Linux installer. systemd-boot is a simple, modern UEFI bootloader that provides fast boot times and clean dual-boot support with Windows.

## Design Goals

- ✅ Simple, fast bootloader (no complex configuration)
- ✅ Dual-boot with Windows (automatic detection)
- ✅ LUKS-encrypted root support (cryptdevice parameters)
- ✅ Fallback boot entries (recovery option)
- ✅ Clean boot menu (timeout, default entry)
- ✅ Easy to maintain and troubleshoot

## Why systemd-boot?

### Advantages

**Simplicity:**
- Plain text config files (easy to edit)
- No complex scripting (unlike GRUB)
- Minimal configuration required

**Speed:**
- Fast boot (instant menu)
- Direct EFI boot (no intermediate stages)
- No unnecessary modules

**Integration:**
- Part of systemd (already installed)
- Native UEFI (no legacy BIOS support)
- Works perfectly with LUKS

**Dual-boot:**
- Auto-detects Windows bootloader
- No manual Windows entry needed (unlike GRUB's os-prober)
- Clean, simple boot menu

### Limitations

**UEFI only:**
- No legacy BIOS support
- Requires EFI System Partition
- Not suitable for old hardware (pre-2010)

**Cannot unlock LUKS for /boot:**
- /boot must be unencrypted
- GRUB can unlock LUKS /boot (but complex)
- Trade-off: simplicity vs. maximum security

**No fancy features:**
- No themes/customization (minimal UI)
- No chainloading complex scenarios
- Basic functionality only

**Perfect for our use case!** Modern hardware, UEFI, simple dual-boot.

## systemd-boot Architecture

### File Structure

```
/boot/                              (ESP mounted here)
├── EFI/
│   ├── systemd/
│   │   └── systemd-bootx64.efi    ← systemd-boot bootloader
│   ├── Microsoft/
│   │   └── bootmgfw.efi            ← Windows bootloader (if dual-boot)
│   └── BOOT/
│       └── BOOTX64.EFI             ← Fallback bootloader
│
├── loader/
│   ├── loader.conf                 ← Main configuration
│   └── entries/
│       ├── arch.conf               ← Arch Linux entry
│       ├── arch-fallback.conf      ← Arch fallback entry
│       └── ...
│
├── vmlinuz-linux                   ← Kernel
├── initramfs-linux.img             ← Initramfs
├── initramfs-linux-fallback.img    ← Fallback initramfs
└── amd-ucode.img                   ← CPU microcode (or intel-ucode.img)
```

### Boot Flow

```
1. UEFI firmware loads systemd-boot from /boot/EFI/systemd/
2. systemd-boot reads /boot/loader/loader.conf
3. Displays boot menu (entries from /boot/loader/entries/)
4. User selects entry (or default after timeout)
5. systemd-boot loads kernel + initramfs
6. Kernel boots with specified parameters
7. initramfs prompts for LUKS password (if encrypted)
8. System continues booting
```

## Installation

### Install systemd-boot

**Command (from chroot):**
```bash
bootctl install
```

**What this does:**
- Installs systemd-bootx64.efi to /boot/EFI/systemd/
- Creates /boot/loader/ directory structure
- Sets systemd-boot as default UEFI boot entry
- Creates fallback boot entry

**Output:**
```
Created "/boot/EFI/systemd".
Created "/boot/EFI/BOOT".
Created "/boot/loader".
Created "/boot/loader/entries".
Copied "/usr/lib/systemd/boot/efi/systemd-bootx64.efi" to "/boot/EFI/systemd/systemd-bootx64.efi".
Copied "/usr/lib/systemd/boot/efi/systemd-bootx64.efi" to "/boot/EFI/BOOT/BOOTX64.EFI".
Random seed file /boot/loader/random-seed successfully written (32 bytes).
Created EFI boot entry "Linux Boot Manager".
```

### Verify Installation

```bash
bootctl status
```

**Expected output:**
- systemd-boot is installed
- ESP path: /boot
- Default boot entry: Linux Boot Manager

## Loader Configuration

### /boot/loader/loader.conf

**Purpose:** Main bootloader configuration
**Location:** `/boot/loader/loader.conf`

**Minimal configuration:**
```
default  arch.conf
timeout  3
console-mode max
editor   no
```

**Parameters explained:**

**`default arch.conf`**
- Default boot entry (matches filename in entries/)
- Can use wildcards: `arch*.conf` or `arch`
- Or use `@saved` to remember last choice

**`timeout 3`**
- Seconds to wait before auto-booting default
- `0` = instant boot (no menu)
- `menu-force` = always show menu (no timeout)

**`console-mode max`**
- Use maximum console resolution
- Options: `keep`, `max`, `auto`, `0`-`9`
- `max` provides best readability

**`editor no`**
- Disable kernel parameter editing at boot
- Security: Prevents bypassing LUKS by editing cmdline
- Can enable for troubleshooting: `editor yes`

### Example Configurations

**Quick boot (no menu):**
```
default  arch.conf
timeout  0
editor   no
```

**Interactive (for dual-boot):**
```
default  arch.conf
timeout  5
console-mode max
editor   no
```

**Remember last choice:**
```
default  @saved
timeout  3
console-mode max
editor   no
```

## Boot Entries

### Arch Linux Entry

**File:** `/boot/loader/entries/arch.conf`

**Basic structure:**
```
title   Arch Linux
linux   /vmlinuz-linux
initrd  /amd-ucode.img
initrd  /initramfs-linux.img
options cryptdevice=UUID=<LUKS-UUID>:cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw
```

**Fields explained:**

**`title`** - Display name in boot menu
- Example: "Arch Linux", "Arch (Encrypted)"
- Shown to user during boot selection

**`linux`** - Kernel path (relative to ESP root)
- `/vmlinuz-linux` for mainline kernel
- `/vmlinuz-linux-lts` for LTS kernel

**`initrd`** - Initramfs images (can have multiple)
- First: CPU microcode (`/amd-ucode.img` or `/intel-ucode.img`)
- Second: Main initramfs (`/initramfs-linux.img`)
- Order matters: microcode must load first

**`options`** - Kernel command line parameters
- Everything after `options` is passed to kernel
- Critical for LUKS, BTRFS, GPU settings

### Kernel Parameters (options line)

**Required parameters:**

**`cryptdevice=UUID=<uuid>:cryptroot`**
- Tells encrypt hook which LUKS device to unlock
- Format: `cryptdevice=UUID=<uuid>:<mapper-name>`
- `<uuid>` from `blkid /dev/nvme0n1pX`
- `<mapper-name>` becomes `/dev/mapper/cryptroot`

**`root=/dev/mapper/cryptroot`**
- Root filesystem location (after LUKS unlock)
- Points to mapped device, not raw partition

**`rootflags=subvol=@`**
- BTRFS subvolume to mount as root
- Our root is `@` subvolume

**`rw`**
- Mount root read-write (standard)

**Optional parameters:**

**NVIDIA systems:**
```
nvidia_drm.modeset=1
```
- Enable DRM kernel mode setting for NVIDIA
- Required for Wayland, modern display management

**Quiet boot:**
```
quiet splash
```
- `quiet` - Suppress most kernel messages
- `splash` - Show boot splash (if configured)

**Debug boot issues:**
```
loglevel=3
```
- Control kernel log verbosity (0-7)
- 3 = errors only, 7 = debug everything

### Complete Example (AMD + LUKS)

**File:** `/boot/loader/entries/arch.conf`
```
title   Arch Linux
linux   /vmlinuz-linux
initrd  /amd-ucode.img
initrd  /initramfs-linux.img
options cryptdevice=UUID=12345678-1234-1234-1234-123456789abc:cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw
```

### Complete Example (Intel + NVIDIA + LUKS)

**File:** `/boot/loader/entries/arch.conf`
```
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options cryptdevice=UUID=12345678-1234-1234-1234-123456789abc:cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ nvidia_drm.modeset=1 rw
```

## Fallback Entry

### Purpose

**Fallback initramfs:**
- Includes ALL kernel modules (not autodetected)
- Larger but more compatible
- Use if main boot fails (hardware changes, broken autodetect)

### Fallback Entry File

**File:** `/boot/loader/entries/arch-fallback.conf`
```
title   Arch Linux (Fallback)
linux   /vmlinuz-linux
initrd  /amd-ucode.img
initrd  /initramfs-linux-fallback.img
options cryptdevice=UUID=12345678-1234-1234-1234-123456789abc:cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw
```

**Difference:** Uses `initramfs-linux-fallback.img` instead of `initramfs-linux.img`

**When to use:**
- Main boot entry fails
- Hardware changes (new GPU, etc.)
- Autodetect hook issues

## Windows Dual-Boot

### Automatic Detection

**systemd-boot auto-detects Windows!**
- Scans ESP for `/EFI/Microsoft/bootmgfw.efi`
- Automatically adds "Windows Boot Manager" entry
- No manual configuration needed

**Boot menu shows:**
```
Arch Linux
Arch Linux (Fallback)
Windows Boot Manager               ← Auto-detected!
Reboot Into Firmware Interface
```

### Manual Windows Entry (Optional)

**If auto-detection fails, create manual entry:**

**File:** `/boot/loader/entries/windows.conf`
```
title   Windows 11
efi     /EFI/Microsoft/Boot/bootmgfw.efi
```

**Fields:**
- `title` - Display name
- `efi` - Path to Windows bootloader (relative to ESP)

**Usually not needed!** systemd-boot finds Windows automatically.

### Boot Order

**Entries appear in order:**
1. Alphabetically by filename (in `/boot/loader/entries/`)
2. Then auto-detected entries (Windows, firmware)

**To control order, use filename prefixes:**
```
/boot/loader/entries/
├── 10-arch.conf           ← First
├── 20-arch-fallback.conf  ← Second
└── 30-windows.conf        ← Third (if manual)
```

## Getting LUKS UUID

### During Installation

**After creating LUKS partition:**
```bash
LUKS_UUID=$(blkid -s UUID -o value /dev/nvme0n1p4)
echo "UUID: $LUKS_UUID"
```

**Or full blkid output:**
```bash
blkid /dev/nvme0n1p4
# Output: /dev/nvme0n1p4: UUID="12345678-..." TYPE="crypto_LUKS"
```

**Store in variable for boot entry creation:**
```bash
OPTIONS_LINE="cryptdevice=UUID=${LUKS_UUID}:cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw"
```

### Manual Method

**If you need UUID later:**
```bash
# Show all partitions with UUIDs
lsblk -f

# Or specific partition
blkid /dev/nvme0n1p4
```

## Boot Entry Creation Script

### Template Approach

**Create entry from template:**
```bash
LUKS_UUID=$(blkid -s UUID -o value "$LUKS_PARTITION")
MICROCODE_IMG="/amd-ucode.img"  # or /intel-ucode.img
NVIDIA_PARAMS=""  # or "nvidia_drm.modeset=1" if NVIDIA detected

cat > /boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  ${MICROCODE_IMG}
initrd  /initramfs-linux.img
options cryptdevice=UUID=${LUKS_UUID}:cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ ${NVIDIA_PARAMS}rw
EOF
```

### Fallback Entry Creation

```bash
cat > /boot/loader/entries/arch-fallback.conf <<EOF
title   Arch Linux (Fallback)
linux   /vmlinuz-linux
initrd  ${MICROCODE_IMG}
initrd  /initramfs-linux-fallback.img
options cryptdevice=UUID=${LUKS_UUID}:cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ ${NVIDIA_PARAMS}rw
EOF
```

## Installation Workflow

### Complete Setup (in chroot)

**Step-by-step:**

```bash
# 1. Install systemd-boot
bootctl install

# 2. Create loader.conf
cat > /boot/loader/loader.conf <<EOF
default  arch.conf
timeout  3
console-mode max
editor   no
EOF

# 3. Detect hardware
LUKS_UUID=$(blkid -s UUID -o value /dev/nvme0n1p4)
HAS_AMD_CPU=true  # From GPU detection phase
HAS_NVIDIA_GPU=false  # From GPU detection phase

# 4. Set microcode and GPU params
if [[ "$HAS_AMD_CPU" == true ]]; then
    MICROCODE="/amd-ucode.img"
else
    MICROCODE="/intel-ucode.img"
fi

if [[ "$HAS_NVIDIA_GPU" == true ]]; then
    NVIDIA_PARAMS="nvidia_drm.modeset=1 "
else
    NVIDIA_PARAMS=""
fi

# 5. Create main entry
cat > /boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  ${MICROCODE}
initrd  /initramfs-linux.img
options cryptdevice=UUID=${LUKS_UUID}:cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ ${NVIDIA_PARAMS}rw
EOF

# 6. Create fallback entry
cat > /boot/loader/entries/arch-fallback.conf <<EOF
title   Arch Linux (Fallback)
linux   /vmlinuz-linux
initrd  ${MICROCODE}
initrd  /initramfs-linux-fallback.img
options cryptdevice=UUID=${LUKS_UUID}:cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ ${NVIDIA_PARAMS}rw
EOF

# 7. Verify installation
bootctl status
```

## Updating systemd-boot

### Automatic Updates

**systemd provides update service:**
```bash
systemctl enable systemd-boot-update.service
```

**What it does:**
- Checks for systemd-boot updates
- Updates bootloader automatically when systemd updates
- Recommended to enable

### Manual Update

**If needed:**
```bash
bootctl update
```

**When to run:**
- After systemd package update
- If boot issues appear
- Rarely needed (auto-update handles this)

## Maintenance

### Listing Entries

```bash
bootctl list
```

**Shows:**
- All boot entries
- Default entry
- Entry details (kernel, initrd, options)

### Current Boot Entry

```bash
bootctl status
```

**Shows:**
- Current boot entry
- ESP mount point
- Firmware info
- Secure Boot status

### Removing Old Entries

**Manual cleanup:**
```bash
rm /boot/loader/entries/old-entry.conf
```

**Kernel updates:**
- Kernel files automatically updated by pacman
- Entries reference `/vmlinuz-linux` (symlink, always current)
- No manual entry updates needed!

## Troubleshooting

### 1. systemd-boot Menu Doesn't Appear

**Symptom:** Boots directly to Windows or UEFI

**Causes:**
- systemd-boot not installed
- Wrong UEFI boot order
- ESP not mounted

**Fix:**
```bash
# Boot from USB, mount ESP
mount /dev/nvme0n1p1 /mnt/boot
mount /dev/mapper/cryptroot /mnt
arch-chroot /mnt

# Reinstall systemd-boot
bootctl install

# Check UEFI boot order
efibootmgr
```

### 2. "Waiting for /dev/mapper/cryptroot" Error

**Symptom:** Boot hangs waiting for root device

**Causes:**
- Wrong UUID in cryptdevice parameter
- Missing encrypt hook
- Wrong mapper name

**Fix:**
```bash
# Boot from USB, unlock manually
cryptsetup open /dev/nvme0n1p4 cryptroot
mount /dev/mapper/cryptroot /mnt
mount /dev/nvme0n1p1 /mnt/boot
arch-chroot /mnt

# Check UUID
blkid /dev/nvme0n1p4

# Fix boot entry
nano /boot/loader/entries/arch.conf
# Update cryptdevice=UUID=... line

# Check mkinitcpio.conf has encrypt hook
nano /etc/mkinitcpio.conf
mkinitcpio -P
```

### 3. No Boot Menu (Auto-boots)

**Symptom:** Skips menu, boots default immediately

**Cause:** `timeout 0` in loader.conf

**Fix:**
```bash
nano /boot/loader/loader.conf
# Change timeout to 3 or higher
```

**Or hold Space during boot to force menu.**

### 4. Windows Entry Missing

**Symptom:** Windows not showing in boot menu

**Causes:**
- Windows not installed on same EFI partition
- Windows bootloader in non-standard location

**Check:**
```bash
ls /boot/EFI/Microsoft/Boot/
# Should see bootmgfw.efi
```

**Fix (manual entry):**
```bash
cat > /boot/loader/entries/windows.conf <<EOF
title   Windows
efi     /EFI/Microsoft/Boot/bootmgfw.efi
EOF
```

### 5. Kernel Panic / Won't Boot

**Use fallback entry!**
- Select "Arch Linux (Fallback)" from menu
- Boots with all modules loaded
- Investigate main entry issue after booting

## Security Considerations

### editor=no (Recommended)

**Why disable editor:**
- User can edit kernel parameters at boot
- Could bypass LUKS: `init=/bin/bash` drops to root shell
- Security issue if physical access

**When to enable:**
- Troubleshooting (temporarily)
- Single-user system, trusted physical access

### Secure Boot

**systemd-boot supports Secure Boot**
- Requires signed kernels
- More complex setup
- V2 feature

**V1:** Assume Secure Boot disabled (most users)

## V1 Implementation Summary

**Features:**
- ✅ Install systemd-boot with `bootctl install`
- ✅ Simple loader.conf (3-second timeout, editor disabled)
- ✅ Main Arch entry with LUKS parameters
- ✅ Fallback entry for recovery
- ✅ Auto-detect CPU (AMD/Intel microcode)
- ✅ Auto-detect GPU (NVIDIA kernel params)
- ✅ Windows auto-detection (no manual entry)
- ✅ Enable auto-update service
- ✅ Verify with `bootctl status`

**Deferred to V2:**
- ⏳ Secure Boot support
- ⏳ Custom boot splash
- ⏳ Advanced boot entry options
- ⏳ Multi-kernel support (linux, linux-lts, linux-zen)

## Testing

### Test Scenarios

**Test 1: Single-boot Arch**
1. Install systemd-boot
2. Create boot entries
3. Reboot
4. Verify boots to Arch with LUKS prompt

**Test 2: Dual-boot with Windows**
1. Windows already installed
2. Install Arch + systemd-boot
3. Reboot
4. Verify menu shows both Arch and Windows
5. Boot to Windows, verify works
6. Boot to Arch, verify LUKS unlocks

**Test 3: Fallback entry**
1. Boot system
2. Select fallback entry
3. Verify boots successfully

**Test 4: NVIDIA parameters**
1. System with NVIDIA GPU
2. Verify boot entry has nvidia_drm.modeset=1
3. Boot and check NVIDIA works
4. Verify Wayland available (if COSMIC)

**Test 5: Wrong UUID**
1. Edit boot entry, change UUID to invalid
2. Reboot
3. Should hang waiting for cryptroot
4. Verify error message is clear
5. Fix from rescue shell

## References

- [Arch Wiki: systemd-boot](https://wiki.archlinux.org/title/Systemd-boot)
- [Arch Wiki: Dual boot with Windows](https://wiki.archlinux.org/title/Dual_boot_with_Windows)
- [systemd-boot man page](https://www.freedesktop.org/software/systemd/man/systemd-boot.html)
- [bootctl man page](https://www.freedesktop.org/software/systemd/man/bootctl.html)
- [Boot loader specification](https://systemd.io/BOOT_LOADER_SPECIFICATION/)
