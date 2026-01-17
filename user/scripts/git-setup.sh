#!/bin/bash
# Git config and SSH key setup script
# Called by wintarch-user-update

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
    local current_name current_email name email

    current_name=$(git config --global user.name 2>/dev/null || true)
    current_email=$(git config --global user.email 2>/dev/null || true)

    if [[ -n "$current_name" && -n "$current_email" ]]; then
        echo "Current git configuration:"
        echo "  Name:  $current_name"
        echo "  Email: $current_email"
        echo ""

        if gum confirm "Update git configuration?"; then
            name=$(gum input --placeholder "Git user name" --value "$current_name")
            email=$(gum input --placeholder "Git email" --value "$current_email")
            git config --global user.name "$name"
            git config --global user.email "$email"
            echo "Git configuration updated"
        else
            echo "Keeping existing git configuration"
        fi
    else
        echo "Setting up git configuration..."
        name=$(gum input --placeholder "Git user name (e.g., John Doe)")
        email=$(gum input --placeholder "Git email (e.g., john@example.com)")
        git config --global user.name "$name"
        git config --global user.email "$email"
        echo "Git configuration saved"
    fi
}

# Generate or display SSH key
setup_ssh_key() {
    local ssh_dir="$HOME/.ssh"
    local key_path="$ssh_dir/id_ed25519"
    local pub_key_path="$key_path.pub"

    # Create .ssh directory if it doesn't exist
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"

    if [[ -f "$key_path" ]]; then
        echo ""
        echo "SSH key already exists:"
        echo "---"
        cat "$pub_key_path"
        echo "---"
        echo ""

        if gum confirm "Generate a NEW SSH key? (old key will be backed up)"; then
            local backup_path="$ssh_dir/id_ed25519.bak.$(date +%s)"
            mv "$key_path" "$backup_path"
            mv "$pub_key_path" "$backup_path.pub"
            echo "Old key backed up to: $backup_path"

            local email
            email=$(git config --global user.email 2>/dev/null || echo "")
            ssh-keygen -t ed25519 -C "$email" -N "" -f "$key_path"

            echo ""
            echo "New SSH public key (add to GitHub/GitLab):"
            echo "---"
            cat "$pub_key_path"
            echo "---"
        else
            echo "Keeping existing SSH key"
        fi
    else
        echo ""
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
    fi
}

# Setup (first run)
setup() {
    check_dependencies
    configure_git
    setup_ssh_key
}

# Update (subsequent runs)
update() {
    check_dependencies
    configure_git
    setup_ssh_key
}

# Main
case "${1:-}" in
    setup)
        setup
        ;;
    update)
        update
        ;;
    *)
        echo "Usage: $0 {setup|update}"
        exit 1
        ;;
esac
