# Keep history in the usual place (/etc/zshrc would point it at ZDOTDIR)
HISTFILE="$HOME/.zsh_history"

[[ -f "$HOME/.zshrc" ]] && source "$HOME/.zshrc"

# --- NASH overrides: everything green ---
PROMPT='%B%F{green}%n%f%b %F{22}❯%f %F{green}%1~%f %B%F{green}❯%f%b '
RPROMPT='%F{22}%*%f'

export CLICOLOR=1
export LSCOLORS=cxcxcxcxcxcxcxcxcxcxcx   # ls -G: every file type green
export GREP_COLORS='mt=01;32'
