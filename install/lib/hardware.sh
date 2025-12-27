#!/bin/bash
# lib/hardware.sh - Hardware detection functions
# Part of omarchy fork installer
# Based on docs/002-gpu-detection.md

# Hardware detection flags
HAS_AMD_GPU=false
HAS_NVIDIA_GPU=false
HAS_INTEL_GPU=false
HAS_AMD_CPU=false
HAS_INTEL_CPU=false

MICROCODE=""
GPU_PACKAGES=()
CPU_NAME=""
GPU_NAME=""

detect_cpu() {
    info "Detecting CPU..."

    CPU_NAME=$(grep -m1 "model name" /proc/cpuinfo | cut -d':' -f2 | xargs)

    if grep -qi "AMD" /proc/cpuinfo; then
        HAS_AMD_CPU=true
        MICROCODE="amd-ucode"
        info "Detected AMD CPU: $CPU_NAME"
    elif grep -qi "Intel" /proc/cpuinfo; then
        HAS_INTEL_CPU=true
        MICROCODE="intel-ucode"
        info "Detected Intel CPU: $CPU_NAME"
    else
        warn "Unknown CPU vendor, skipping microcode"
        MICROCODE=""
    fi
}

detect_gpu() {
    info "Detecting GPU..."

    local gpu_info
    gpu_info=$(lspci 2>/dev/null | grep -iE "VGA|3D|Display" || echo "")

    if [[ -z "$gpu_info" ]]; then
        warn "No GPU detected via lspci"
        GPU_NAME="Unknown/Virtual"
        return
    fi

    GPU_NAME=$(echo "$gpu_info" | head -n1 | cut -d':' -f3 | xargs)

    # Check for AMD
    if echo "$gpu_info" | grep -iq "AMD\|ATI"; then
        HAS_AMD_GPU=true
        info "Detected AMD GPU: $GPU_NAME"
    fi

    # Check for NVIDIA
    if echo "$gpu_info" | grep -iq "NVIDIA"; then
        HAS_NVIDIA_GPU=true
        info "Detected NVIDIA GPU: $GPU_NAME"
    fi

    # Check for Intel
    if echo "$gpu_info" | grep -iq "Intel"; then
        HAS_INTEL_GPU=true
        info "Detected Intel GPU: $GPU_NAME"
    fi

    # If nothing detected, assume software rendering
    if [[ "$HAS_AMD_GPU" == false ]] && [[ "$HAS_NVIDIA_GPU" == false ]] && [[ "$HAS_INTEL_GPU" == false ]]; then
        warn "No recognized GPU vendor, will install mesa for software rendering"
        HAS_INTEL_GPU=true  # Use mesa as fallback
    fi
}

build_gpu_package_list() {
    info "Building GPU driver package list..."

    GPU_PACKAGES=()

    # NVIDIA drivers (proprietary)
    if [[ "$HAS_NVIDIA_GPU" == true ]]; then
        GPU_PACKAGES+=(nvidia nvidia-utils nvidia-settings)
        info "Added NVIDIA proprietary drivers"
    fi

    # AMD/Intel drivers (mesa)
    if [[ "$HAS_AMD_GPU" == true ]] || [[ "$HAS_INTEL_GPU" == true ]]; then
        GPU_PACKAGES+=(mesa)
        info "Added mesa drivers"

        # AMD-specific
        if [[ "$HAS_AMD_GPU" == true ]]; then
            GPU_PACKAGES+=(vulkan-radeon libva-mesa-driver)
            info "Added AMD Vulkan and video acceleration"
        fi

        # Intel-specific
        if [[ "$HAS_INTEL_GPU" == true ]]; then
            GPU_PACKAGES+=(vulkan-intel intel-media-driver)
            info "Added Intel Vulkan and video acceleration"
        fi
    fi
}

detect_all_hardware() {
    ui_section "Hardware Detection"

    detect_cpu
    detect_gpu
    build_gpu_package_list

    # Display summary
    ui_info "Hardware Summary:"
    echo "  CPU:       $CPU_NAME"
    echo "  Microcode: ${MICROCODE:-None}"
    echo "  GPU:       $GPU_NAME"
    echo "  Drivers:   ${GPU_PACKAGES[*]}"
    echo ""

    # Save to state for later phases
    save_state "microcode" "$MICROCODE"
    save_state "gpu_packages" "${GPU_PACKAGES[*]}"
    save_state "has_nvidia" "$HAS_NVIDIA_GPU"
}
