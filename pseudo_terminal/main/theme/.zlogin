[[ -f "$HOME/.zlogin" ]] && source "$HOME/.zlogin"
# All rc files are read; don't pass ZDOTDIR to programs started from here (e.g. `code .`)
unset ZDOTDIR
