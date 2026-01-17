#!/bin/bash
# User migration: Add git config and SSH key setup
# This migration offers existing users the option to configure git and SSH keys

set -e

WINTARCH_PATH="${WINTARCH_PATH:-/opt/wintarch}"

echo ""
if command -v gum &>/dev/null && gum confirm "Set up git config and SSH keys?"; then
    "$WINTARCH_PATH/user/scripts/git-setup.sh"
else
    echo "Skipping git setup"
fi
