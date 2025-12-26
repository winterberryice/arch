# LUKS Encryption Setup

## Overview

This document describes the LUKS (Linux Unified Key Setup) encryption setup workflow for the Arch Linux installer. LUKS provides full-disk encryption, protecting all user data at rest.

## Design Goals

- ✅ Secure password handling (no plaintext logging)
- ✅ User-friendly password prompts with confirmation
- ✅ Strong encryption defaults (AES-256, XTS mode)
- ✅ Proper initramfs configuration (encrypt hook)
- ✅ Clear error messages and recovery guidance
- ✅ LUKS header backup option
- ✅ Support for both interactive and automated setups

## LUKS Basics

### What Gets Encrypted

**Encrypted (inside LUKS container):**
- ✅ Root filesystem (/)
- ✅ /home (all user data)
- ✅ /var (system data, logs)
- ✅ Swap (if using swapfile inside BTRFS)

**NOT Encrypted (requirements):**
- ❌ /boot (kernels, initramfs) - systemd-boot can't unlock LUKS
- ❌ EFI partition - UEFI firmware requirement

### How LUKS Works

```
Boot sequence:
1. UEFI loads systemd-boot from ESP (unencrypted)
2. systemd-boot loads kernel + initramfs from /boot (unencrypted)
3. Kernel boots, runs initramfs
4. initramfs prompts for LUKS password
5. cryptsetup unlocks LUKS partition → /dev/mapper/cryptroot
6. Mount BTRFS filesystem from /dev/mapper/cryptroot
7. Switch to real root, continue boot
```

### LUKS Versions

**LUKS2 (Default, Recommended):**
- Modern format (since cryptsetup 2.0)
- Better header protection
- Support for Argon2 key derivation (more secure)
- Arch Linux default

**LUKS1 (Legacy):**
- Older format
- Wider compatibility (GRUB can boot from LUKS1 /boot)
- We don't need this (systemd-boot can't use it anyway)

**V1 Decision:** Use LUKS2 with defaults

## Password Requirements

### Security Considerations

**Minimum requirements:**
- 12+ characters recommended
- Mix of uppercase, lowercase, numbers, symbols
- No dictionary words
- Not reused from other systems

**Trade-offs:**
- Stronger password = Better security
- But: You'll type it EVERY BOOT
- Forgotten password = **Permanent data loss** (no recovery!)

### Password Strength Validation

**V1 Approach: Warn but allow**
- Check length (warn if < 12 characters)
- Don't enforce complexity (user may have good reasons)
- Display strength estimate
- Require explicit confirmation for weak passwords

**V2 Enhancement:**
- Optional: Integrate `pwquality` library
- Configurable strength requirements

## Password Handling Workflow

### Step 1: Initial Prompt

**Using gum:**
```bash
PASSWORD=$(gum input --password --placeholder "Enter LUKS encryption password")
```

**Security:**
- ✅ No echo (password hidden)
- ✅ Not logged to shell history
- ✅ Stored in memory only

### Step 2: Confirmation Prompt

```bash
PASSWORD_CONFIRM=$(gum input --password --placeholder "Confirm password")

if [[ "$PASSWORD" != "$PASSWORD_CONFIRM" ]]; then
    gum style --foreground 196 "❌ Passwords do not match!"
    exit 1
fi
```

### Step 3: Strength Check (Optional)

```bash
LENGTH=${#PASSWORD}

if [[ $LENGTH -lt 12 ]]; then
    gum style --foreground 208 "⚠️  Warning: Password is short ($LENGTH chars)"
    gum style "Recommendation: Use 12+ characters for better security"

    gum confirm "Continue with this password?" || exit 1
fi
```

### Step 4: Final Confirmation

```bash
gum style --border rounded --padding "1 2" "
LUKS Encryption Setup

⚠️  IMPORTANT:
• This password encrypts ALL your data
• You will need it EVERY time you boot
• If you forget it, your data is LOST FOREVER
• No recovery method exists

Make sure you:
✓ Remember this password
✓ Can type it correctly (check keyboard layout!)
✓ Won't forget it
"

gum confirm "Proceed with encryption?" || exit 1
```

## LUKS Container Creation

### cryptsetup Command

**Basic LUKS2 format:**
```bash
echo -n "$PASSWORD" | cryptsetup luksFormat --type luks2 /dev/nvme0n1p4 -
```

**With explicit options (verbose):**
```bash
echo -n "$PASSWORD" | cryptsetup luksFormat \
    --type luks2 \
    --cipher aes-xts-plain64 \
    --key-size 512 \
    --hash sha256 \
    --iter-time 2000 \
    --use-random \
    /dev/nvme0n1p4 -
```

**Parameters explained:**
- `--type luks2` - Use LUKS2 format
- `--cipher aes-xts-plain64` - AES encryption in XTS mode (default, secure)
- `--key-size 512` - 512-bit key (AES-256 in XTS mode, default)
- `--hash sha256` - SHA-256 for key hashing (default)
- `--iter-time 2000` - 2 seconds of PBKDF iterations (default, slows brute force)
- `--use-random` - Use /dev/random for key material (most secure)
- `-` - Read password from stdin (for scripting)

**V1 Decision:** Use defaults (just `--type luks2`), they're already secure

### Progress Indication

```bash
gum spin --spinner dot --title "Creating LUKS container..." -- \
    bash -c "echo -n '$PASSWORD' | cryptsetup luksFormat --type luks2 $PARTITION -"
```

### Error Handling

**Possible errors:**
1. **Partition in use:** Can't format mounted partition
2. **Insufficient permissions:** Need root
3. **Invalid partition:** Doesn't exist or wrong type

**Error handling:**
```bash
if ! echo -n "$PASSWORD" | cryptsetup luksFormat --type luks2 "$PARTITION" - 2>/dev/null; then
    ERROR_MSG=$(echo -n "$PASSWORD" | cryptsetup luksFormat --type luks2 "$PARTITION" - 2>&1)

    gum style --foreground 196 "❌ LUKS creation failed!"
    gum style "$ERROR_MSG"

    if echo "$ERROR_MSG" | grep -q "Device or resource busy"; then
        gum style "Partition may be mounted. Unmount it first."
    fi

    exit 1
fi
```

## Opening LUKS Container

### Open for Installation

**After creating LUKS, open it:**
```bash
echo -n "$PASSWORD" | cryptsetup open /dev/nvme0n1p4 cryptroot -
```

**This creates:** `/dev/mapper/cryptroot`

**Device mapper name:**
- `cryptroot` is the name we choose
- Accessible as `/dev/mapper/cryptroot`
- Used in fstab, boot params

**Alternative names:**
- Some use `luks-UUID` (auto-generated)
- We use `cryptroot` (simple, consistent)

### Verify Open

```bash
if [[ ! -b /dev/mapper/cryptroot ]]; then
    gum style --foreground 196 "❌ Failed to open LUKS container"
    exit 1
fi

gum style --foreground 2 "✅ LUKS container unlocked: /dev/mapper/cryptroot"
```

## LUKS in /etc/crypttab

### What is crypttab?

**File:** `/etc/crypttab`
**Purpose:** Configure encrypted devices to unlock at boot
**Loaded by:** systemd (systemd-cryptsetup)

### Our Configuration

**For systemd-boot + LUKS:**

**We DON'T use /etc/crypttab for root partition!**
- Root unlock handled by `encrypt` hook in initramfs
- Kernel parameter specifies root LUKS device
- crypttab is for *additional* encrypted devices (like /home on separate partition)

**Example /etc/crypttab (if using separate /home LUKS):**
```
# <name>    <device>                              <password>  <options>
home        UUID=xxxx-xxxx-xxxx-xxxx              none        luks
```

**For our single LUKS setup:**
- `/etc/crypttab` can be empty or non-existent
- Root LUKS unlock via kernel params + encrypt hook

## initramfs Configuration (Critical!)

### /etc/mkinitcpio.conf

**This is THE MOST CRITICAL file for LUKS boot!**

**Must add hooks:**
```
HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)
```

**Key hooks explained:**

**`keyboard`** - Essential!
- Loads keyboard drivers
- Needed to type LUKS password at boot
- MUST come before `encrypt`

**`keymap`** - Important for non-US keyboards
- Loads your keyboard layout
- Without this: US layout at boot (can't type password if you have special chars!)
- Load early so password prompt uses correct layout

**`consolefont`** - Optional but recommended
- Loads console font
- Better readability for password prompt

**`encrypt`** - THE LUKS UNLOCK HOOK
- Prompts for LUKS password
- Unlocks encrypted root
- Creates /dev/mapper/cryptroot
- **MUST come after keyboard/keymap, before filesystems**

**Hook order matters:**
1. `base`, `udev` - Essentials
2. `keyboard`, `keymap` - Input devices FIRST
3. `encrypt` - Unlock using keyboard
4. `filesystems` - Mount unlocked filesystems

### NVIDIA Systems (Reminder)

**If NVIDIA GPU detected, ALSO add modules:**
```
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)
```

### Rebuild initramfs

**After editing /etc/mkinitcpio.conf:**
```bash
mkinitcpio -P
```

**This generates:**
- `/boot/initramfs-linux.img` - Main initramfs
- `/boot/initramfs-linux-fallback.img` - Fallback (all modules)

**Failure to rebuild = UNBOOTABLE SYSTEM!**

## Kernel Parameters (systemd-boot)

### Required Parameters

**Boot entry must include:**
```
options cryptdevice=UUID=<LUKS-UUID>:cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw
```

**Breakdown:**

**`cryptdevice=UUID=<UUID>:cryptroot`**
- Tells `encrypt` hook which device to unlock
- `UUID=xxx` - LUKS partition UUID (from `blkid`)
- `:cryptroot` - Device mapper name (becomes /dev/mapper/cryptroot)

**`root=/dev/mapper/cryptroot`**
- Where actual root filesystem is
- After unlocking LUKS

**`rootflags=subvol=@`**
- BTRFS subvolume to mount as root
- Our root is in `@` subvolume

### Getting LUKS UUID

**Method 1: blkid**
```bash
LUKS_UUID=$(blkid -s UUID -o value /dev/nvme0n1p4)
echo "cryptdevice=UUID=$LUKS_UUID:cryptroot"
```

**Method 2: lsblk**
```bash
lsblk -o NAME,UUID /dev/nvme0n1p4
```

**UUID vs Device Path:**
- ✅ Use UUID (persistent across reboots, disk changes)
- ❌ Avoid `/dev/nvme0n1p4` (can change with hardware changes)

## LUKS Header Backup

### Why Backup?

**LUKS header contains:**
- Encryption metadata
- Key slots (encrypted master key)
- **If header corrupts = DATA LOST FOREVER**

**Common corruption causes:**
- Disk errors
- Accidental overwrite (reinstalling bootloader, etc.)
- Filesystem corruption

### Creating Backup

**Backup command:**
```bash
cryptsetup luksHeaderBackup /dev/nvme0n1p4 --header-backup-file /root/luks-header-backup.img
```

**Store backup:**
- Save to USB drive (external)
- Or: Print key slot info and store separately
- **Never store on encrypted drive itself!**

### V1 Decision

**Offer header backup after installation:**
```bash
gum confirm "Create LUKS header backup? (Recommended)" && {
    cryptsetup luksHeaderBackup "$LUKS_PARTITION" \
        --header-backup-file "/root/luks-header-$(date +%F).img"

    gum style --foreground 2 "
    ✅ Header backup created: /root/luks-header-$(date +%F).img

    ⚠️  IMPORTANT: Copy this file to external storage!
    This backup can recover your data if LUKS header corrupts.
    "
}
```

### Restoring Header

**If header corrupts:**
```bash
cryptsetup luksHeaderRestore /dev/nvme0n1p4 --header-backup-file /root/luks-header-backup.img
```

## Key Slots (Advanced)

### What are Key Slots?

**LUKS supports 8 key slots (LUKS2: 32 slots)**
- Each slot can have different password
- All unlock the same master key
- Master key encrypts the data
- Useful for:
  - Multiple users
  - Password changes (add new, remove old)
  - Recovery keys

### V1 Approach

**Single password in slot 0** (default)
- Simple, sufficient for single-user
- Can add more keys later if needed

### V2 Enhancements

**Multiple key slots:**
- Add recovery password (slot 1)
- Add keyfile for auto-unlock (slot 2)
- TPM2-sealed key (slot 3)

**Commands:**
```bash
# Add new password
cryptsetup luksAddKey /dev/nvme0n1p4

# Remove key slot
cryptsetup luksKillSlot /dev/nvme0n1p4 1

# Change password (add new, remove old)
cryptsetup luksChangeKey /dev/nvme0n1p4
```

## Installation Workflow

### Complete LUKS Setup Steps

**Phase 1: During partitioning (pre-install.sh)**

```
1. User selects partition for LUKS
2. Prompt for LUKS password (with confirmation)
3. Validate password strength (warn if weak)
4. Create LUKS container: cryptsetup luksFormat
5. Open LUKS container: cryptsetup open → /dev/mapper/cryptroot
6. Create BTRFS on /dev/mapper/cryptroot
7. Continue with installation...
```

**Phase 2: During chroot configuration (install.sh)**

```
1. Edit /etc/mkinitcpio.conf:
   - Add keyboard, keymap, encrypt hooks
   - Add NVIDIA modules if needed
2. Rebuild initramfs: mkinitcpio -P
3. Get LUKS UUID: blkid
4. Create systemd-boot entry with cryptdevice= parameter
5. Optional: Create LUKS header backup
```

## Password Prompt at Boot

### What User Sees

```
A password is required to access the cryptroot volume:
Enter passphrase for /dev/nvme0n1p4:
```

**Input:**
- No echo (password hidden)
- Uses keyboard layout from keymap hook
- Caps Lock indicator (if enabled)

**On success:**
- Unlocks LUKS
- Mounts BTRFS
- Continues boot

**On failure:**
- Shows error
- Prompts again (3 attempts)
- Drops to rescue shell after 3 failures

## Error Scenarios & Recovery

### 1. Wrong Password at Boot

**Symptom:** "No key available with this passphrase"

**Recovery:**
1. Try again (check Caps Lock, keyboard layout)
2. After 3 failures → rescue shell
3. From rescue: `cryptsetup open /dev/nvme0n1p4 cryptroot`
4. If still failing → boot from USB, unlock manually

### 2. Missing encrypt Hook

**Symptom:** "Waiting for /dev/mapper/cryptroot" → timeout

**Recovery:**
1. Boot from Arch USB
2. Unlock LUKS manually:
   ```bash
   cryptsetup open /dev/nvme0n1p4 cryptroot
   mount -o subvol=@ /dev/mapper/cryptroot /mnt
   mount /dev/nvme0n1p1 /mnt/boot
   arch-chroot /mnt
   ```
3. Fix /etc/mkinitcpio.conf (add encrypt hook)
4. Rebuild: `mkinitcpio -P`
5. Reboot

### 3. Wrong cryptdevice= Parameter

**Symptom:** Boot hangs, can't find LUKS device

**Recovery:**
1. Boot from USB
2. Check correct UUID: `blkid /dev/nvme0n1p4`
3. Mount and chroot (see above)
4. Edit `/boot/loader/entries/arch.conf`
5. Fix `cryptdevice=UUID=...` parameter
6. Reboot

### 4. Keyboard Layout Wrong

**Symptom:** Can type password on live USB but not at boot prompt

**Recovery:**
1. Boot from USB
2. Mount and chroot
3. Check `/etc/vconsole.conf` (should have KEYMAP=)
4. Ensure `keymap` hook in /etc/mkinitcpio.conf
5. Rebuild: `mkinitcpio -P`

### 5. Forgotten Password

**Symptom:** Can't remember LUKS password

**Recovery:** **NONE. Data is lost.**

**Options:**
- If you have LUKS header backup with known password → restore header
- If you added multiple key slots → try other passwords
- Otherwise: Data is permanently encrypted, no recovery possible

**This is by design!** Encryption that can be bypassed isn't encryption.

## Testing Strategy

### Test Scenarios

**Test 1: Basic LUKS setup**
1. Create LUKS on test partition
2. Open, format BTRFS, close
3. Reopen with same password
4. Verify can access filesystem

**Test 2: Wrong password**
1. Try to open with wrong password
2. Should fail with clear error
3. Try with correct password
4. Should succeed

**Test 3: Boot with LUKS**
1. Install system with LUKS
2. Reboot
3. Enter password at prompt
4. System should boot normally

**Test 4: Wrong password at boot**
1. Enter wrong password
2. Should retry
3. After 3 attempts, rescue shell
4. Verify can unlock from rescue shell

**Test 5: Recovery from USB**
1. Boot from Arch USB
2. Manually unlock LUKS
3. Mount and chroot
4. Verify can access system

## Security Best Practices

### DO:
- ✅ Use strong, unique password
- ✅ Store LUKS header backup externally
- ✅ Test password before rebooting!
- ✅ Use UUID for cryptdevice parameter
- ✅ Include keyboard + keymap hooks

### DON'T:
- ❌ Store password in scripts/logs
- ❌ Reuse passwords from other systems
- ❌ Skip header backup
- ❌ Store header backup on encrypted drive
- ❌ Use weak password for convenience

## V1 Implementation Summary

**Features:**
- ✅ Interactive password prompt (gum)
- ✅ Password confirmation
- ✅ Basic strength warning
- ✅ LUKS2 with secure defaults
- ✅ Proper initramfs hooks
- ✅ UUID-based boot parameters
- ✅ Clear error messages
- ✅ Optional header backup

**Deferred to V2:**
- ⏳ Multiple key slots
- ⏳ Keyfile for auto-unlock
- ⏳ TPM2 integration
- ⏳ Password strength enforcement (pwquality)
- ⏳ Encrypted /boot with GRUB

## References

- [Arch Wiki: dm-crypt](https://wiki.archlinux.org/title/Dm-crypt)
- [Arch Wiki: dm-crypt/Encrypting an entire system](https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system)
- [Arch Wiki: dm-crypt/Device encryption](https://wiki.archlinux.org/title/Dm-crypt/Device_encryption)
- [cryptsetup FAQ](https://gitlab.com/cryptsetup/cryptsetup/-/wikis/FrequentlyAskedQuestions)
- [LUKS specification](https://gitlab.com/cryptsetup/LUKS2-docs)
