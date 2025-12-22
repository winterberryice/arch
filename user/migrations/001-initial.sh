#!/bin/bash
# Migration 001: Initial setup
# This migration runs for users updating from version 0 to version 1
# Note: On first run (v0), dotfiles are copied directly, so this typically won't run
# This is here as an example/placeholder

set -e  # Exit on error

echo "Running migration 001: Initial setup"

# Example: Ensure config directories exist
mkdir -p "$HOME/.config/fish"
mkdir -p "$HOME/.config/nvim"
mkdir -p "$HOME/.config/kitty"

# Example: Add a marker to show this migration ran
echo "# Migration 001 completed on $(date)" >> "$HOME/.config/migration.log"

echo "✓ Migration 001 complete"
