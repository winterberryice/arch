#!/bin/bash
# Migration: Add yay color support
# Enables color output for pacman and yay by uncommenting Color in pacman.conf

set -e

echo "=== Yay/Pacman Color Configuration Migration ==="
echo "Enabling color support for pacman and yay..."
echo ""

# 1. Check if Color is already enabled in pacman.conf
if grep -q '^Color' /etc/pacman.conf; then
    echo "✓ Color already enabled in pacman.conf, nothing to do"
    exit 0
fi

# 2. Check if Color option exists (commented or not)
if ! grep -q '#Color' /etc/pacman.conf && ! grep -q 'Color' /etc/pacman.conf; then
    echo "⚠ Warning: Color option not found in /etc/pacman.conf"
    echo "  Adding Color option to /etc/pacman.conf..."
    # Add Color after the [options] section
    sed -i '/^\[options\]/a Color' /etc/pacman.conf
else
    # 3. Uncomment the Color line
    echo "Uncommenting Color in /etc/pacman.conf..."
    sed -i 's/^#Color/Color/' /etc/pacman.conf
fi

echo "✓ Color enabled in pacman.conf"
echo ""

# 4. Verify configuration
echo "=== Configuration Summary ==="
echo "File: /etc/pacman.conf"
echo "Color setting:"
grep '^Color' /etc/pacman.conf
echo ""
echo "✓ Migration complete!"
echo ""
echo "Both pacman and yay will now display colored output in the terminal."
echo ""
