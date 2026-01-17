#!/bin/bash
# Git config and SSH key setup script
# Called by wintarch-user-update and user migrations

set -e

# Required dependencies
DEPENDENCIES=(git openssh gum)

# Check and install dependencies before proceeding
check_dependencies() {
    local missing=()

    for dep in "${DEPENDENCIES[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Installing missing dependencies: ${missing[*]}"
        sudo pacman -S --noconfirm "${missing[@]}"
    fi
}

# Configure git user name and email
configure_git() {
    echo "Setting up git configuration..."
    local name email

    name=$(gum input --placeholder "Git user name (e.g., John Doe)")
    email=$(gum input --placeholder "Git email (e.g., john@example.com)")

    git config --global user.name "$name"
    git config --global user.email "$email"
    echo "Git configuration saved"
}

# Generate SSH key (auto-backup if exists)
setup_ssh_key() {
    local ssh_dir="$HOME/.ssh"
    local key_path="$ssh_dir/id_ed25519"
    local pub_key_path="$key_path.pub"

    # Create .ssh directory if it doesn't exist
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"

    # Backup existing key if present
    if [[ -f "$key_path" ]]; then
        local backup_path="$ssh_dir/id_ed25519.bak.$(date +%s)"
        mv "$key_path" "$backup_path"
        mv "$pub_key_path" "$backup_path.pub"
        echo "Existing SSH key backed up to: $backup_path"
    fi

    # Generate new key
    echo "Generating SSH key..."
    local email
    email=$(git config --global user.email 2>/dev/null || echo "")
    ssh-keygen -t ed25519 -C "$email" -N "" -f "$key_path"

    echo ""
    echo "SSH public key (add to GitHub/GitLab):"
    echo "---"
    cat "$pub_key_path"
    echo "---"
    echo ""
    echo "Key generated with blank password (protected by LUKS encryption)"
}

# Main
check_dependencies
configure_git
setup_ssh_key
