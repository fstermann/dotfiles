autoload -U promptinit; promptinit
prompt pure

alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
alias dotfiles-code='GIT_DIR=$HOME/.dotfiles GIT_WORK_TREE=$HOME code ~'

source /opt/homebrew/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh