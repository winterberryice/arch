#!/bin/bash
# Quick installer for QEMU testing
# Usage in QEMU: bash <(curl -sL https://raw.githubusercontent.com/winterberryice/arch/claude/implement-omarchy-fork-R9IW6/test/install-test.sh)

set -e

echo "Cloning arch installer..."
git clone https://github.com/winterberryice/arch.git /tmp/arch-install
cd /tmp/arch-install

echo "Switching to test branch..."
git checkout claude/implement-omarchy-fork-R9IW6

echo "Running installer..."
cd install
./install.sh
