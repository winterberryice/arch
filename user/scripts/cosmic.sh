#!/bin/bash
# COSMIC desktop setup and update script
# Called by wintarch-user-update
#
# Sets up (first run only):
# - Dock favorites: Brave, VS Code, Files, Edit, Terminal, Store, Settings
# - Default web browser: Brave

set -e

COSMIC_CONFIG_DIR="$HOME/.config/cosmic"
APPLIST_DIR="$COSMIC_CONFIG_DIR/com.system76.CosmicAppList/v1"
FAVORITES_FILE="$APPLIST_DIR/favorites"

# Desktop file IDs for pinned applications
# Order matters - this is how they appear in the dock
DOCK_FAVORITES=(
    "brave-browser"
    "code"
    "com.system76.CosmicFiles"
    "com.system76.CosmicEdit"
    "com.system76.CosmicTerm"
    "com.system76.CosmicStore"
    "com.system76.CosmicSettings"
)

# Check if COSMIC is running/installed
is_cosmic_available() {
    # Check for cosmic-session or cosmic-panel
    command -v cosmic-session &>/dev/null || command -v cosmic-panel &>/dev/null
}

# Set dock favorites (pinned apps)
setup_dock_favorites() {
    echo "Setting up COSMIC dock favorites..."

    # Create config directory if it doesn't exist
    mkdir -p "$APPLIST_DIR"

    # Generate RON-format favorites list
    {
        echo "["
        for i in "${!DOCK_FAVORITES[@]}"; do
            if [[ $i -lt $((${#DOCK_FAVORITES[@]} - 1)) ]]; then
                echo "    \"${DOCK_FAVORITES[$i]}\","
            else
                echo "    \"${DOCK_FAVORITES[$i]}\","
            fi
        done
        echo "]"
    } > "$FAVORITES_FILE"

    echo "Dock favorites configured: ${DOCK_FAVORITES[*]}"
}

# Set default web browser to Brave
setup_default_browser() {
    echo "Setting Brave as default web browser..."

    # Check if Brave is installed
    if ! command -v brave &>/dev/null; then
        echo "Brave not installed yet, skipping default browser setup"
        return 0
    fi

    # Use xdg-settings to set default browser
    if command -v xdg-settings &>/dev/null; then
        xdg-settings set default-web-browser brave-browser.desktop 2>/dev/null || {
            echo "Note: Could not set default browser (may need graphical session)"
        }
    fi

    # Also set via xdg-mime for http/https handlers
    if command -v xdg-mime &>/dev/null; then
        xdg-mime default brave-browser.desktop x-scheme-handler/http 2>/dev/null || true
        xdg-mime default brave-browser.desktop x-scheme-handler/https 2>/dev/null || true
        xdg-mime default brave-browser.desktop text/html 2>/dev/null || true
    fi

    echo "Default browser set to Brave"
}

# Setup (first run)
setup() {
    if ! is_cosmic_available; then
        echo "COSMIC desktop not detected, skipping setup"
        return 0
    fi

    setup_dock_favorites
    setup_default_browser
}

# Update (subsequent runs) - no-op to preserve user customizations
update() {
    # Don't overwrite user's dock/browser customizations
    # Setup is only done on first run
    :
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
