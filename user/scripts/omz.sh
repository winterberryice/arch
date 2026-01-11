#!/bin/bash
# Oh My Zsh setup and update script
# Called by wintarch-user-update

set -e

OMZ_DIR="$HOME/.oh-my-zsh"
OMZ_CUSTOM="$OMZ_DIR/custom/plugins"

# Plugin repositories
declare -A PLUGINS=(
    ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions.git"
    ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
)

# Install Oh My Zsh (non-interactive)
install_omz() {
    if [[ -d "$OMZ_DIR" ]]; then
        echo "Oh My Zsh already installed"
        return 0
    fi

    echo "Installing Oh My Zsh..."
    git clone https://github.com/ohmyzsh/ohmyzsh.git "$OMZ_DIR"
}

# Install external plugins
install_plugins() {
    mkdir -p "$OMZ_CUSTOM"

    for plugin in "${!PLUGINS[@]}"; do
        local plugin_dir="$OMZ_CUSTOM/$plugin"
        if [[ -d "$plugin_dir" ]]; then
            echo "Plugin $plugin already installed"
        else
            echo "Installing plugin: $plugin..."
            git clone "${PLUGINS[$plugin]}" "$plugin_dir"
        fi
    done
}

# Update Oh My Zsh
update_omz() {
    if [[ ! -d "$OMZ_DIR" ]]; then
        echo "Oh My Zsh not installed, skipping update"
        return 0
    fi

    echo "Updating Oh My Zsh..."
    git -C "$OMZ_DIR" pull --rebase --autostash
}

# Update external plugins
update_plugins() {
    for plugin in "${!PLUGINS[@]}"; do
        local plugin_dir="$OMZ_CUSTOM/$plugin"
        if [[ -d "$plugin_dir" ]]; then
            echo "Updating plugin: $plugin..."
            git -C "$plugin_dir" pull --rebase --autostash
        fi
    done
}

# Setup (first run)
setup() {
    install_omz
    install_plugins
}

# Update (subsequent runs)
update() {
    update_omz
    update_plugins
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
