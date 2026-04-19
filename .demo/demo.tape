# demo.tape — VHS recording script for README terminal demo
# Usage: vhs .demo/demo.tape
# Requires: vhs, zsh, oh-my-posh, fzf, bat, fd, rg, MesloLGS Nerd Font

Output .demo/demo.gif

Require zsh
Require fzf
Require bat

Set Shell "zsh"
Set FontFamily "MesloLGS Nerd Font"
Set FontSize 16
Set Width 1300
Set Height 820
Set Padding 24
Set WindowBar Colorful
Set WindowBarSize 44
Set TypingSpeed 45ms
Set PlaybackSpeed 1.0
Set Theme "Monokai Pro (Filter Octagon)"
Set CursorBlink true

# ─── Off-screen setup ───────────────────────────────────────────────
Hide
Type "source ~/.zshrc 2>/dev/null"
Enter
Sleep 1500ms
Type "cd ~/.dotfiles"
Enter
Sleep 300ms
# Override git identity via env vars (doesn't touch real config)
Type "export GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=user.name GIT_CONFIG_VALUE_0=user GIT_CONFIG_KEY_1=user.email GIT_CONFIG_VALUE_1=user@example.com"
Enter
Sleep 300ms
# Seed history so autosuggestions have something to offer later
Type "dotfiles log --oneline -5"
Enter
Sleep 200ms
Type "clear"
Enter
Sleep 500ms
Show

# ─── 1. Health check ────────────────────────────────────────────────
Type "dotfiles doctor"
Sleep 700ms
Enter
Sleep 3s

# ─── 2. Recent changes via autosuggestion ───────────────────────────
# Type a prefix matching seeded history; plugin shows the rest in grey.
Type@80ms "dotfiles l"
Sleep 500ms
# Accept the suggestion with →
Right
Sleep 1s
Enter
Sleep 2s

Type "clear"
Enter
Sleep 500ms

# ─── 3. fzf-tab completion with file preview on <Tab> ───────────────
Type "cat installers/"
Sleep 400ms
# Tab opens the fzf-tab picker with a side-pane bat preview
Tab
Sleep 100ms
# Cycle through 5 entries — pause 2s on each to show preview content
Down
Sleep 100ms
Down
Sleep 1s
Down
Sleep 1s
Down
Sleep 1s
Escape
Sleep 600ms
Ctrl+U
Sleep 1s
