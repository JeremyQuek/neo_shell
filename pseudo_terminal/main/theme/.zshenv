# NASH-only zsh config. main.js points ZDOTDIR here, so zsh reads these
# files instead of ~/.z*. Each one loads the real file from $HOME first,
# so your normal setup still applies — nothing in $HOME is modified.
[[ -f "$HOME/.zshenv" ]] && source "$HOME/.zshenv"
