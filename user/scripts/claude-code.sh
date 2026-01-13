#!/bin/bash
# Claude Code setup and update script
# Called by wintarch-user-update

set -e

CLAUDE_DIR="$HOME/.claude"

# Install Claude Code
install_claude_code() {
    if [[ -d "$CLAUDE_DIR" ]] && command -v claude &>/dev/null; then
        echo "Claude Code already installed"
        return 0
    fi

    echo "Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash
}

# Update Claude Code
update_claude_code() {
    if ! command -v claude &>/dev/null; then
        echo "Claude Code not installed, skipping update"
        return 0
    fi

    echo "Updating Claude Code..."
    claude update
}

# Setup (first run)
setup() {
    install_claude_code
}

# Update (subsequent runs)
update() {
    update_claude_code
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
