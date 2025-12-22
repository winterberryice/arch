# my-distro fish shell configuration
# User dotfile template

# Greeting
set fish_greeting "Welcome to my-distro!"

# Aliases
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'

# Git aliases
alias gs='git status'
alias gd='git diff'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph'

# Add /opt/my-distro/bin to PATH if not already there
if not contains /opt/my-distro/bin $PATH
    set -gx PATH /opt/my-distro/bin $PATH
end

# TODO: Add your fish shell customizations here
