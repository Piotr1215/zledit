#!/usr/bin/env zsh
# zsh-jumper - Jump to any word on the current line via fuzzy picker
# https://github.com/decoder/zsh-jumper

# Standardized $0 handling (Zsh Plugin Standard)
0="${ZERO:-${${0:#$ZSH_ARGZERO}:-${(%):-%N}}}"
0="${${(M)0:#/*}:-$PWD/$0}"

typeset -gA ZshJumper
ZshJumper[dir]="${0:h}"

# ------------------------------------------------------------------------------
# Picker Detection & Configuration
# ------------------------------------------------------------------------------
# Priority: zstyle > fzf-tmux (if in tmux) > fzf > sk > peco > percol
#
# Configure via zstyle:
#   zstyle ':zsh-jumper:' picker fzf
#   zstyle ':zsh-jumper:' picker-opts '--height=10 --reverse'
#   zstyle ':zsh-jumper:' disable-bindings yes
# ------------------------------------------------------------------------------

_zsh_jumper_detect_picker() {
    emulate -L zsh

    local picker
    zstyle -s ':zsh-jumper:' picker picker

    if [[ -n "$picker" ]]; then
        (( $+commands[$picker] )) && { echo "$picker"; return 0 }
        echo "zsh-jumper: configured picker '$picker' not found" >&2
        return 1
    fi

    # Auto-detect: prefer fzf-tmux in tmux sessions
    if [[ -n "$TMUX" ]] && (( $+commands[fzf-tmux] )); then
        echo "fzf-tmux"
    elif (( $+commands[fzf] )); then
        echo "fzf"
    elif (( $+commands[sk] )); then
        echo "sk"
    elif (( $+commands[peco] )); then
        echo "peco"
    elif (( $+commands[percol] )); then
        echo "percol"
    else
        return 1
    fi
}

_zsh_jumper_get_picker_opts() {
    emulate -L zsh

    local picker="$1" opts
    zstyle -s ':zsh-jumper:' picker-opts opts

    if [[ -n "$opts" ]]; then
        echo "$opts"
        return
    fi

    # Sensible defaults per picker
    case "$picker" in
        fzf|fzf-tmux)
            echo "--height=40% --reverse --prompt='jump> '"
            ;;
        sk)
            echo "--height=40% --reverse --prompt='jump> '"
            ;;
        peco)
            echo "--prompt='jump> '"
            ;;
        percol)
            echo "--prompt='jump> '"
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Main Widget
# ------------------------------------------------------------------------------

zsh-jumper-widget() {
    emulate -L zsh
    setopt local_options

    local picker opts target

    picker="$(_zsh_jumper_detect_picker)"
    if [[ -z "$picker" ]]; then
        zle -M "zsh-jumper: no picker found (install fzf, sk, peco, or percol)"
        return 1
    fi

    local words=(${(z)BUFFER})
    [[ ${#words[@]} -eq 0 ]] && return 0

    opts="$(_zsh_jumper_get_picker_opts "$picker")"

    # Run picker
    target=$(printf '%s\n' "${words[@]}" | eval "$picker $opts")

    if [[ -n "$target" ]]; then
        # Find position and move cursor
        local pos=$((${BUFFER[(i)$target]} - 1))
        (( pos >= 0 )) && CURSOR=$pos
    fi

    zle redisplay
}

zle -N zsh-jumper-widget

# ------------------------------------------------------------------------------
# Keybindings
# ------------------------------------------------------------------------------

zsh-jumper-setup-bindings() {
    emulate -L zsh

    # Check for opt-out
    if zstyle -t ':zsh-jumper:' disable-bindings; then
        return 0
    fi

    local key
    zstyle -s ':zsh-jumper:' binding key || key='^X/'

    bindkey "$key" zsh-jumper-widget
}

zsh-jumper-setup-bindings

# ------------------------------------------------------------------------------
# Unload (for plugin managers like zinit)
# ------------------------------------------------------------------------------

zsh-jumper-unload() {
    emulate -L zsh

    # Remove widget
    zle -D zsh-jumper-widget 2>/dev/null

    # Remove functions
    unfunction zsh-jumper-widget _zsh_jumper_detect_picker \
               _zsh_jumper_get_picker_opts zsh-jumper-setup-bindings \
               zsh-jumper-unload 2>/dev/null

    # Clean up global state
    unset 'ZshJumper[dir]'
    (( ${#ZshJumper} == 0 )) && unset ZshJumper

    return 0
}

# Register unload hook if zinit supports it
if (( $+functions[@zsh-plugin-run-on-unload] )); then
    @zsh-plugin-run-on-unload 'zsh-jumper-unload'
fi

return 0
