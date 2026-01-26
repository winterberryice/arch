#!/bin/bash
# Migration: Add yay color support
# Enables color output for yay AUR helper

set -e

echo "=== Yay Color Configuration Migration ==="
echo "Enabling color support for yay..."
echo ""

# 1. Check if yay is installed
if ! command -v yay &>/dev/null; then
    echo "⚠ yay is not installed, skipping color configuration"
    echo "  (Color will be configured automatically if yay is installed later)"
    exit 0
fi

echo "✓ yay is installed"
echo ""

# 2. Check if color config already exists
if [[ -f /etc/yay/config.json ]]; then
    if grep -q '"usecolor".*true' /etc/yay/config.json; then
        echo "✓ yay color support already enabled, nothing to do"
        exit 0
    else
        echo "⚠ yay config exists but color is not enabled"
        echo "  Updating configuration..."
    fi
fi

# 3. Create yay configuration directory
echo "Creating yay configuration..."
mkdir -p /etc/yay

# 4. Create or update yay config with color support
cat > /etc/yay/config.json <<'EOF'
{
  "usecolor": true
}
EOF

echo "✓ yay configuration created"
echo ""

# 5. Verify configuration
echo "=== Configuration Summary ==="
echo "File: /etc/yay/config.json"
cat /etc/yay/config.json
echo ""
echo "✓ Migration complete!"
echo ""
echo "Yay will now display colored output in the terminal."
echo ""
