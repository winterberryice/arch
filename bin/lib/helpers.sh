#!/bin/bash
# Shared helper functions for wintarch commands

# Check if running as root, exit with message if not
require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "\033[31mError: This command must be run as root.\033[0m" >&2
        echo "Try: sudo $(basename "$0") $*" >&2
        exit 1
    fi
}
