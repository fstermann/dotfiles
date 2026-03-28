dotfiles() {
  case "$1" in
    update)  bash "$HOME/.dotfiles/installers/update.sh" ;;
    doctor)  bash "$HOME/.dotfiles/installers/doctor.sh" ;;
    install) bash "$HOME/.dotfiles/install.sh" ;;
    *)       git --git-dir="$HOME/.dotfiles/.git" --work-tree="$HOME/.dotfiles" "$@" ;;
  esac
}

# Source zsh plugins
if [[ "$OSTYPE" == "darwin"* ]]; then
    ZSH_PLUGIN_PREFIX=$(brew --prefix)/share
else
    eval "$(~/homebrew/bin/brew shellenv zsh)"
    ZSH_PLUGIN_PREFIX="$HOME/.config/zsh/plugins"
fi


# Load completions
FPATH=$ZSH_PLUGIN_PREFIX/zsh-completions:$FPATH
autoload -Uz compinit && compinit

source $ZSH_PLUGIN_PREFIX/fzf-tab/fzf-tab.zsh
#source $ZSH_PLUGIN_PREFIX/zsh-autocomplete/zsh-autocomplete.plugin.zsh
source $ZSH_PLUGIN_PREFIX/zsh-autosuggestions/zsh-autosuggestions.zsh
source $ZSH_PLUGIN_PREFIX/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

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


_git_remerge ()
{
	__git_complete_strategy && return
	case "$cur" in
	--*)
		__gitcomp_builtin merge
		return
	esac
	__git_complete_refs
}

# Machine-local overrides (not tracked in the repo)
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
