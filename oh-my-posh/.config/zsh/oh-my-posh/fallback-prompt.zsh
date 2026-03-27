# fallback-prompt.zsh
# Pure Zsh prompt — used when oh-my-posh is not available.
# Matches the style of pure.toml: Nord palette, ❯ symbol, git branch on the same line.

setopt PROMPT_SUBST

# True-color ANSI escapes wrapped in %{..%} so Zsh counts them as zero-width.
_p_red=$'%{\e[38;2;191;97;106m%}'     # #BF616A — username / error indicator
_p_blue=$'%{\e[38;2;129;161;193m%}'   # #81A1C1 — path
_p_gray=$'%{\e[38;2;108;108;108m%}'   # #6C6C6C — git branch
_p_purple=$'%{\e[38;2;180;142;173m%}' # #B48EAD — prompt symbol (success)
_p_reset=$'%{\e[0m%}'

_fallback_git_info() {
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null) || \
        branch=$(git rev-parse --short HEAD 2>/dev/null) || return
    printf '%s' "${_p_gray} ${branch}${_p_reset}"
}

_fallback_precmd() {
    local git_info
    git_info=$(_fallback_git_info)
    # Line 1: user  path  branch
    # Line 2: ❯ (purple on success, red on error)
    PROMPT="${_p_red}%n${_p_reset} ${_p_blue}%~${_p_reset}${git_info}
%(?.${_p_purple}.${_p_red})❯${_p_reset} "
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _fallback_precmd
