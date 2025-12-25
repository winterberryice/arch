# GPU Detection & Driver Installation

## Overview

This document describes the GPU detection strategy and driver installation logic for the Arch Linux installer. The system must automatically detect GPU hardware and install appropriate drivers for AMD, NVIDIA, and Intel GPUs, including hybrid configurations.

## Design Goals

- ✅ Automatic GPU detection (no user input required)
- ✅ Support AMD, NVIDIA, and Intel GPUs
- ✅ Handle hybrid GPU systems (integrated + discrete)
- ✅ Flexible: work on current AMD system and future NVIDIA systems
- ✅ Minimal package installation (only what's needed)
- ✅ Proper kernel parameter configuration
- ✅ Microcode detection and installation (AMD vs Intel CPU)

## GPU Vendors & Driver Strategy

### AMD GPUs

**Open Source Drivers (Default)**
- Modern AMD GPUs use `amdgpu` kernel driver
- Mesa provides OpenGL/Vulkan support
- Usually included by default in base packages

**Packages:**
- **Required:** Usually none (mesa included in desktop environments)
- **Optional:**
  - `mesa` - Explicit install if needed
  - `vulkan-radeon` - Vulkan support
  - `libva-mesa-driver` - Hardware video acceleration (VA-API)
  - `mesa-vdpau` - Hardware video acceleration (VDPAU)
  - `xf86-video-amdgpu` - DDX driver (usually not needed with modern Xorg)

**Kernel modules:** `amdgpu` (loaded automatically)

**Kernel parameters:** Usually none required

### NVIDIA GPUs

**Proprietary Drivers (Required)**
- NVIDIA requires proprietary drivers for good performance
- Open source `nouveau` driver exists but limited (poor performance, no CUDA)
- Must match kernel version (use `-lts` variants with `linux-lts`)

**Packages:**
- **Required:**
  - `nvidia-lts` - Proprietary driver for linux-lts kernel
  - `nvidia-utils` - Userspace utilities and libraries
  - `nvidia-settings` - Configuration GUI
- **Optional:**
  - `lib32-nvidia-utils` - 32-bit support (gaming, Wine)
  - `cuda` - CUDA toolkit (development, ML)
  - `opencl-nvidia` - OpenCL support

**Kernel modules:** `nvidia`, `nvidia_modeset`, `nvidia_uvm`, `nvidia_drm`

**Kernel parameters (important!):**
```
nvidia_drm.modeset=1
```
Required for Wayland support and modern display management.

**mkinitcpio hooks:**
Add `nvidia` modules to `/etc/mkinitcpio.conf`:
```
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
```

### Intel GPUs

**Open Source Drivers (Default)**
- Modern Intel GPUs use `i915` kernel driver (older) or `xe` (newer, Arc GPUs)
- Mesa provides OpenGL/Vulkan support
- Usually included by default

**Packages:**
- **Required:** Usually none (included in desktop)
- **Optional:**
  - `mesa` - Explicit install if needed
  - `vulkan-intel` - Vulkan support
  - `intel-media-driver` - Hardware video acceleration (newer GPUs, Broadwell+)
  - `libva-intel-driver` - Hardware video acceleration (older GPUs, up to Coffee Lake)
  - `xf86-video-intel` - DDX driver (usually not needed, modesetting is better)

**Kernel modules:** `i915` or `xe` (loaded automatically)

**Kernel parameters:** Usually none required

## Microcode (CPU-based)

**Separate from GPU!** Microcode is CPU vendor-specific.

### AMD CPUs
**Package:** `amd-ucode`

**Purpose:** CPU microcode updates for AMD processors

**Installation:** Always install on AMD CPUs (regardless of GPU)

### Intel CPUs
**Package:** `intel-ucode`

**Purpose:** CPU microcode updates for Intel processors

**Installation:** Always install on Intel CPUs (regardless of GPU)

**Important:** CPU microcode ≠ GPU drivers. An Intel CPU can have an NVIDIA GPU!

## Detection Strategy

### Step 1: Detect GPU Hardware

**Method:** Use `lspci` to query PCI devices

**AMD GPU Detection:**
```bash
lspci | grep -i "VGA\|3D\|Display" | grep -i "AMD\|ATI"
```

**NVIDIA GPU Detection:**
```bash
lspci | grep -i "VGA\|3D\|Display" | grep -i "NVIDIA"
```

**Intel GPU Detection:**
```bash
lspci | grep -i "VGA\|3D\|Display" | grep -i "Intel"
```

**Example output:**
```
01:00.0 VGA compatible controller: NVIDIA Corporation GA104 [GeForce RTX 3070]
00:02.0 VGA compatible controller: Intel Corporation UHD Graphics 630
```

### Step 2: Detect CPU for Microcode

**AMD CPU Detection:**
```bash
lscpu | grep -i "vendor" | grep -i "AMD"
# OR
grep -i "AMD" /proc/cpuinfo
```

**Intel CPU Detection:**
```bash
lscpu | grep -i "vendor" | grep -i "Intel"
# OR
grep -i "Intel" /proc/cpuinfo
```

### Step 3: Determine Configuration

**Possible scenarios:**
1. **Single AMD GPU** → Install AMD drivers (if needed)
2. **Single NVIDIA GPU** → Install NVIDIA drivers + kernel params
3. **Single Intel GPU** → Use defaults (integrated)
4. **Hybrid: Intel + NVIDIA** → Install both, configure NVIDIA prime
5. **Hybrid: AMD + NVIDIA** → Rare, install both
6. **Multiple GPUs** → Install all drivers, let user configure later

## Hybrid GPU Systems (Laptops)

### Intel + NVIDIA (Most Common)

**Challenge:** Laptops often have:
- Intel iGPU (integrated) - low power, always on
- NVIDIA dGPU (discrete) - high performance, switchable

**Solutions:**

**Option 1: NVIDIA Prime (Official)**
- Install both Intel and NVIDIA drivers
- Use `prime-run` command to run apps on NVIDIA
- Default: Intel GPU (power saving)
- Example: `prime-run glxinfo` (runs on NVIDIA)

**Packages:** `nvidia-prime` (provides `prime-run` script)

**Option 2: Optimus Manager**
- AUR package for switching between GPUs
- Requires logout to switch
- More complex, not recommended for V1

**V1 Recommendation:** Install both drivers, provide `prime-run`, document usage

### AMD + AMD (APU + dGPU)

**Scenario:** AMD CPU with integrated graphics + AMD discrete GPU

**Solution:** Install AMD drivers once, both GPUs work automatically

**DRI_PRIME:** Can select GPU with environment variable:
```bash
DRI_PRIME=1 glxinfo  # Run on discrete GPU
```

### Detection Logic for Hybrid

**Count GPUs:**
```bash
GPU_COUNT=$(lspci | grep -i "VGA\|3D" | wc -l)
```

**If GPU_COUNT > 1:**
- Detect all GPU types
- Install all required drivers
- Configure for primary GPU (usually discrete for desktop, integrated for laptop)
- Provide switching mechanism (prime-run or DRI_PRIME)

## Package Selection Logic

### Pseudocode

```
# Detect GPUs
HAS_AMD = detect_amd_gpu()
HAS_NVIDIA = detect_nvidia_gpu()
HAS_INTEL = detect_intel_gpu()

# Detect CPU
HAS_AMD_CPU = detect_amd_cpu()
HAS_INTEL_CPU = detect_intel_cpu()

# Base packages (always installed)
PACKAGES = ["base", "linux-lts", "linux-firmware", "btrfs-progs", ...]

# Microcode (CPU-based)
if HAS_AMD_CPU:
    PACKAGES.append("amd-ucode")
elif HAS_INTEL_CPU:
    PACKAGES.append("intel-ucode")

# GPU drivers
if HAS_NVIDIA:
    PACKAGES.extend(["nvidia-lts", "nvidia-utils", "nvidia-settings"])
    NEEDS_NVIDIA_PARAMS = true
    if HAS_INTEL or HAS_AMD:
        PACKAGES.append("nvidia-prime")  # Hybrid system

if HAS_AMD:
    # AMD drivers usually included, but ensure mesa
    PACKAGES.extend(["mesa", "vulkan-radeon"])

if HAS_INTEL:
    # Intel drivers usually included
    PACKAGES.extend(["mesa", "vulkan-intel", "intel-media-driver"])

# Desktop environment (if selected)
if DESKTOP == "gnome":
    PACKAGES.extend(["gnome", "gdm", ...])
```

## Kernel Parameters

### NVIDIA Systems

**Required parameter:**
```
nvidia_drm.modeset=1
```

**Why:** Enables DRM kernel mode setting for NVIDIA, required for Wayland and modern display management.

**Where to add:**
- systemd-boot: `/boot/loader/entries/arch.conf`
- In `options` line with other kernel parameters

**Example:**
```
options cryptdevice=UUID=xxx:cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ nvidia_drm.modeset=1
```

### AMD/Intel Systems

**Usually no special parameters needed.**

**Optional (power saving):**
- AMD: `amdgpu.ppfeaturemask=0xffffffff` (enable overclocking features)
- Intel: `i915.enable_guc=3` (enable GuC/HuC firmware, better power management)

**V1: Skip optional parameters, keep it simple.**

## mkinitcpio Configuration

### NVIDIA Systems

**Must add NVIDIA modules to initramfs!**

**Edit `/etc/mkinitcpio.conf`:**
```
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
```

**Why:** Ensures NVIDIA modules load early, prevents issues with early KMS.

**Rebuild initramfs:**
```bash
mkinitcpio -P
```

### AMD/Intel Systems

**No special modules needed** (loaded automatically).

**Standard configuration:**
```
MODULES=()
HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)
```

## Installation Flow

### During pacstrap (Step 5 of installation)

```
1. Detect GPU(s) using lspci
2. Detect CPU using lscpu
3. Build package list:
   - Base packages
   - Microcode (amd-ucode or intel-ucode)
   - GPU drivers (nvidia-lts, mesa, vulkan packages)
   - Hybrid support (nvidia-prime if needed)
4. Run pacstrap with full package list
```

### During chroot configuration (Step 6)

```
IF NVIDIA detected:
  1. Edit /etc/mkinitcpio.conf:
     - Add NVIDIA modules to MODULES=()
  2. Regenerate initramfs: mkinitcpio -P
  3. Add nvidia_drm.modeset=1 to boot entry
```

## User Communication

### Information Display

**After detection, show user:**
```
┌─────────────────────────────────────┐
│ Hardware Detected                   │
├─────────────────────────────────────┤
│ CPU:  AMD Ryzen 7 5800X             │
│       → Installing amd-ucode        │
│                                     │
│ GPU:  AMD Radeon RX 6800 XT         │
│       → Using open source drivers   │
│       → Installing mesa, vulkan     │
└─────────────────────────────────────┘
```

**For hybrid systems:**
```
┌─────────────────────────────────────┐
│ Hardware Detected                   │
├─────────────────────────────────────┤
│ CPU:  Intel Core i7-11800H          │
│       → Installing intel-ucode      │
│                                     │
│ GPU1: Intel UHD Graphics (iGPU)     │
│ GPU2: NVIDIA RTX 3070 (dGPU)        │
│       → Hybrid configuration        │
│       → Installing NVIDIA drivers   │
│       → Installing nvidia-prime     │
│                                     │
│ Note: Use 'prime-run <app>' to      │
│       run applications on NVIDIA    │
└─────────────────────────────────────┘
```

## Edge Cases & Troubleshooting

### Unknown GPU Vendor

**If lspci shows GPU but vendor not recognized:**
- Fallback: Install mesa (works for most)
- Log warning for manual driver installation
- Continue installation

### No GPU Detected

**Rare, but possible (servers, VMs):**
- Skip GPU driver installation
- Install basic mesa (software rendering fallback)
- System will work but no hardware acceleration

### Multiple NVIDIA GPUs (SLI/NVLink)

**Same driver works for all NVIDIA GPUs**
- Detect any NVIDIA GPU → install nvidia-lts
- All NVIDIA GPUs in system use same driver

### Nouveau Blacklist

**NVIDIA proprietary drivers require blacklisting nouveau:**
- Modern nvidia package handles this automatically
- Creates `/usr/lib/modprobe.d/nvidia.conf` with blacklist
- V1: No manual intervention needed

### VM Detection

**Virtual machines (VirtualBox, VMware, QEMU):**
- May show virtual GPU (VirtualBox Graphics, VMware SVGA)
- Install guest additions instead of GPU drivers
- V1: Out of scope, document for V2

## Testing Strategy

### Test Scenarios

**Scenario 1: AMD GPU + AMD CPU**
- Example: Ryzen + RX 6800
- Expected: amd-ucode, mesa drivers
- Verify: `glxinfo | grep "OpenGL renderer"` shows AMD

**Scenario 2: NVIDIA GPU + Intel CPU**
- Example: i7 + RTX 3070
- Expected: intel-ucode, nvidia-lts
- Verify: `nvidia-smi` shows GPU info

**Scenario 3: Intel iGPU only**
- Example: i5 with integrated graphics
- Expected: intel-ucode, mesa
- Verify: `glxinfo` works

**Scenario 4: Hybrid Intel + NVIDIA**
- Example: Laptop with i7 + RTX 3060
- Expected: Both drivers, nvidia-prime
- Verify: `prime-run glxinfo` uses NVIDIA

**Scenario 5: AMD APU (integrated graphics)**
- Example: Ryzen 5700G
- Expected: amd-ucode, mesa
- Verify: `DRI_PRIME=0 glxinfo` works

## Detection Script Structure

### Pseudocode Flow

```bash
#!/bin/bash
# detect_hardware.sh

detect_gpu() {
    local gpu_info=$(lspci | grep -i "VGA\|3D\|Display")

    # Detect vendors
    if echo "$gpu_info" | grep -iq "AMD\|ATI"; then
        HAS_AMD_GPU=true
        AMD_GPU_NAME=$(echo "$gpu_info" | grep -i "AMD\|ATI" | cut -d: -f3)
    fi

    if echo "$gpu_info" | grep -iq "NVIDIA"; then
        HAS_NVIDIA_GPU=true
        NVIDIA_GPU_NAME=$(echo "$gpu_info" | grep -i "NVIDIA" | cut -d: -f3)
    fi

    if echo "$gpu_info" | grep -iq "Intel"; then
        HAS_INTEL_GPU=true
        INTEL_GPU_NAME=$(echo "$gpu_info" | grep -i "Intel" | cut -d: -f3)
    fi

    # Count GPUs
    GPU_COUNT=$(echo "$gpu_info" | wc -l)
}

detect_cpu() {
    local cpu_info=$(lscpu)

    if echo "$cpu_info" | grep -iq "AMD"; then
        HAS_AMD_CPU=true
        MICROCODE="amd-ucode"
    elif echo "$cpu_info" | grep -iq "Intel"; then
        HAS_INTEL_CPU=true
        MICROCODE="intel-ucode"
    fi
}

build_package_list() {
    # Base packages
    PACKAGES=("base" "linux-lts" "linux-firmware" "btrfs-progs" ...)

    # Microcode
    [[ -n "$MICROCODE" ]] && PACKAGES+=("$MICROCODE")

    # GPU drivers
    if [[ "$HAS_NVIDIA_GPU" == true ]]; then
        PACKAGES+=("nvidia-lts" "nvidia-utils" "nvidia-settings")
        NEEDS_NVIDIA_CONFIG=true

        # Hybrid system
        if [[ "$GPU_COUNT" -gt 1 ]]; then
            PACKAGES+=("nvidia-prime")
            IS_HYBRID=true
        fi
    fi

    if [[ "$HAS_AMD_GPU" == true ]]; then
        PACKAGES+=("mesa" "vulkan-radeon")
    fi

    if [[ "$HAS_INTEL_GPU" == true ]]; then
        PACKAGES+=("mesa" "vulkan-intel" "intel-media-driver")
    fi
}

display_hardware_info() {
    gum style --border rounded --padding "1 2" "
    Hardware Detected:

    CPU:  $CPU_NAME
          → Microcode: $MICROCODE

    GPU:  ${AMD_GPU_NAME}${NVIDIA_GPU_NAME}${INTEL_GPU_NAME}
          → Drivers: ${DRIVER_INFO}
    "
}

# Main execution
detect_gpu
detect_cpu
build_package_list
display_hardware_info
```

## V2 Enhancements

**Planned for future:**
- ⏳ VM detection and guest tools installation
- ⏳ Optimus Manager integration (advanced GPU switching)
- ⏳ NVIDIA CUDA toolkit installation option
- ⏳ AMD ROCm installation option (compute/ML)
- ⏳ Multi-monitor configuration
- ⏳ Custom kernel parameters (gaming optimizations)
- ⏳ Vulkan layer configuration (MangoHud, vkBasalt)
- ⏳ GPU overclocking tools (CoreCtrl for AMD)

## References

- [Arch Wiki: NVIDIA](https://wiki.archlinux.org/title/NVIDIA)
- [Arch Wiki: AMDGPU](https://wiki.archlinux.org/title/AMDGPU)
- [Arch Wiki: Intel Graphics](https://wiki.archlinux.org/title/Intel_graphics)
- [Arch Wiki: NVIDIA Optimus](https://wiki.archlinux.org/title/NVIDIA_Optimus)
- [Arch Wiki: Hybrid Graphics](https://wiki.archlinux.org/title/Hybrid_graphics)
- [Arch Wiki: Microcode](https://wiki.archlinux.org/title/Microcode)
