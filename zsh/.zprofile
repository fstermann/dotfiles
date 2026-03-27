if [[ "$OSTYPE" == "darwin"* ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv zsh)"
else
    eval "$(~/homebrew/bin/brew shellenv zsh)"
fi
