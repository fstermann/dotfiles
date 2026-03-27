if command -v oh-my-posh &>/dev/null; then
    eval "$(oh-my-posh init zsh --config ~/.config/zsh/oh-my-posh/pure.toml)"
else
    source ~/.config/zsh/oh-my-posh/fallback-prompt.zsh
fi
