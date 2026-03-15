alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
alias dotfiles-code='GIT_DIR=$HOME/.dotfiles GIT_WORK_TREE=$HOME code ~'

# Source zsh plugins
if [[ "$OSTYPE" == "darwin"* ]]; then
    ZSH_PLUGIN_PREFIX=$(brew --prefix)
else
    ZSH_PLUGIN_PREFIX="~/.config/zsh/plugins"
fi
source $ZSH_PLUGIN_PREFIX/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh
source $ZSH_PLUGIN_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source $ZSH_PLUGIN_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Source .config files
source ~/.config/zsh/oh-my-posh/oh-my-posh.zsh
source ~/.config/fzf/fzf.zsh

_smart_tab() {
  if [[ -n $POSTDISPLAY ]]; then
    # There's an autosuggestion — accept it
    zle autosuggest-accept
  else
    # No suggestion — open completion menu
    zle menu-select
  fi
}
zle -N _smart_tab
bindkey '^I' _smart_tab

