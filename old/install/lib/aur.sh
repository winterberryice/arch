#!/bin/bash
# lib/aur.sh - AUR package management functions
# Part of omarchy fork installer

# Build and install an AUR package as a specific user
# Usage: build_aur_package <package_name> <build_user>
build_aur_package() {
    local package="$1"
    local build_user="$2"

    if [[ -z "$package" ]] || [[ -z "$build_user" ]]; then
        error "Usage: build_aur_package <package_name> <build_user>"
        return 1
    fi

    info "Building AUR package: $package"

    # Create temporary build directory
    local build_dir="/tmp/aur-${package}"
    mkdir -p "$build_dir"
    chown "$build_user:$build_user" "$build_dir"

    # Clone AUR repository
    info "Cloning AUR repository for $package..."
    if ! sudo -u "$build_user" git clone "https://aur.archlinux.org/${package}.git" "$build_dir"; then
        error "Failed to clone AUR repository for $package"
        return 1
    fi

    # Build package
    info "Building $package (this may take a few minutes)..."
    cd "$build_dir" || return 1

    if ! sudo -u "$build_user" makepkg --noconfirm -si; then
        error "Failed to build $package"
        return 1
    fi

    cd - > /dev/null || return 1

    # Cleanup
    rm -rf "$build_dir"

    success "Successfully installed $package from AUR"
    return 0
}

# Install yay AUR helper
# Usage: install_yay <build_user>
install_yay() {
    local build_user="$1"

    if [[ -z "$build_user" ]]; then
        error "Usage: install_yay <build_user>"
        return 1
    fi

    info "Installing yay AUR helper..."

    # Install base-devel if not already installed
    if ! pacman -Qi base-devel &>/dev/null; then
        info "Installing base-devel (required for AUR builds)..."
        pacman -S --noconfirm --needed base-devel
    fi

    # Install git if not already installed
    if ! pacman -Qi git &>/dev/null; then
        info "Installing git (required for AUR)..."
        pacman -S --noconfirm --needed git
    fi

    # Allow build user to run pacman without password (temporary)
    echo "${build_user} ALL=(ALL) NOPASSWD: /usr/bin/pacman" > /etc/sudoers.d/temp-aur-build
    chmod 0440 /etc/sudoers.d/temp-aur-build

    # Build and install yay
    if ! build_aur_package "yay" "$build_user"; then
        error "Failed to install yay"
        rm -f /etc/sudoers.d/temp-aur-build
        return 1
    fi

    # Remove temporary sudo permissions
    rm -f /etc/sudoers.d/temp-aur-build

    success "yay AUR helper installed successfully"
    return 0
}

# Install AUR package using yay
# Usage: install_from_aur <package_name>
install_from_aur() {
    local package="$1"

    if [[ -z "$package" ]]; then
        error "Usage: install_from_aur <package_name>"
        return 1
    fi

    if ! command -v yay &>/dev/null; then
        error "yay not found - install yay first"
        return 1
    fi

    info "Installing $package from AUR using yay..."

    # Run yay as root (yay will drop privileges automatically)
    if ! yay -S --noconfirm --needed "$package"; then
        error "Failed to install $package from AUR"
        return 1
    fi

    success "Successfully installed $package from AUR"
    return 0
}
