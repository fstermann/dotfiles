# On Linux fzf is installed via git clone to ~/.fzf; ensure the binary is on PATH.
if [[ "$OSTYPE" != "darwin"* ]]; then
    export PATH="$HOME/.fzf/bin:$PATH"
fi

# Set up fzf key bindings and fuzzy completion
if command -v fzf &>/dev/null; then
    source <(fzf --zsh)
fi

# Show hidden files in tab completions (cat, ls, etc.)
setopt globdots

export FZF_DEFAULT_COMMAND='fd --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND='rg --files --hidden --follow --glob "!.git/*"'
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'

export FZF_DEFAULT_OPTS="\
--layout=reverse \
--height=80%"

export FZF_CTRL_T_OPTS="\
--preview '~/.config/fzf/preview.zsh {}'"


# Scheme name: Monokai
# Scheme system: base16
# Scheme author: Wimer Hazenberg (http://www.monokai.nl)
# Template author: Tinted Theming (https://github.com/tinted-theming)
_gen_fzf_default_opts() {

local color00='#272822'
local color01='#383830'
local color02='#49483e'
local color03='#75715e'
local color04='#a59f85'
local color05='#f8f8f2'
local color06='#f5f4f1'
local color07='#f9f8f5'
local color08='#f92672'
local color09='#fd971f'
local color0A='#f4bf75'
local color0B='#a6e22e'
local color0C='#a1efe4'
local color0D='#66d9ef'
local color0E='#ae81ff'
local color0F='#cc6633'

export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS"\
" --color=fg:$color04,header:$color0D,info:$color0A,pointer:$color0C"\
" --color=marker:$color0C,fg+:$color06,prompt:$color0A,hl+:$color0D"
}
#" --color=bg+:$color01,bg:$color00,spinner:$color0C,hl:$color0D"\
_gen_fzf_default_opts

# Check if needed after installation
if [[ "$OSTYPE" != "darwin"* ]]; then
    alias bat="batcat"
fi

zstyle ':fzf-tab:*' fzf-preview '~/.config/fzf/preview.zsh ${realpath:-$word}'
zstyle ':fzf-tab:complete:cd:*' fzf-preview '~/.config/fzf/preview.zsh ${realpath:-$word}'
zstyle ':fzf-tab:complete:ls:*' fzf-preview '~/.config/fzf/preview.zsh ${realpath:-$word}'
zstyle ':fzf-tab:complete:cat:*' fzf-preview '~/.config/fzf/preview.zsh ${realpath:-$word}'
zstyle ':fzf-tab:*' fzf-flags '--preview-window=right:40%' '--min-height=20'
zstyle ':fzf-tab:complete:cd:*' continuous-trigger '/'
zstyle ':fzf-tab:*' use-fzf-default-opts yes
