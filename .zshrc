alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
alias dotfiles-code='GIT_DIR=$HOME/.dotfiles GIT_WORK_TREE=$HOME code ~'

# Source zsh plugins
if [[ "$OSTYPE" == "darwin"* ]]; then
    ZSH_PLUGIN_PREFIX=$(brew --prefix)
else
    ZSH_PLUGIN_PREFIX="~/.config/zsh/plugins"
fi


# Load completions
FPATH=$ZSH_PLUGIN_PREFIX/share/zsh-completions:$FPATH
autoload -Uz compinit && compinit

source $ZSH_PLUGIN_PREFIX/share/fzf-tab/fzf-tab.zsh
#source $ZSH_PLUGIN_PREFIX/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh
source $ZSH_PLUGIN_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source $ZSH_PLUGIN_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Source .config files
source ~/.config/zsh/oh-my-posh/oh-my-posh.zsh
source ~/.config/fzf/fzf.zsh


# History
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no

# Up arrow to trigger the fzf history widget
bindkey '^[[A' fzf-history-widget   # Up arrow
bindkey '^[OA' fzf-history-widget   # Up arrow (alternate escape sequence)
