# demo.tape — VHS recording script for README terminal screenshot
# Usage: vhs .demo/demo.tape
# Requires: vhs, zsh, oh-my-posh, MesloLGS Nerd Font

Output .demo/demo.gif

Require zsh

Set Shell "zsh"
Set FontFamily "MesloLGS Nerd Font"
Set FontSize 14
Set Width 1000
Set Height 550
Set Padding 20
Set WindowBar Colorful
Set WindowBarSize 40
Set TypingSpeed 40ms
Set Theme "Monokai Pro (Filter Octagon)"
Set CursorBlink false

# Set up demo environment off-screen
Hide
Type "source ~/.zshrc 2>/dev/null"
Enter
Sleep 2s
Type "cd ~/.dotfiles"
Enter
Sleep 500ms
# Override git identity via env vars (doesn't touch real config)
Type "export GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=user.name GIT_CONFIG_VALUE_0=user GIT_CONFIG_KEY_1=user.email GIT_CONFIG_VALUE_1=user@example.com"
Enter
Sleep 1s
Show

# Clear screen to remove any setup artifacts
Ctrl+L
Sleep 1s

# Run the health check
Type "dotfiles doctor"
Sleep 500ms
Enter
Sleep 2s

# Show git status of the dotfiles repo
Type "dotfiles status -s"
Sleep 500ms
Enter
Sleep 2s

# Show a config file with bat
Type "bat --style=header,grid ~/.config/fzf/fzf.zsh"
Sleep 500ms
Enter
Sleep 3s
