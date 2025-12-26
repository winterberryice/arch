#!/bin/bash
# --- SYSTEM CONFIGURATION SCRIPT ---
# Configures the newly installed Arch Linux system.
# Run this script from inside the chroot as the root user.

# --- NOTE ---
# This script uses constants defined below. The `USERNAME` constant should
# match the one you exported as an environment variable for the first script
# to ensure files are placed in the correct home directory.

# Exit immediately if a command exits with a non-zero status.
set -e

# --- 1. DEFINE SYSTEM CONSTANTS ---
readonly HOSTNAME="archlinux"
readonly USERNAME="january" # This must match the variable from the first script
readonly TIMEZONE="Europe/Warsaw"
readonly LOCALE_EN="en_US.UTF-8"
readonly LOCALE_PL="pl_PL.UTF-8"

# --- 2. TIMEZONE, CLOCK, AND NETWORK TIME SYNC ---
echo ">>> Configuring time and date..."
# Set the system timezone
ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
# Set the hardware clock from the system clock
hwclock --systohc
# Enable Network Time Protocol (NTP) to sync time with web servers
timedatectl set-ntp true
echo "✅ Time configured and NTP enabled."

# --- 3. LOCALIZATION AND LANGUAGE ---
echo ">>> Configuring system locale to ${LOCALE_EN} and ${LOCALE_PL}..."
# Uncomment the desired locales in the locale generation file
sed -i "/^#${LOCALE_EN}/s/^#//g" /etc/locale.gen
sed -i "/^#${LOCALE_PL}/s/^#//g" /etc/locale.gen
# Generate the locales
locale-gen
# Set the primary system language
echo "LANG=${LOCALE_EN}" > /etc/locale.conf
echo "✅ Locales generated."

# --- 4. HOSTNAME ---
echo ">>> Setting hostname to '${HOSTNAME}'..."
echo "${HOSTNAME}" > /etc/hostname

# --- 5. RECREATE INITRAMFS ---
echo ">>> Recreating initramfs (mkinitcpio)..."
mkinitcpio -P

# --- 6. SET ROOT PASSWORD ---
echo "---"
echo ">>> Please set the root password now."
passwd
echo "---"

# --- 7. GRUB BOOTLOADER INSTALLATION ---
echo ">>> Installing and configuring GRUB bootloader..."
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=ARCH
grub-mkconfig -o /boot/grub/grub.cfg

# --- 8. CREATE USER AND SET PASSWORD ---
echo ">>> Creating user '${USERNAME}'..."
useradd -m -G wheel,audio,video,storage -s /bin/bash "${USERNAME}"
echo "---"
echo ">>> Please set the password for ${USERNAME}."
passwd "${USERNAME}"
echo "---"

# --- 9. INSTALL DESKTOP, DRIVERS, AND UTILITIES ---
echo ">>> Installing core packages (COSMIC, NVIDIA, Bluetooth, etc.)..."
pacman -S --noconfirm --needed \
    cosmic-epoch cosmic-greeter pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber \
    sudo base-devel git \
    nvidia nvidia-settings nvidia-utils \
    snapper snap-pac \
    bluez bluez-utils \
    noto-fonts ttf-dejavu ttf-liberation noto-fonts-emoji

# --- 10. ENABLE SYSTEM SERVICES ---
echo ">>> Enabling essential system services..."
systemctl enable cosmic-greeter.service
systemctl enable NetworkManager.service
systemctl enable bluetooth.service

# Enable PipeWire audio services for the user
sudo -u ${USERNAME} systemctl --user enable pipewire pipewire-pulse wireplumber

# --- 11. CONFIGURE SUDO ---
echo ">>> Configuring sudo to allow users in the 'wheel' group..."
# This is the standard, secure way to grant admin rights
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

# --- 12. INSTALL AUR HELPER (YAY) & PACKAGES ---
echo ">>> Installing AUR helper (yay) and snapper-rollback..."
# This block runs commands as the new user to avoid permission issues
sudo -u ${USERNAME} bash <<EOT
set -e
cd "/home/${USERNAME}"
if ! command -v yay &>/dev/null; then
    echo "yay not found, installing..."
    git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin
    makepkg -si --noconfirm
    cd ..
    rm -rf yay-bin
fi
yay -S --noconfirm snapper-rollback
EOT

# --- 13. FINAL SNAPPER CONFIGURATION ---
echo ">>> Setting up Snapper configurations for root and home..."
snapper -c root create-config /
snapper -c home create-config /home
# Create initial baseline snapshots
snapper -c root create -d "baseline_root_install"
snapper -c home create -d "baseline_home_install"
echo "✅ Snapper configured with root and home profiles."

echo ""
echo "✅🚀 Installation and configuration complete!"
echo "You can now type 'exit', then 'umount -a', and finally 'reboot'."
