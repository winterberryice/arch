# my-distro system-wide fish shell configuration
# Applied to /etc/xdg/fish/config.fish
# Users can override in ~/.config/fish/config.fish

# System-wide defaults
set fish_greeting ""  # Disable default greeting (users can customize)

# System PATH
if test -d /opt/my-distro/bin
    set -gx PATH /opt/my-distro/bin $PATH
end

# TODO: Add system-wide fish shell defaults here
# Keep minimal - users should customize in their own ~/.config/fish/
