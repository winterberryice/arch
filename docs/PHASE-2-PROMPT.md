# Phase 2 Implementation Prompt

Use this prompt to start a new session for Phase 2 implementation.

---

## Context: Phase 1 Complete ✅

I have an Arch Linux installer (omarchy fork) with **Phase 1 complete and tested**.

### Phase 1 Achievements (COMPLETE ✅)

**What works:**
- ✅ Interactive installation with gum TUI
- ✅ User-chosen credentials (username, passwords, hostname, timezone)
- ✅ Interactive disk selection with safety prompts
- ✅ Multi-disk detection and selection menu
- ✅ Warnings for mounted disks, existing filesystems, existing OS
- ✅ "YES" confirmation required before disk wipe
- ✅ BTRFS filesystem with subvolumes (@, @home, @snapshots, @var_log, @swap)
- ✅ systemd-boot bootloader with PARTUUID-based root identification
- ✅ Hardware auto-detection (AMD/Intel CPU, AMD/NVIDIA/Intel GPU)
- ✅ Full COSMIC desktop environment (24 packages)
- ✅ PipeWire audio stack
- ✅ Security hardening (ufw firewall, SSH hardening, secure permissions)
- ✅ Tested in QEMU - fully working
- ✅ Clean, formatted output
- ✅ Modular architecture (install/lib/, install/phases/)

**Current behavior:**
- ✅ Interactive configuration prompts
- ✅ User selects which disk to wipe (whole disk wipe)
- ✅ Safety confirmations before destructive operations
- ✅ Secure by default (firewall, no root SSH, proper permissions)

### Architecture Overview

```
arch/
├── install/
│   ├── install.sh              # Main orchestrator with interactive config
│   ├── lib/
│   │   ├── common.sh          # Error handling, logging, state (no hardcoded config)
│   │   ├── hardware.sh        # CPU/GPU detection
│   │   └── ui.sh              # Interactive prompts (gum), disk selection
│   └── phases/
│       ├── 01-prepare.sh      # Requirements, mirrors, hardware detection
│       ├── 02-partition.sh    # Interactive disk selection + partitioning
│       ├── 03-btrfs.sh        # BTRFS subvolumes and mounting
│       ├── 04-install.sh      # pacstrap base system + COSMIC
│       ├── 05-configure.sh    # System config (chroot: timezone, locale, users)
│       ├── 06-bootloader.sh   # systemd-boot installation (chroot)
│       └── 07-finalize.sh     # Swapfile, security hardening (chroot)
├── test/
│   └── qemu-test.sh           # QEMU testing helper (30GB disk, Phase 1 branch)
├── docs/
│   ├── PHASE-0-COMPLETE.md    # Phase 0 summary
│   ├── PHASE-1-COMPLETE.md    # Phase 1 summary and test results
│   └── [planning docs]        # Architecture planning
└── README.md
```

**Current partitioning scheme:**
- GPT partition table
- 512MB EFI partition (FAT32)
- Remaining space for BTRFS root partition
- **Wipes entire selected disk**

---

## Phase 2 Goal: Advanced Features and Flexibility

**Primary objective:** Add advanced installation features while maintaining the simplicity and safety of Phase 1.

### Phase 2 Feature Options (Pick 2-3 to start)

You can choose which features to prioritize for Phase 2. Here are the top candidates:

---

### Feature Option A: LUKS Full Disk Encryption ⭐ HIGH VALUE

**User benefit:** Secure data at rest, essential for laptops and sensitive data

**What to implement:**
- Prompt user if they want encryption (default: yes for laptops, optional for desktops)
- Password prompt for LUKS (with strength validation)
- Optional keyfile support
- Encrypt BTRFS partition (EFI remains unencrypted)
- Update bootloader to handle encrypted root
- Update fstab and crypttab
- Test unlock on boot

**Technical changes needed:**
- `02-partition.sh`: Add LUKS container creation
- `03-btrfs.sh`: Format LUKS container, then create BTRFS on it
- `06-bootloader.sh`: Add kernel parameters for cryptdevice
- `05-configure.sh`: Generate /etc/crypttab

**Acceptance criteria:**
- ✅ User can choose to encrypt installation
- ✅ Strong password required for encryption
- ✅ System boots and prompts for unlock password
- ✅ BTRFS works normally on encrypted volume
- ✅ Swap is also encrypted

---

### Feature Option B: Partition-Level Installation ⭐ HIGH VALUE

**User benefit:** Install alongside existing OS, use free space, preserve data

**What to implement:**
- List all partitions on selected disk (not just disks)
- Show partition details (size, type, filesystem, mount status)
- Allow selecting specific partition to replace
- Detect and calculate free space on disk
- Option to install in free space (create new partitions)
- Option to shrink existing partition (advanced)
- Preserve existing EFI partition for dual-boot

**Technical changes needed:**
- `install/lib/ui.sh`: Add partition selection functions
- `02-partition.sh`: Support partition mode vs whole disk mode
- `02-partition.sh`: Free space detection and partition creation
- `06-bootloader.sh`: Detect and use existing EFI partition
- Add Windows detection and bootloader entry preservation

**Acceptance criteria:**
- ✅ User can choose whole disk or partition mode
- ✅ User can select specific partition to replace
- ✅ User can install to free space
- ✅ Existing EFI partition is preserved and used
- ✅ Existing OS bootloader entries preserved
- ✅ No data loss on unselected partitions

---

### Feature Option C: Desktop Environment Selection

**User benefit:** Choose DE during installation, not locked to COSMIC

**What to implement:**
- Menu to select desktop environment:
  - COSMIC (default, current)
  - GNOME
  - KDE Plasma
  - Xfce
  - i3 / Sway (tiling WM)
  - Minimal (no DE, just base system)
- Package list based on selection
- Display manager selection (GDM, SDDM, LightDM, or none)
- DE-specific configuration

**Technical changes needed:**
- `install/lib/ui.sh`: Add DE selection prompt
- `04-install.sh`: Conditional package installation based on choice
- `05-configure.sh`: Enable appropriate display manager

**Acceptance criteria:**
- ✅ User can choose DE from menu
- ✅ Selected DE installs correctly
- ✅ Display manager configured for chosen DE
- ✅ System boots to chosen DE

---

### Feature Option D: Locale and Keyboard Improvements

**User benefit:** Proper locale and keyboard setup for non-US users

**What to implement:**
- Locale selection menu (search/filter list)
- Multiple locale support (generate several)
- Keyboard layout selection (qwerty, azerty, dvorak, etc.)
- Console font selection
- Timezone auto-detection based on IP (with override)

**Technical changes needed:**
- `install/lib/ui.sh`: Locale picker, keyboard layout picker
- `05-configure.sh`: Generate multiple locales, set keyboard in vconsole.conf

**Acceptance criteria:**
- ✅ User can search and select locale
- ✅ User can select keyboard layout
- ✅ Console keyboard works correctly
- ✅ X11/Wayland keyboard configured

---

### Feature Option E: Advanced BTRFS Options

**User benefit:** Customize subvolume layout, compression, snapshots

**What to implement:**
- Compression algorithm choice (zstd:1, zstd:3, lzo, none)
- Custom subvolume layout
- Automatic snapper setup and configuration
- Pre/post-install snapshots
- Snapshot retention policies

**Technical changes needed:**
- `install/lib/ui.sh`: BTRFS options menu
- `03-btrfs.sh`: Custom subvolume creation, compression level
- `07-finalize.sh`: Snapper auto-config (install and configure)

**Acceptance criteria:**
- ✅ User can choose compression level
- ✅ User can customize subvolumes
- ✅ Snapper configured automatically
- ✅ Initial snapshots created
- ✅ Rollback tested

---

### Feature Option F: Post-Install Customization

**User benefit:** Personalize installation without manual setup

**What to implement:**
- Optional AUR helper installation (yay, paru)
- Dotfiles repository cloning
- Additional package selection (browser, terminal, editor)
- User profile picture selection
- Wallpaper download/selection
- Oh-my-zsh or fish shell setup

**Technical changes needed:**
- New phase: `08-customize.sh`
- `install/lib/ui.sh`: Customization prompts

**Acceptance criteria:**
- ✅ User can choose AUR helper
- ✅ User can provide dotfiles repo URL
- ✅ User can select additional packages
- ✅ Customizations applied before first boot

---

## Phase 2 Implementation Strategy

### Recommended Approach

**Start with 2-3 features maximum** to keep Phase 2 manageable:

**My recommendations for Phase 2 priorities:**

1. **Option A: LUKS Encryption** (most requested, high security value)
2. **Option B: Partition-Level Installation** (enables dual-boot, preserves data)
3. **Option C: Desktop Environment Selection** (flexibility, wider audience)

OR

1. **Option B: Partition-Level Installation** (you mentioned this in planning docs)
2. **Option A: LUKS Encryption** (high value)
3. **Option D: Locale/Keyboard** (international users)

**Defer to Phase 3:**
- Advanced BTRFS options
- Post-install customization
- Additional DEs beyond 3-4 main ones

---

## Phase 2 Technical Considerations

### Maintain Phase 1 Quality

**Keep these Phase 1 features:**
- ✅ Interactive prompts with validation
- ✅ Safety confirmations
- ✅ Clear warnings
- ✅ Security hardening
- ✅ Clean modular code
- ✅ Good error handling

### Add New Capabilities

**Without breaking:**
- Simple installation flow (don't overcomplicate)
- QEMU testing compatibility
- Error recovery
- Logging

### Testing Requirements

**Phase 2 must be tested:**
- ✅ In QEMU (basic flow still works)
- ✅ With encryption (if implementing LUKS)
- ✅ With partition selection (if implementing)
- ✅ On real hardware (ultimate validation)

---

## Phase 2 Acceptance Criteria

Choose based on which features you implement. Examples:

### If implementing LUKS (Option A):
- ✅ User can enable/disable encryption
- ✅ Encryption password validated (min 12 chars, confirmation)
- ✅ BTRFS created on encrypted volume
- ✅ Bootloader configured for encrypted root
- ✅ System boots and prompts for password
- ✅ Unlock works, system boots normally
- ✅ Swap encrypted
- ✅ Performance acceptable

### If implementing Partition Selection (Option B):
- ✅ User can choose whole disk or partition mode
- ✅ Partition list shown with details
- ✅ Free space detected and displayed
- ✅ Existing partitions preserved
- ✅ EFI partition reused if exists
- ✅ Windows bootloader entries preserved
- ✅ Dual-boot works

### If implementing DE Selection (Option C):
- ✅ DE menu with 4+ options
- ✅ COSMIC, GNOME, KDE Plasma work
- ✅ Display manager auto-configured
- ✅ All DEs boot successfully
- ✅ Basic functionality tested

---

## Phase 2 File Structure

Potential new files/changes:

```
install/
├── lib/
│   ├── encryption.sh    # LUKS functions (if implementing)
│   └── partition.sh     # Partition detection functions (if implementing)
└── phases/
    ├── 02-partition.sh  # Modified for partition mode / LUKS
    ├── 03-btrfs.sh      # Modified for encrypted volume
    ├── 04-install.sh    # Modified for DE selection
    └── 08-customize.sh  # New phase for post-install (optional)
```

---

## Key Files Reference (Phase 1 - Current State)

**Configuration management:**
- `install/lib/common.sh` - Config via environment variables, state management
- `install/lib/ui.sh` - Interactive prompts (gum), disk selection, validation
- `install/lib/hardware.sh` - Hardware detection (CPU, GPU)

**Installation phases:**
- `install/install.sh` - Calls configure_installation() before phases
- `install/phases/02-partition.sh` - Interactive disk selection + GPT + BTRFS format
- `install/phases/03-btrfs.sh` - Subvolume creation and mounting
- `install/phases/04-install.sh` - pacstrap with COSMIC
- `install/phases/05-configure.sh` - System config in chroot
- `install/phases/06-bootloader.sh` - systemd-boot installation
- `install/phases/07-finalize.sh` - Swapfile + security hardening

**Testing:**
- `test/qemu-test.sh` - QEMU helper (branch: claude/phase-1-implementation-9YKnp)

---

## Starting Point for Phase 2

**When you start Phase 2, begin with:**

1. **Decide which features to implement** (recommend 2-3 from options above)

2. **Read current codebase** to understand Phase 1 implementation:
   - `install/install.sh` - Main flow
   - `install/lib/ui.sh` - Interactive prompts patterns
   - `install/phases/02-partition.sh` - Current disk handling
   - `install/phases/03-btrfs.sh` - Current BTRFS setup

3. **Plan the implementation:**
   - What prompts to add
   - What validation needed
   - Where to modify existing code
   - What new functions/files needed

4. **Implement incrementally:**
   - Add prompts first
   - Test prompt flow
   - Add functionality
   - Test in QEMU
   - Fix bugs
   - Document

5. **Test thoroughly:**
   - QEMU test after each feature
   - Real hardware test when stable

---

## Questions to Ask Me (Phase 2)

When starting Phase 2, you should ask:

1. **Feature selection:**
   - "Which 2-3 features from the options should I prioritize?"
   - "Do you want LUKS encryption, partition selection, or DE choice first?"

2. **UX decisions:**
   - "Should encryption be opt-in or opt-out?"
   - "Should we support resizing partitions or only use existing/free space?"
   - "How many desktop environments should we support initially?"

3. **Technical decisions:**
   - "Should LUKS use default cipher (aes-xts-plain64) or offer choices?"
   - "Should we auto-detect existing EFI or always ask?"
   - "Should we support LVM on LUKS or just LUKS on partition?"

4. **Scope control:**
   - "Should we keep Phase 2 simple (2 features) or ambitious (3-4 features)?"
   - "What should be deferred to Phase 3?"

---

## Phase 2 Success Metrics

**Phase 2 is successful when:**

- ✅ Chosen features implemented and working
- ✅ Phase 1 simplicity and safety maintained
- ✅ Installation still completes in <15 minutes
- ✅ QEMU tested and validated
- ✅ Real hardware tested (for critical features)
- ✅ Code remains clean and modular
- ✅ Documentation updated
- ✅ No regressions from Phase 1

---

## Recommendations for Phase 2

**Based on your planning docs mentioning "free space" installation:**

### Recommended Phase 2 Feature Set:

**Priority 1: Partition-Level Installation (Option B)**
- Enables dual-boot
- Allows installing alongside Windows/other Linux
- Uses free space without wiping disk
- High user value

**Priority 2: LUKS Encryption (Option A)**
- Essential for security
- Many users want this
- Not too complex to implement

**Priority 3: Desktop Environment Selection (Option C)** OR **Locale/Keyboard (Option D)**
- DE selection = wider audience
- Locale/Keyboard = better international support
- Your choice based on priorities

**Defer to Phase 3:**
- Advanced BTRFS options
- Post-install customization
- Additional DEs
- Snapper automation

---

## Let's Build Phase 2!

**When ready, ask me:**

1. Which features to prioritize (I recommend B + A + C or D)
2. Any specific requirements or constraints
3. Whether to maintain compatibility with Phase 1 simple mode

**Then:**

1. Read existing Phase 1 code
2. Plan implementation approach
3. Implement feature by feature
4. Test in QEMU after each feature
5. Validate on real hardware
6. Document and merge

---

## Current Branch

**Phase 1 branch:** `claude/phase-1-implementation-9YKnp` (complete, tested, working)

**For Phase 2:** Create new branch like `claude/phase-2-implementation-XXXXX`

---

## Documentation

**Phase 1 docs:**
- `docs/PHASE-0-COMPLETE.md` - Phase 0 results
- `docs/PHASE-1-COMPLETE.md` - Phase 1 results (all ✅)
- `docs/005-installation-flow.md` - Architecture
- `docs/006-implementation-strategy.md` - Planning

**Phase 2 docs to create:**
- `docs/PHASE-2-COMPLETE.md` - Phase 2 results (when done)
- Update `README.md` with Phase 2 features

---

**Ready to make this installer even more powerful! 🚀**

**Target:** Advanced features while maintaining Phase 1's simplicity and safety.
