# Wintarch-specific zsh configuration

# Environment
export EDITOR="${EDITOR:-vim}"
export VISUAL="${VISUAL:-vim}"

# Path additions (if not already present)
[[ ":$PATH:" != *":/usr/local/bin:"* ]] && export PATH="/usr/local/bin:$PATH"
