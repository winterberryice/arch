# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-01-15

### Added

-   **New Installer:** Complete rewrite of the system installer, inspired by `omarchy`.
    -   Features a TUI-driven configuration process.
    -   Supports dual-booting with Windows (options to wipe disk, use free space, or use an existing partition).
    -   Enforces mandatory LUKS2 full-disk encryption.
    -   Uses BTRFS with subvolumes (`@`, `@home`, `@log`, `@pkg`) for an efficient filesystem layout.
-   **Bootable Snapshots:** Integrated `limine` bootloader with `snapper`.
    -   Automatically creates system snapshots before updates.
    -   Allows booting into read-only snapshots from the boot menu for easy rollback.
    -   A new `wintarch-snapshot restore` command makes a booted snapshot permanent.
-   **Wintarch System Management:** The installed system is now self-managing via a suite of commands.
    -   `wintarch-update`: Safely updates the system (snapshot -> git pull -> packages -> migrations).
    -   `wintarch-snapshot`: Manages BTRFS snapshots (list, create, delete, restore).
    -   `wintarch-pkg-add`/`drop`: Wrappers for safe package management.
    -   `wintarch-migrations`: A migration system to handle changes on installed systems over time.
-   **User Configuration System:** Added `wintarch-user-update` for managing user-level settings.
    -   Installs and manages Oh My Zsh with custom aliases and configurations.
    -   Installs the Claude Code CLI and adds it to the user's PATH.
    -   Configures the COSMIC desktop dock and sets the default browser on first run.
-   **Included Software & DEs:**
    -   **COSMIC Desktop:** Features System76's modern, Rust-based desktop environment.
    -   **Applications:** Firefox, Brave (default browser), VS Code.
    -   **Development Tools:** `fastfetch`, `btop`, `docker` (with service enabled), and `mise` for version management.
    -   **System Utilities:** Bluetooth support, `curl`, `less`, `gum` for TUI prompts.
-   **Automated Release Workflow:** Implemented a secure, semi-automated release process.
    -   Triggered by a `/release` command in a PR comment by a maintainer.
    -   Automatically merges, bumps the version, tags, and creates a GitHub Release.
-   **Automated Installation:** Added `boot.sh` script to enable one-liner installation from the Arch ISO.
-   **Testing:** Included a QEMU script (`test/test.sh`) for testing installer builds.

### Changed

-   **Project Structure:** Reorganized the repository into a clearer structure (`install/`, `bin/`, `user/`, `systemd/`, etc.).
-   **Root Handling:** Refactored system management scripts to use `sudo` for specific commands instead of requiring the entire script to be run as root, improving compatibility with tools like `yay`.
-   **Installer Output:** Post-installation steps now show real-time output instead of appearing to hang.
-   **Documentation:** Split documentation into a user-focused `README.md` and a developer-focused `CLAUDE.md`.

### Fixed

-   **Snapper Configuration:** Moved Snapper setup to a `systemd` service that runs on first boot, fixing failures caused by the lack of a D-Bus session in the installer's `chroot` environment.
-   **Archinstall Stability:** Resolved multiple issues where `archinstall` would fail due to Python version mismatches or missing dependencies on the live ISO.
-   **Git Pager:** Prevented `wintarch-update` from failing on minimal systems by setting `GIT_PAGER=cat`.
-   **Git Ownership:** Fixed "dubious ownership" errors from `git` by adding `/opt/wintarch` to the system's `safe.directory` list during installation.

[unreleased]: https://github.com/winterberryice/arch/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/winterberryice/arch/tree/v0.1.0
