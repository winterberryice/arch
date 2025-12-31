# Partitioning Strategy

## Overview

This document describes the partitioning approach for the Arch Linux installer, supporting flexible dual-boot scenarios with Windows and full-disk encryption via LUKS.

## Design Goals

- ✅ Support both Windows-first and Arch-first installation orders
- ✅ Work with existing partitions or create new ones
- ✅ Flexible free space selection
- ✅ Full LUKS encryption (except /boot)
- ✅ Simple TUI using `gum`
- ✅ Single Arch installation (no multi-distro in same LUKS container)

## Partitioning Modes

### Mode A: Create in Free Space (Recommended)
- Detect free/unallocated space on disk
- User selects from available free regions
- Create new partition(s) in selected space
- **Use case:** Clean install alongside Windows, dual-boot setups

### Mode B: Reformat Existing Partition
- Show existing partitions with warning
- User selects partition to reformat (DESTROYS DATA)
- Reformat selected partition as LUKS
- **Use case:** Replace old Linux install, reuse partition

## EFI System Partition (ESP) Strategy

### ESP Handling Rules

**When ESP exists (Windows or previous Linux):**
- Default: Use existing ESP (100-260MB typical for Windows 11)
- Option: Create new ESP (2GB) if existing is too small
- User confirms choice via `gum confirm`

**When ESP does NOT exist (fresh disk):**
- Automatically create 2GB ESP (type EF00, FAT32)
- Create as first partition for compatibility

**Critical:** ESP is NEVER inside LUKS (bootloader cannot unlock LUKS)

### ESP Partition Creation Matrix

| ESP Exists? | LUKS Method | Partitions to Create |
|-------------|-------------|---------------------|
| ✅ Yes | Free space | 1 (LUKS only) |
| ✅ Yes | Reformat existing | 0 (just reformat) |
| ❌ No | Free space | 2 (ESP + LUKS) |
| ❌ No | Reformat existing | 1 (ESP only) + reformat |

## Installation Order Scenarios

### Scenario A: Windows Installed First (Common)

**Typical layout:**
```
/dev/nvme0n1
├─ p1: EFI (100-260MB, FAT32)        [Created by Windows]
├─ p2: MSR (16MB)                     [Microsoft Reserved]
├─ p3: Windows (NTFS, ~500GB)         [Windows C:\]
└─ [Free space ~500GB]                [Available for Linux]
```

**User workflow:**
1. Shrink Windows partition in Windows Disk Management
2. Boot Arch installer
3. Installer detects free space
4. User selects free space region
5. Create LUKS partition in free space
6. Use existing Windows ESP

### Scenario B: Arch Installed First

**Initial state:**
```
/dev/nvme0n1
└─ [Free space 1TB]                   [Empty disk]
```

**Installer creates:**
```
/dev/nvme0n1
├─ p1: EFI (2GB, FAT32)               [Created by installer]
├─ p2: LUKS (500GB or remaining)      [Arch Linux]
└─ [Free space for Windows]           [Optional, user choice]
```

**Future Windows install:**
- Windows detects existing EFI partition
- Uses it (no conflict)
- Creates MSR and Windows partitions in free space

### Scenario C: Fresh Disk (Arch-only)

**Installer creates:**
```
/dev/nvme0n1
├─ p1: EFI (2GB, FAT32)
└─ p2: LUKS (remaining space)
```

## Partition Layout

### Final Partition Structure

**Standard dual-boot layout:**
```
p1: EFI (100MB-2GB, FAT32)           [Unencrypted, shared]
    Mounted at: /boot
    Contains: systemd-boot, kernels, initramfs

p2: MSR (16MB)                        [If Windows present]

p3: Windows (NTFS, variable size)     [If dual-boot]

p4: LUKS Container                    [Encrypted]
    Device mapper: /dev/mapper/cryptroot
    └─ BTRFS filesystem
       ├─ @ (root)                    → /
       ├─ @home                       → /home
       ├─ @snapshots                  → /.snapshots
       ├─ @var_log                    → /var/log
       └─ @swap                       → swapfile container
```

**Arch-only layout:**
```
p1: EFI (2GB, FAT32)                 [Unencrypted]
    Mounted at: /boot

p2: LUKS Container                    [Encrypted]
    └─ BTRFS (same subvolume structure)
```

## BTRFS Subvolume Strategy

### Single Arch Installation

**Subvolume naming:** Simple, no multi-distro prefixes

```
@           - Root filesystem (/)
@home       - User home directories (/home)
@snapshots  - Snapper snapshots (/.snapshots)
@var_log    - System logs (/var/log)
@swap       - Swapfile container (CoW disabled)
```

**Mount options:**
- `noatime` - Reduce write operations
- `compress=zstd` - Transparent compression
- `subvol=<name>` - Specific subvolume mount

**Why single Arch:**
- Simpler to manage and document
- Other distros can use separate LUKS partitions
- Avoids shared filesystem corruption risk

## Swap Strategy

**V1 Implementation:** zram + BTRFS swapfile (no hibernation)

### zram (Primary Swap)
- Compressed RAM swap
- Size: 4-8GB (configured in systemd)
- Zero disk I/O
- Fast, ~1000x faster than disk swap

### BTRFS Swapfile (Secondary/Backup)
- Subvolume: `@swap` (CoW disabled)
- Size: 8-16GB (or 1.5x RAM)
- Fallback when zram fills up
- Sets foundation for hibernation (V2)

### Swap Priority Chain
```
RAM (physical)
  ↓ (when full)
zram (compressed)
  ↓ (when zram full)
BTRFS swapfile (disk)
```

**Hibernation:** Deferred to V2 (complex with BTRFS + LUKS)

## TUI Implementation

### Tool: gum

**Why gum:**
- ✅ Modern, beautiful terminal UI
- ✅ Simple commands (`gum choose`, `gum confirm`)
- ✅ Easy integration with bash
- ✅ Better UX than dialog/whiptail

**Installation:** Script installs as dependency
```bash
pacman -Sy --noconfirm gum
```

### User Flow

**Step 1: Disk Selection**
```
Select disk:
> nvme0n1 (1TB NVMe)
  sda (500GB SSD)
```

**Step 2: Current Layout Display**
```
Current layout: /dev/nvme0n1
├─ nvme0n1p1  100MB   EFI
├─ nvme0n1p2  16MB    Microsoft Reserved
├─ nvme0n1p3  500GB   Windows (NTFS)
└─ FREE       500GB   Unallocated

ESP detected: /dev/nvme0n1p1 (100MB)
Free space: 500GB available
```

**Step 3: Partition Method**
```
Select partition method:
> Create in free space
  Use existing partition (DESTROYS DATA)
```

**Step 4a: Free Space Selection** (if multiple regions)
```
Select free space:
> Region 1: 500GB (after nvme0n1p3)
  Region 2: 50GB (after nvme0n1p1)
```

**Step 4b: Existing Partition Selection** (if reformat mode)
```
⚠️  WARNING: Will erase all data!

Select partition to reformat:
> /dev/sda3 (500GB, ext4)
  /dev/sda4 (200GB, ntfs)
```

**Step 5: ESP Handling**
```
Existing ESP found: /dev/nvme0n1p1 (100MB)

Use existing ESP?
> Yes
  No (create new 2GB ESP)
```

**Step 6: Confirmation**
```
Confirm partitioning plan:
• ESP: Use existing /dev/nvme0n1p1
• LUKS: Create in 500GB free space

Actions:
1. Create partition 4 (500GB, type 8309)
2. Format as LUKS (will ask for password)
3. Create BTRFS inside LUKS
4. Create subvolumes: @, @home, @snapshots, @var_log, @swap

⚠️  This will modify partition table

Proceed? [Yes] [No]
```

## Partitioning Tools

### Detection
- `lsblk` - List block devices
- `parted -l` - Partition table info
- `parted print free` - Show free space regions
- `blkid` - UUID and filesystem type detection

### Creation
- `sgdisk` - Scriptable GPT partitioning (recommended)
- `parted` - Alternative, works with both MBR/GPT
- `mkfs.fat -F32` - Format ESP as FAT32
- `cryptsetup luksFormat` - Create LUKS container
- `mkfs.btrfs` - Create BTRFS filesystem

### Validation
- Check partition type (ESP: EF00, LUKS: 8309)
- Verify EFI partition is FAT32
- Confirm LUKS unlock works
- Validate BTRFS mountable

## Security Considerations

### What's Encrypted
- ✅ Root filesystem (/)
- ✅ /home (all user data)
- ✅ /var (logs, system data)
- ✅ Swap (inside LUKS)

### What's NOT Encrypted
- ❌ /boot (kernels, initramfs) - systemd-boot requirement
- ❌ EFI partition - UEFI firmware requirement

### Threat Model

**Protected against:**
- ✅ Laptop theft (data unrecoverable without password)
- ✅ Disk disposal (old drives safe to discard)
- ✅ Physical access to powered-off system

**NOT protected against:**
- ❌ Evil maid attack (boot tampering possible)
- ❌ Runtime attacks (system unlocked when running)
- ❌ Keyloggers, malware, physical access when running

**Trade-off:** Unencrypted /boot for simplicity vs. GRUB encrypted /boot for maximum security. V1 chooses simplicity.

## Edge Cases & Troubleshooting

### Multiple Free Space Regions
- Show all regions with sizes
- User selects preferred region
- Common with complex Windows setups (recovery partitions)

### Tiny Windows ESP (100MB)
- Windows 10 often creates 100MB ESP (too small for comfort)
- Windows 11 usually creates 260MB (workable)
- Options:
  1. Use existing (manage kernel cleanup carefully)
  2. Create new 2GB ESP (advanced users)
- V1: Use existing, implement kernel cleanup

### No Free Space Available
- Error: No free space detected
- Suggest: Shrink existing partition first
- Point to Windows Disk Management or GParted Live

### Existing Linux Installation
- Warn user if Linux partitions detected
- Confirm: Reformat or create new partition?
- Offer: Import existing ESP

## V2 Future Enhancements

**Planned for later:**
- ⏳ Hibernation support (swapfile offset calculation)
- ⏳ Automatic partition resizing (shrink Windows from Linux)
- ⏳ Multi-distro support (multiple LUKS containers)
- ⏳ LVM on LUKS (alternative to BTRFS)
- ⏳ Encrypted /boot with GRUB
- ⏳ TPM2 auto-unlock

## References

- [Arch Wiki: Partitioning](https://wiki.archlinux.org/title/Partitioning)
- [Arch Wiki: LUKS](https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system)
- [Arch Wiki: BTRFS](https://wiki.archlinux.org/title/Btrfs)
- [Arch Wiki: Dual boot with Windows](https://wiki.archlinux.org/title/Dual_boot_with_Windows)
- [systemd-boot documentation](https://wiki.archlinux.org/title/Systemd-boot)
