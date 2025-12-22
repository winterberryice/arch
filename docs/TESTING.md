# Testing Guide

This document describes testing strategies for my-distro, from quick iteration during development to full system testing before release.

## Table of Contents

1. [Testing Strategy Overview](#testing-strategy-overview)
2. [Docker Quick Iteration](#docker-quick-iteration)
3. [QEMU Full System Testing](#qemu-full-system-testing)
4. [Snapshot-Based Testing](#snapshot-based-testing)
5. [Multi-User Testing](#multi-user-testing)
6. [Migration Testing](#migration-testing)
7. [Testing Checklist](#testing-checklist)

---

## Testing Strategy Overview

### Testing Pyramid for my-distro

```
                    ┌─────────────────┐
                    │  QEMU Full      │  Slow, complete
                    │  System Test    │  (30+ min)
                    └─────────────────┘
                   /                   \
              ┌─────────────────────────────┐
              │   Snapshot Testing          │  Medium, incremental
              │   (QEMU/VM snapshots)       │  (5-10 min)
              └─────────────────────────────┘
             /                                 \
    ┌───────────────────────────────────────────────┐
    │        Docker Quick Iteration                 │  Fast, focused
    │        (script logic, migrations)             │  (1-2 min)
    └───────────────────────────────────────────────┘
```

### When to Use Each

| Test Type | Speed | Scope | Use Case |
|-----------|-------|-------|----------|
| **Docker** | Fast (1-2 min) | Script logic | Developing scripts, testing migrations |
| **Snapshot** | Medium (5-10 min) | Incremental | Testing update flows, multi-user scenarios |
| **QEMU** | Slow (30+ min) | Full system | Pre-release validation, fresh install testing |

---

## Docker Quick Iteration

### Purpose

Docker provides a fast, disposable Arch Linux environment for testing scripts and migrations without the overhead of a full VM.

### Advantages

- ✅ Fast: Boots in seconds
- ✅ Reproducible: Start from clean slate each time
- ✅ Lightweight: No GUI overhead
- ✅ Good for: Script logic, migrations, multi-user basic testing

### Limitations

- ❌ Not a complete system (no init system like systemd)
- ❌ Can't test boot process or system services
- ❌ Some package behaviors may differ

### Setup

#### Dockerfile

Create `testing/Dockerfile`:

```dockerfile
FROM archlinux:latest

# Update system and install base tools
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
    base-devel \
    git \
    neovim \
    fish \
    sudo \
    rsync

# Create test users
RUN useradd -m -G wheel -s /bin/bash alice && \
    useradd -m -G wheel -s /bin/bash bob && \
    useradd -m -s /bin/bash charlie && \
    echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# Set working directory
WORKDIR /workspace

# Default command
CMD ["/bin/bash"]
```

#### Build Image

```bash
cd testing/
docker build -t my-distro-test .
```

### Testing Workflow

#### Test System Update Script

```bash
# Run container with my-distro mounted
docker run --rm -it \
    -v $(pwd):/workspace \
    my-distro-test bash

# Inside container:
# Simulate installing my-distro
mkdir -p /opt/my-distro
cp -r /workspace/* /opt/my-distro/

# Add to PATH
export PATH="/opt/my-distro/bin:$PATH"

# Test system update
cd /opt/my-distro/bin
bash -x ./my-distro-update-system

# Check results
ls -la /etc/xdg/
cat /opt/my-distro/version
```

#### Test User Update Script

```bash
# Continue in container from above

# Switch to test user
su - alice

# Test user update
my-distro-update-user

# Check results
ls -la ~/.config/
cat ~/.local/share/my-distro-state/version

# Exit back to root
exit
```

#### Test Multi-User Scenario

```bash
# In container as root

# Update system
/opt/my-distro/bin/my-distro-update-system

# Update each user
for user in alice bob charlie; do
    echo "=== Testing user: $user ==="
    su - $user -c "my-distro-update-user"
    echo ""
done

# Verify each user's state
for user in alice bob charlie; do
    echo "User $user version:"
    su - $user -c "cat ~/.local/share/my-distro-state/version"
done
```

#### Test Migration Scripts

```bash
# In container

# Manually set old version
su - alice
echo "3" > ~/.local/share/my-distro-state/version
exit

# Copy dotfiles manually (simulate user on v3)
mkdir -p /home/alice/.config
cp -r /opt/my-distro/user/dotfiles/* /home/alice/.config/
chown -R alice:alice /home/alice/.config

# Update to trigger migrations
su - alice -c "my-distro-update-user"

# Verify migrations ran
su - alice -c "cat ~/.config/fish/config.fish | grep 'my-distro aliases'"
```

### Docker Testing Script

Create `testing/docker-test.sh`:

```bash
#!/bin/bash
set -e

echo "Building Docker test image..."
docker build -t my-distro-test testing/

echo "Running tests in Docker..."
docker run --rm \
    -v $(pwd):/workspace \
    my-distro-test \
    bash -c '
        set -e

        # Install my-distro
        echo "Installing my-distro..."
        mkdir -p /opt/my-distro
        cp -r /workspace/* /opt/my-distro/
        export PATH="/opt/my-distro/bin:$PATH"

        # Test system update
        echo "Testing system update..."
        cd /opt/my-distro
        # Simulate git repo (no network in test)
        git init
        git add .
        git commit -m "Initial"

        # Run system update (skip pacman, test our logic)
        # TODO: Mock pacman commands

        # Test user updates
        echo "Testing user updates..."
        for user in alice bob charlie; do
            echo "  Testing $user..."
            su - $user -c "my-distro-update-user" || exit 1
            version=$(su - $user -c "cat ~/.local/share/my-distro-state/version")
            echo "    $user at version $version"
        done

        echo "All tests passed!"
    '
```

Run tests:

```bash
chmod +x testing/docker-test.sh
./testing/docker-test.sh
```

### Quick Iteration Loop

During development:

```bash
# Edit scripts
vim bin/my-distro-update-user

# Test immediately
docker run --rm -it \
    -v $(pwd):/workspace \
    my-distro-test \
    bash -c '
        mkdir -p /opt/my-distro
        cp -r /workspace/* /opt/my-distro/
        su - alice -c "bash -x /opt/my-distro/bin/my-distro-update-user"
    '

# Iterate quickly!
```

---

## QEMU Full System Testing

### Purpose

QEMU provides a complete Arch Linux system for full integration testing, including boot process, systemd services, and complete package management.

### Advantages

- ✅ Complete system: Real systemd, pacman, everything
- ✅ Realistic: Exact production environment
- ✅ Snapshot support: Save/restore states
- ✅ Full testing: Boot to shutdown

### Limitations

- ❌ Slower: VM boot time, full package installs
- ❌ More resources: Requires CPU, RAM, disk
- ❌ Setup overhead: Need to install Arch first

### Initial Setup

#### Install Arch in QEMU

```bash
# Create disk image (20GB)
qemu-img create -f qcow2 arch-test.qcow2 20G

# Download Arch ISO
wget https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso

# Boot from ISO
qemu-system-x86_64 \
    -m 4G \
    -smp 2 \
    -cpu host \
    -enable-kvm \
    -cdrom archlinux-x86_64.iso \
    -drive file=arch-test.qcow2,format=qcow2 \
    -boot d \
    -nic user,hostfwd=tcp::2222-:22

# Inside VM: Install Arch Linux
# Follow standard installation guide:
# - Partition disk
# - Install base system
# - Configure bootloader
# - Enable SSH for remote access
```

#### Install my-distro

```bash
# SSH into VM
ssh -p 2222 root@localhost

# Clone my-distro (use your repo URL)
git clone https://github.com/user/my-distro.git /opt/my-distro

# Add to PATH
echo 'export PATH="/opt/my-distro/bin:$PATH"' >> /etc/profile
source /etc/profile

# Run initial system update
my-distro-update-system

# Create test users
useradd -m -G wheel alice
useradd -m -G wheel bob
useradd -m charlie
passwd alice  # Set password for SSH login
passwd bob
passwd charlie
```

#### Create Baseline Snapshot

```bash
# Shutdown VM gracefully
ssh -p 2222 root@localhost 'shutdown -h now'

# Create snapshot (baseline)
qemu-img snapshot -c baseline arch-test.qcow2

# List snapshots
qemu-img snapshot -l arch-test.qcow2
```

### Testing Workflow

#### Boot VM

```bash
# Boot VM (with SSH port forwarding)
qemu-system-x86_64 \
    -m 4G \
    -smp 2 \
    -cpu host \
    -enable-kvm \
    -drive file=arch-test.qcow2,format=qcow2 \
    -nic user,hostfwd=tcp::2222-:22 \
    -nographic  # or remove for GUI
```

#### Test System Update

```bash
# SSH as root
ssh -p 2222 root@localhost

# Ensure repo is latest (for testing, use local copy)
cd /opt/my-distro
git pull

# Run system update
my-distro-update-system

# Verify
cat /opt/my-distro/version
ls -la /etc/xdg/
pacman -Qq | grep -E 'neovim|fish|kitty'  # Check packages installed
```

#### Test User Updates

```bash
# SSH as alice
ssh -p 2222 alice@localhost

# Run user update
my-distro-update-user

# Verify
cat ~/.local/share/my-distro-state/version
ls -la ~/.config/
cat ~/.config/fish/config.fish

# Test running applications
fish
nvim --version
```

#### Test Multi-User Scenario

```bash
# As root
ssh -p 2222 root@localhost

# Update all users
for user in alice bob charlie; do
    sudo -u $user my-distro-update-user
done

# Verify
for user in alice bob charlie; do
    echo "$user version:"
    sudo -u $user cat /home/$user/.local/share/my-distro-state/version
done
```

### QEMU Testing Script

Create `testing/qemu-test.sh`:

```bash
#!/bin/bash
set -e

VM_IMAGE="arch-test.qcow2"
SSH_PORT=2222
SNAPSHOT_NAME="test-$(date +%Y%m%d-%H%M%S)"

# Restore baseline snapshot
echo "Restoring baseline snapshot..."
qemu-img snapshot -a baseline "$VM_IMAGE"

# Start VM in background
echo "Starting VM..."
qemu-system-x86_64 \
    -m 4G \
    -smp 2 \
    -cpu host \
    -enable-kvm \
    -drive file="$VM_IMAGE",format=qcow2 \
    -nic user,hostfwd=tcp::$SSH_PORT-:22 \
    -display none \
    -daemonize \
    -pidfile vm.pid

# Wait for SSH
echo "Waiting for VM to boot..."
for i in {1..30}; do
    if ssh -p $SSH_PORT -o StrictHostKeyChecking=no \
           -o UserKnownHostsFile=/dev/null \
           root@localhost 'echo ready' 2>/dev/null; then
        break
    fi
    sleep 2
done

# Run tests
echo "Running tests..."
ssh -p $SSH_PORT root@localhost << 'EOF'
    set -e

    # Update my-distro repo (copy from host - see below)
    cd /opt/my-distro

    # Test system update
    echo "Testing system update..."
    my-distro-update-system

    # Test user updates
    echo "Testing user updates..."
    for user in alice bob charlie; do
        sudo -u $user my-distro-update-user
    done

    # Verify
    echo "Verifying..."
    version=$(cat /opt/my-distro/version)
    echo "System at version: $version"

    for user in alice bob charlie; do
        user_version=$(sudo -u $user cat /home/$user/.local/share/my-distro-state/version)
        echo "$user at version: $user_version"
    done
EOF

# Shutdown VM
echo "Shutting down VM..."
ssh -p $SSH_PORT root@localhost 'shutdown -h now' || true

# Wait for shutdown
sleep 5

# Create snapshot of test result
echo "Creating snapshot: $SNAPSHOT_NAME"
qemu-img snapshot -c "$SNAPSHOT_NAME" "$VM_IMAGE"

echo "Test complete!"
```

---

## Snapshot-Based Testing

### Purpose

Snapshots allow you to save VM state at specific points and quickly return to that state for iterative testing.

### Snapshot Strategy

```
baseline
  ├─ fresh-install (system v1, users v0)
  │
  ├─ system-v2 (system updated to v2)
  │   ├─ alice-v2 (alice updated)
  │   └─ mixed-versions (alice v2, bob v1, charlie v0)
  │
  └─ system-v5 (latest system)
      └─ all-users-v5 (all users updated)
```

### Creating Snapshots

```bash
# After fresh install
qemu-img snapshot -c fresh-install arch-test.qcow2

# After system update to v2
qemu-img snapshot -c system-v2 arch-test.qcow2

# After updating alice
qemu-img snapshot -c alice-updated arch-test.qcow2
```

### Using Snapshots

```bash
# List available snapshots
qemu-img snapshot -l arch-test.qcow2

# Apply (restore) a snapshot
qemu-img snapshot -a system-v2 arch-test.qcow2

# Boot VM (now at system-v2 state)
qemu-system-x86_64 -drive file=arch-test.qcow2,format=qcow2 ...

# Test update from v2 to v5
# ...

# Restore again to test different scenario
qemu-img snapshot -a system-v2 arch-test.qcow2
```

### Snapshot Testing Workflow

```bash
# Test updating from various states

# Test 1: Fresh install → latest
qemu-img snapshot -a fresh-install arch-test.qcow2
# Boot, test updates, verify

# Test 2: v2 → latest
qemu-img snapshot -a system-v2 arch-test.qcow2
# Boot, test updates, verify

# Test 3: Mixed user versions
qemu-img snapshot -a mixed-versions arch-test.qcow2
# Boot, test individual user updates, verify
```

### Snapshot Testing Script

Create `testing/snapshot-test.sh`:

```bash
#!/bin/bash
set -e

VM_IMAGE="arch-test.qcow2"
SNAPSHOT=$1

if [[ -z "$SNAPSHOT" ]]; then
    echo "Usage: $0 <snapshot-name>"
    echo "Available snapshots:"
    qemu-img snapshot -l "$VM_IMAGE"
    exit 1
fi

# Restore snapshot
echo "Restoring snapshot: $SNAPSHOT"
qemu-img snapshot -a "$SNAPSHOT" "$VM_IMAGE"

# Boot VM
echo "Booting VM..."
qemu-system-x86_64 \
    -m 4G \
    -cpu host \
    -enable-kvm \
    -drive file="$VM_IMAGE",format=qcow2 \
    -nic user,hostfwd=tcp::2222-:22

# VM stays open for manual testing
```

---

## Multi-User Testing

### Test Scenarios

#### Scenario 1: Three Users, Different Update States

```bash
# Setup
# - System at v5
# - alice: v5 (up-to-date)
# - bob: v3 (two versions behind)
# - charlie: v0 (never updated)

# Test: System updates to v6

# Expected results:
# - alice updates v5 → v6 (runs migration 006)
# - bob updates v3 → v6 (runs migrations 004, 005, 006)
# - charlie updates v0 → v6 (first-run copy, no migrations)

# Verification:
for user in alice bob charlie; do
    sudo -u $user my-distro-update-user
    version=$(sudo -u $user cat ~/.local/share/my-distro-state/version)
    echo "$user: $version (expected: 6)"

    # Check configs exist
    sudo -u $user ls -la /home/$user/.config/
done
```

#### Scenario 2: Concurrent User Updates

```bash
# Test: Multiple users update simultaneously
# (Shouldn't conflict - each user has own state)

# Run updates in parallel
for user in alice bob charlie; do
    sudo -u $user my-distro-update-user &
done

# Wait for all to complete
wait

# Verify all succeeded
for user in alice bob charlie; do
    version=$(sudo -u $user cat ~/.local/share/my-distro-state/version)
    echo "$user: $version"
done
```

#### Scenario 3: User Without Home Directory

```bash
# Test: System user (nologin) doesn't break

# Create system user
useradd -r -s /usr/sbin/nologin systemuser

# Attempt user update (should handle gracefully)
sudo -u systemuser my-distro-update-user || echo "Expected to fail gracefully"
```

#### Scenario 4: New User on Updated System

```bash
# System at v6, create brand new user

# Create user
useradd -m -G wheel diane
passwd diane

# User runs update for first time
sudo -u diane my-distro-update-user

# Verify: diane should be at v6 immediately (no migrations)
version=$(sudo -u diane cat /home/diane/.local/share/my-distro-state/version)
echo "diane: $version (expected: 6)"

# Verify configs copied
sudo -u diane ls -la /home/diane/.config/
```

### Multi-User Test Script

Create `testing/multi-user-test.sh`:

```bash
#!/bin/bash
set -e

echo "=== Multi-User Testing ==="

# Create test users with different states
echo "Setting up test users..."

# User 1: Up-to-date
sudo -u alice my-distro-update-user
echo "Alice state:"
sudo -u alice cat ~/.local/share/my-distro-state/version

# User 2: Old version (manually set)
sudo -u bob bash -c "mkdir -p ~/.local/share/my-distro-state && echo '3' > ~/.local/share/my-distro-state/version"
echo "Bob state: 3 (manually set)"

# User 3: Never updated (v0)
sudo -u charlie bash -c "rm -rf ~/.local/share/my-distro-state ~/.config/fish ~/.config/nvim"
echo "Charlie state: fresh (no configs)"

# Test: Update system
echo ""
echo "Updating system..."
my-distro-update-system

# Test: Each user updates
echo ""
echo "Updating users..."
for user in alice bob charlie; do
    echo "  Updating $user..."
    sudo -u $user my-distro-update-user
done

# Verify
echo ""
echo "=== Verification ==="
latest=$(cat /opt/my-distro/version)
for user in alice bob charlie; do
    version=$(sudo -u $user cat /home/$user/.local/share/my-distro-state/version 2>/dev/null || echo "ERROR")
    if [[ "$version" == "$latest" ]]; then
        echo "✓ $user: $version (correct)"
    else
        echo "✗ $user: $version (expected: $latest)"
    fi
done

echo ""
echo "=== Test Complete ==="
```

---

## Migration Testing

### Test Cases

#### Test 1: Sequential Migrations

```bash
# Setup: User at v1, system at v5
echo "1" > ~/.local/share/my-distro-state/version

# Run update
my-distro-update-user

# Verify: Migrations 2, 3, 4, 5 all ran
# Check each migration's effects:
# - v2: tmux config exists
# - v3: fish aliases exist
# - v4: nvim plugin fixed
# - v5: completions directory exists
```

#### Test 2: Idempotent Migrations

```bash
# Test: Running same migration twice should be safe

# User at v2
echo "2" > ~/.local/share/my-distro-state/version

# Run update to v3
my-distro-update-user

# Manually re-run migration 003
bash /opt/my-distro/user/migrations/003-update-fish-aliases.sh

# Verify: No duplicates, no errors
grep -c "# my-distro aliases v3" ~/.config/fish/config.fish
# Should be 1, not 2
```

#### Test 3: Migration Failure Handling

```bash
# Test: If migration fails, user version not updated

# Create migration that will fail
cat > /opt/my-distro/user/migrations/999-will-fail.sh << 'EOF'
#!/bin/bash
echo "This migration will fail"
exit 1
EOF

# User at v1, system at v999
echo "999" > /opt/my-distro/version

# Run update (should fail)
my-distro-update-user || echo "Expected failure"

# Verify: User version not updated
version=$(cat ~/.local/share/my-distro-state/version)
echo "User version: $version (should not be 999)"
```

#### Test 4: Large Version Jump

```bash
# Test: Jumping many versions (v1 → v10)

# Setup
echo "1" > ~/.local/share/my-distro-state/version
echo "10" > /opt/my-distro/version

# Ensure migrations 002-010 exist
for v in {2..10}; do
    cat > /opt/my-distro/user/migrations/$(printf '%03d' $v)-test.sh << 'EOF'
#!/bin/bash
echo "Migration $v"
touch ~/.config/migration-$v-ran
EOF
done

# Run update
my-distro-update-user

# Verify: All migrations ran
for v in {2..10}; do
    if [[ -f ~/.config/migration-$v-ran ]]; then
        echo "✓ Migration $v ran"
    else
        echo "✗ Migration $v DID NOT RUN"
    fi
done
```

### Migration Test Script

Create `testing/migration-test.sh`:

```bash
#!/bin/bash
set -e

TEST_USER="alice"
STATE_FILE="/home/$TEST_USER/.local/share/my-distro-state/version"

echo "=== Migration Testing ==="

# Test 1: Sequential migrations
echo ""
echo "Test 1: Sequential migrations (1 → 5)"
sudo -u $TEST_USER bash -c "echo '1' > $STATE_FILE"
sudo -u $TEST_USER my-distro-update-user
version=$(sudo -u $TEST_USER cat $STATE_FILE)
[[ "$version" == "5" ]] && echo "✓ PASS" || echo "✗ FAIL"

# Test 2: Idempotent (run twice)
echo ""
echo "Test 2: Idempotent migrations"
sudo -u $TEST_USER bash -c "echo '2' > $STATE_FILE"
sudo -u $TEST_USER my-distro-update-user
before=$(sudo -u $TEST_USER cat ~/.config/fish/config.fish | md5sum)
sudo -u $TEST_USER bash -c "echo '2' > $STATE_FILE"
sudo -u $TEST_USER my-distro-update-user
after=$(sudo -u $TEST_USER cat ~/.config/fish/config.fish | md5sum)
[[ "$before" == "$after" ]] && echo "✓ PASS" || echo "✗ FAIL"

# Test 3: Large jump (1 → current)
echo ""
echo "Test 3: Large version jump"
sudo -u $TEST_USER bash -c "echo '1' > $STATE_FILE"
sudo -u $TEST_USER my-distro-update-user
latest=$(cat /opt/my-distro/version)
version=$(sudo -u $TEST_USER cat $STATE_FILE)
[[ "$version" == "$latest" ]] && echo "✓ PASS" || echo "✗ FAIL"

echo ""
echo "=== Tests Complete ==="
```

---

## Testing Checklist

### Before Release

- [ ] **Docker Tests**
  - [ ] System update script runs without errors
  - [ ] User update script runs without errors
  - [ ] Multi-user updates work correctly
  - [ ] Migrations execute sequentially
  - [ ] First-run initialization works

- [ ] **QEMU Full System Tests**
  - [ ] Fresh Arch install → my-distro install → system update
  - [ ] User updates (alice, bob, charlie)
  - [ ] System services work (if any)
  - [ ] Packages install correctly
  - [ ] System configs applied to /etc/xdg/

- [ ] **Snapshot Tests**
  - [ ] v1 → latest upgrade path
  - [ ] v2 → latest upgrade path
  - [ ] Mixed version users upgrade correctly

- [ ] **Multi-User Tests**
  - [ ] Three users at different versions
  - [ ] Concurrent user updates
  - [ ] New user on updated system
  - [ ] User without home directory (graceful fail)

- [ ] **Migration Tests**
  - [ ] All migrations run sequentially
  - [ ] Migrations are idempotent
  - [ ] Large version jumps work
  - [ ] Failed migration doesn't update version

- [ ] **Edge Cases**
  - [ ] System update with no network (git pull fails gracefully)
  - [ ] User update when /opt/my-distro/ is unreadable
  - [ ] Lock file prevents concurrent system updates
  - [ ] Empty packages.list doesn't break system update

### Manual Verification

After automated tests pass, manually verify:

- [ ] User configs are readable and sensible
- [ ] Applications (nvim, fish, etc.) start correctly
- [ ] No password/secrets in configs
- [ ] Documentation is up-to-date
- [ ] Version numbers are correct

---

## Summary

### Quick Development Iteration

```bash
# Edit scripts
vim bin/my-distro-update-user

# Test in Docker (1-2 minutes)
docker run --rm -it -v $(pwd):/workspace my-distro-test bash
```

### Pre-Commit Testing

```bash
# Run Docker tests
./testing/docker-test.sh

# Run migration tests
./testing/migration-test.sh
```

### Pre-Release Testing

```bash
# Full QEMU test
./testing/qemu-test.sh

# Snapshot-based regression tests
./testing/snapshot-test.sh fresh-install
./testing/snapshot-test.sh system-v2
./testing/snapshot-test.sh mixed-versions
```

### Continuous Integration

For automated testing, set up CI pipeline:

```yaml
# .github/workflows/test.yml
name: Test my-distro

on: [push, pull_request]

jobs:
  docker-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build test image
        run: docker build -t my-distro-test testing/
      - name: Run tests
        run: ./testing/docker-test.sh
```

This ensures every commit is tested automatically!
