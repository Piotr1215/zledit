#!/usr/bin/env zsh
# zsh-jumper - Jump to any word on the current line via fuzzy picker
# https://github.com/decoder/zsh-jumper

# Standardized $0 handling (Zsh Plugin Standard)
0="${ZERO:-${${0:#$ZSH_ARGZERO}:-${(%):-%N}}}"
0="${${(M)0:#/*}:-$PWD/$0}"

typeset -gA ZshJumper
ZshJumper[dir]="${0:h}"

# ------------------------------------------------------------------------------
# Configuration (read once at load time)
# ------------------------------------------------------------------------------
# Configure via zstyle BEFORE loading the plugin:
#   zstyle ':zsh-jumper:' picker fzf
#   zstyle ':zsh-jumper:' picker-opts '--height=10 --reverse'
#   zstyle ':zsh-jumper:' disable-bindings yes
#   zstyle ':zsh-jumper:' preview off
#   zstyle ':zsh-jumper:' preview-window 'right:50%:wrap'
# ------------------------------------------------------------------------------

_zsh_jumper_load_config() {
    emulate -L zsh
    local val

    # Read all zstyle config once and store in ZshJumper array
    zstyle -s ':zsh-jumper:' overlay val; ZshJumper[overlay]="${val:-on}"
    zstyle -s ':zsh-jumper:' preview val; ZshJumper[preview]="${val:-on}"
    zstyle -s ':zsh-jumper:' preview-window val; ZshJumper[preview-window]="${val:-right:50%:wrap}"
    zstyle -s ':zsh-jumper:' cursor val; ZshJumper[cursor]="${val:-start}"
    zstyle -s ':zsh-jumper:' picker-opts val; ZshJumper[picker-opts]="$val"

    # FZF action keys
    zstyle -s ':zsh-jumper:' fzf-wrap-key val; ZshJumper[wrap-key]="${val:-ctrl-s}"
    zstyle -s ':zsh-jumper:' fzf-help-key val; ZshJumper[help-key]="${val:-ctrl-h}"
    zstyle -s ':zsh-jumper:' fzf-var-key val; ZshJumper[var-key]="${val:-ctrl-e}"
    zstyle -s ':zsh-jumper:' fzf-replace-key val; ZshJumper[replace-key]="${val:-ctrl-r}"
    zstyle -s ':zsh-jumper:' fzf-instant-key val; ZshJumper[instant-key]="${val:-;}"

    # Detect picker (prefer explicit config, then auto-detect)
    zstyle -s ':zsh-jumper:' picker val
    if [[ -n "$val" ]]; then
        (( $+commands[$val] )) && ZshJumper[picker]="$val"
    elif [[ -n "$TMUX" ]] && (( $+commands[fzf-tmux] )); then
        ZshJumper[picker]="fzf-tmux"
    elif (( $+commands[fzf] )); then
        ZshJumper[picker]="fzf"
    elif (( $+commands[sk] )); then
        ZshJumper[picker]="sk"
    elif (( $+commands[peco] )); then
        ZshJumper[picker]="peco"
    elif (( $+commands[percol] )); then
        ZshJumper[picker]="percol"
    fi
}

_zsh_jumper_load_config

# Result variables (set by adapters)
typeset -g _zj_result_key _zj_result_selection

# ------------------------------------------------------------------------------
# Picker Adapters (Ports & Adapters pattern)
# ------------------------------------------------------------------------------
# Each adapter implements the same interface:
#   Input:  items via stdin, config via _zj_invoke_* variables
#   Output: _zj_result_key (action), _zj_result_selection (chosen item)
#   Return: 0 = success, 1 = cancelled/error
# ------------------------------------------------------------------------------

# Shared helper for fzf-like pickers (fzf, fzf-tmux, sk)
# Args: $1=command, $2=height (empty for fzf-tmux which uses tmux pane)
_zsh_jumper_adapter_fzflike() {
    local cmd="$1"
    local -a base_opts=(${2:+--height=$2} --reverse)
    [[ -n "${ZshJumper[picker-opts]}" ]] && base_opts=(${(z)ZshJumper[picker-opts]})

    local result
    if [[ -n "$_zj_invoke_binds" ]]; then
        result=$($cmd "${base_opts[@]}" \
            --prompt="$_zj_invoke_prompt" \
            --header="$_zj_invoke_header" \
            --bind "$_zj_invoke_binds" \
            "${_zj_invoke_preview_args[@]}")
        _zj_result_key="${result%%$'\n'*}"
        _zj_result_selection="${result#*$'\n'}"
    else
        result=$($cmd "${base_opts[@]}" --prompt="$_zj_invoke_prompt")
        _zj_result_key=""
        _zj_result_selection="$result"
    fi
    [[ -n "$_zj_result_selection" ]]
}

_zsh_jumper_adapter_fzf() { _zsh_jumper_adapter_fzflike fzf 40%; }
_zsh_jumper_adapter_fzf-tmux() { _zsh_jumper_adapter_fzflike fzf-tmux; }
_zsh_jumper_adapter_sk() { _zsh_jumper_adapter_fzflike sk 40%; }

# Shared helper for simple pickers (no bind support)
_zsh_jumper_adapter_simple() {
    local cmd="$1"
    local -a base_opts=()
    [[ -n "${ZshJumper[picker-opts]}" ]] && base_opts=(${(z)ZshJumper[picker-opts]})

    _zj_result_key=""
    _zj_result_selection=$($cmd "${base_opts[@]}" --prompt="$_zj_invoke_prompt")
    [[ -n "$_zj_result_selection" ]]
}

_zsh_jumper_adapter_peco() { _zsh_jumper_adapter_simple peco; }
_zsh_jumper_adapter_percol() { _zsh_jumper_adapter_simple percol; }

# ------------------------------------------------------------------------------
# Port: Unified Picker Interface
# ------------------------------------------------------------------------------
# Usage:
#   printf '%s\n' "${items[@]}" | _zsh_jumper_invoke_picker <picker> <prompt> [header] [binds] [preview_args...]
# Returns:
#   _zj_result_key - action key (empty for basic selection)
#   _zj_result_selection - selected item(s)
# ------------------------------------------------------------------------------

_zsh_jumper_invoke_picker() {
    local picker="$1" prompt="$2" header="$3" binds="$4"
    shift 4
    local -a preview_args=("$@")

    # Set invocation context for adapter
    _zj_invoke_prompt="$prompt"
    _zj_invoke_header="$header"
    _zj_invoke_binds="$binds"
    _zj_invoke_preview_args=("${preview_args[@]}")

    # Clear results
    _zj_result_key=""
    _zj_result_selection=""

    # Dispatch to adapter
    local adapter_fn="_zsh_jumper_adapter_${picker}"
    if (( $+functions[$adapter_fn] )); then
        $adapter_fn
    else
        echo "zsh-jumper: unknown picker '$picker'" >&2
        return 1
    fi
}

_zsh_jumper_supports_binds() {
    [[ "$1" == fzf* || "$1" == sk ]]
}

# ------------------------------------------------------------------------------
# Overlay (visual hints on command line)
# ------------------------------------------------------------------------------

# Hint keys: home row first, then top row, then bottom
typeset -ga _zj_hint_keys=(a s d f g h j k l q w e r t y u i o p z x c v b n m)

_zsh_jumper_build_overlay() {
    local -a hints=(a s d f g h j k l q w e r t y u i o p z x c v b n m)
    local i=1 pos word last_end=0 result=""
    while (( i <= ${#_zj_words[@]} )); do
        pos=${_zj_positions[$i]}
        word=${_zj_words[$i]}
        result+="${BUFFER:$last_end:$((pos - last_end))}"
        (( i <= ${#hints[@]} )) && result+="[${hints[$i]}]${word}" || result+="[${i}]${word}"
        last_end=$((pos + ${#word}))
        (( i++ ))
    done
    result+="${BUFFER:$last_end}"
    REPLY="$result"
}

# Highlight hint keys [a] [s] [27] etc with color via region_highlight
_zsh_jumper_highlight_hints() {
    region_highlight=()
    local i=0 len=${#BUFFER} j content
    while (( i < len )); do
        if [[ "${BUFFER:$i:1}" == "[" ]]; then
            # Find closing ]
            j=$((i + 1))
            while (( j < len )) && [[ "${BUFFER:$j:1}" != "]" ]]; do
                (( j++ ))
            done
            if (( j < len )); then
                content="${BUFFER:$((i+1)):$((j-i-1))}"
                # Highlight if content is a single letter (a-z) or a number
                if [[ "$content" == [a-z] ]] || [[ "$content" =~ ^[0-9]+$ ]]; then
                    region_highlight+=("$i $((j+1)) fg=yellow,bold")
                fi
                (( i = j + 1 ))
            else
                (( i++ ))
            fi
        else
            (( i++ ))
        fi
    done
}

# Map hint key back to word index
_zsh_jumper_hint_to_index() {
    local hint="$1" i
    for i in {1..${#_zj_hint_keys[@]}}; do
        [[ "${_zj_hint_keys[$i]}" == "$hint" ]] && { echo "$i"; return 0; }
    done
    # Fallback: if it's a number, use directly
    [[ "$hint" =~ ^[0-9]+$ ]] && echo "$hint"
}

# ------------------------------------------------------------------------------
# Tokenizer
# ------------------------------------------------------------------------------

_zsh_jumper_tokenize() {
    emulate -L zsh
    _zj_words=()
    _zj_positions=()

    local i=0 word_start=-1 in_word=0
    local len=${#BUFFER}

    while (( i < len )); do
        if [[ "${BUFFER:$i:1}" == [[:space:]] ]]; then
            if (( in_word )); then
                local word="${BUFFER:$word_start:$((i - word_start))}"
                [[ "$word" != "\\" ]] && {
                    _zj_words+=("$word")
                    _zj_positions+=($word_start)
                }
                in_word=0
            fi
        elif (( ! in_word )); then
            word_start=$i
            in_word=1
        fi
        (( i++ ))
    done

    if (( in_word )); then
        local word="${BUFFER:$word_start}"
        [[ "$word" != "\\" ]] && {
            _zj_words+=("$word")
            _zj_positions+=($word_start)
        }
    fi
}

_zsh_jumper_preview() {
    local t="$1"
    t="${t#*: }"
    t="${t//\"/}"
    t="${t//\'/}"
    [[ "$t" == *=* ]] && t="${t##*=}"
    [[ "$t" == "~"* ]] && t="$HOME${t#"~"}"

    if [[ -d "$t" ]]; then
        ls -la "$t" 2>/dev/null
    elif [[ -f "$t" ]]; then
        if command -v bat >/dev/null; then
            bat --style=plain --color=always -n --line-range=:30 "$t" 2>/dev/null
        else
            head -30 "$t" 2>/dev/null
        fi
    fi
}

# ------------------------------------------------------------------------------
# Main Widget
# ------------------------------------------------------------------------------

zsh-jumper-widget() {
    emulate -L zsh
    setopt local_options no_xtrace no_verbose

    local picker="${ZshJumper[picker]}"
    if [[ -z "$picker" ]]; then
        zle -M "zsh-jumper: no picker found (install fzf, sk, peco, or percol)"
        return 1
    fi

    _zsh_jumper_tokenize
    [[ ${#_zj_words[@]} -eq 0 ]] && return 0

    # Build numbered list with hint keys
    local -a numbered
    local i hint
    for i in {1..${#_zj_words[@]}}; do
        if (( i <= ${#_zj_hint_keys[@]} )); then
            hint="${_zj_hint_keys[$i]}"
            numbered+=("[${hint}] $i: ${_zj_words[$i]}")
        else
            numbered+=("$i: ${_zj_words[$i]}")
        fi
    done

    # Use pre-loaded config from ZshJumper array (no zstyle reads during widget)
    local header="" binds=""
    local -a preview_args=()

    if _zsh_jumper_supports_binds "$picker"; then
        local wk=${ZshJumper[wrap-key]#ctrl-} hk=${ZshJumper[help-key]#ctrl-}
        local vk=${ZshJumper[var-key]#ctrl-} rk=${ZshJumper[replace-key]#ctrl-}
        local ik=${ZshJumper[instant-key]}
        header="^${(U)wk}:wrap | ^${(U)hk}:help | ^${(U)vk}:var | ^${(U)rk}:replace | ${ik}+a-z:jump"

        # Build hint key bindings and unbind/rebind lists
        # Letter keys start unbound (for fuzzy search), instant-key rebinds them
        local hint_binds="" unbinds="" rebinds="" k
        for k in a s d f g h j k l q w e r t y u i o p z x c v b n m; do
            hint_binds+=",$k:print(hint-$k)+accept"
            unbinds+="${unbinds:+,}$k"
            rebinds+="${rebinds:+,}$k"
        done

        binds="enter:print()+accept"
        binds+=",${ZshJumper[wrap-key]}:print(wrap)+accept"
        binds+=",${ZshJumper[help-key]}:print(help)+accept"
        binds+=",${ZshJumper[var-key]}:print(var)+accept"
        binds+=",${ZshJumper[replace-key]}:print(replace)+accept"
        binds+="$hint_binds"
        # Start with letter keys unbound; instant-key rebinds them
        binds+=",start:unbind($unbinds)"
        binds+=",${ik}:rebind($rebinds)"

        if [[ "${ZshJumper[preview]}" != "off" ]]; then
            local preview_cmd='t="{}"; t="${t#*: }"; t="${t//\"/}"; t="${t//'"'"'/}"; [[ "$t" == *=* ]] && t="${t##*=}"; [[ "$t" == "~"* ]] && t="$HOME${t#"~"}"; [ -d "$t" ] && ls -la "$t" 2>/dev/null || [ -f "$t" ] && { command -v bat >/dev/null && bat --style=plain --color=always -n --line-range=:30 "$t" 2>/dev/null || head -30 "$t" 2>/dev/null; }'
            preview_args=(--preview "$preview_cmd" --preview-window "${ZshJumper[preview-window]}")
        fi
    fi

    # Always save original buffer (for safe restoration)
    local saved_buffer="$BUFFER"

    # Show overlay on command line with highlighted hints
    if [[ "${ZshJumper[overlay]}" != "off" ]]; then
        _zsh_jumper_build_overlay
        BUFFER="$REPLY"
        _zsh_jumper_highlight_hints
        zle -R
    fi

    # Invoke picker via port (zle -I invalidates display for external command)
    zle -I
    printf '%s\n' "${numbered[@]}" | _zsh_jumper_invoke_picker "$picker" "jump> " "$header" "$binds" "${preview_args[@]}"

    # Restore original buffer and clear highlights
    region_highlight=()
    BUFFER="$saved_buffer"

    # Handle instant hint keys (hint-a, hint-s, etc)
    if [[ "$_zj_result_key" == hint-* ]]; then
        local hint_char="${_zj_result_key#hint-}"
        local hint_idx="$(_zsh_jumper_hint_to_index "$hint_char")"
        if [[ -n "$hint_idx" ]] && (( hint_idx >= 1 && hint_idx <= ${#_zj_words[@]} )); then
            _zsh_jumper_do_jump "[${hint_char}] ${hint_idx}: ${_zj_words[$hint_idx]}"
        fi
        zle reset-prompt
        return 0
    fi

    [[ -z "$_zj_result_selection" ]] && { zle reset-prompt; return 0; }

    # Handle result based on action key
    local -a selections=("${(@f)_zj_result_selection}")

    case "$_zj_result_key" in
        wrap)    _zsh_jumper_do_wrap "${selections[@]}" ;;
        help)    _zsh_jumper_do_help "${selections[@]}" ;;
        var)     _zsh_jumper_do_var "${selections[@]}" ;;
        replace) _zsh_jumper_do_replace "${selections[@]}" ;;
        *)       _zsh_jumper_do_jump "${selections[@]}" ;;
    esac

    zle reset-prompt
}

# ------------------------------------------------------------------------------
# Actions
# ------------------------------------------------------------------------------

# Extract index from selection format: "[a] 1: word" or "[123] 1: word" or "1: word"
_zsh_jumper_extract_index() {
    local sel="$1"
    # Strip hint prefix if present: "[...] N: word" -> "N: word"
    # Uses shortest match (#) to strip first [...] followed by space
    sel="${sel#\[*\] }"
    # Extract number before colon
    echo "${sel%%:*}"
}

_zsh_jumper_do_jump() {
    local sel="$1"
    [[ -z "$sel" ]] && return 1

    local idx="$(_zsh_jumper_extract_index "$sel")"
    [[ "$idx" =~ ^[0-9]+$ ]] || return 1
    (( idx < 1 || idx > ${#_zj_words[@]} )) && return 1

    local pos="${_zj_positions[$idx]}"
    local target="${_zj_words[$idx]}"

    case "${ZshJumper[cursor]}" in
        end)    CURSOR=$((pos + ${#target})) ;;
        middle) CURSOR=$((pos + ${#target} / 2)) ;;
        *)      CURSOR=$pos ;;
    esac
}

_zsh_jumper_do_wrap() {
    local sel="$1"
    [[ -z "$sel" ]] && return 1

    local idx="$(_zsh_jumper_extract_index "$sel")"
    [[ "$idx" =~ ^[0-9]+$ ]] || return 1
    (( idx < 1 || idx > ${#_zj_words[@]} )) && return 1

    local pos="${_zj_positions[$idx]}"
    local target="${_zj_words[$idx]}"

    local wrappers='"..."   double quote
'"'"'...'"'"'   single quote
"$..."  quoted variable
${...}  variable expansion
$(...)  command substitution
`...`   backtick / legacy subshell
[...]   square brackets / test
{...}   curly braces / brace expansion
(...)   parentheses / subshell
<...>   angle brackets / redirect'

    zle -I
    print -r -- "$wrappers" | _zsh_jumper_invoke_picker "${ZshJumper[picker]}" "wrap> " "Select wrapper" ""
    [[ -z "$_zj_result_selection" ]] && return

    local wrapper_type="${_zj_result_selection%%[[:space:]]*}"
    local open close
    case "$wrapper_type" in
        '"..."')   open='"' close='"' ;;
        "'...'")   open="'" close="'" ;;
        '"$..."')  open='"$' close='"' ;;
        '${...}')  open='${' close='}' ;;
        '$(...)')  open='$(' close=')' ;;
        '`...`')   open='`' close='`' ;;
        '[...]')   open='[' close=']' ;;
        '{...}')   open='{' close='}' ;;
        '(...)')   open='(' close=')' ;;
        '<...>')   open='<' close='>' ;;
    esac

    local end_pos=$((pos + ${#target}))
    BUFFER="${BUFFER:0:$end_pos}${close}${BUFFER:$end_pos}"
    BUFFER="${BUFFER:0:$pos}${open}${BUFFER:$pos}"
    CURSOR=$((pos + ${#open}))
}

_zsh_jumper_do_help() {
    local sel="$1"
    [[ -z "$sel" ]] && return 1

    local idx="$(_zsh_jumper_extract_index "$sel")"
    [[ "$idx" =~ ^[0-9]+$ ]] || return 1
    (( idx < 1 || idx > ${#_zj_words[@]} )) && return 1

    local target="${_zj_words[$idx]}"
    local cmd="${_zj_words[1]}"
    local help_text=""

    if [[ "$target" == -* ]] && (( $+commands[$cmd] )); then
        local -a lines matching
        lines=("${(@f)$("$cmd" --help 2>&1)}")
        for line in "${lines[@]}"; do
            [[ "$line" == *"$target"* ]] && matching+=("$line")
            (( ${#matching[@]} >= 20 )) && break
        done
        help_text="${(F)matching}"
    elif (( $+commands[$target] )); then
        help_text=$("$target" --help 2>&1)
    fi

    if [[ -n "$help_text" ]]; then
        print
        print "=== $target ==="
        print -r -- "$help_text"
        print
        zle reset-prompt
    else
        zle -M "No help for: $target"
    fi
}

_zsh_jumper_do_var() {
    emulate -L zsh
    setopt local_options no_xtrace no_verbose

    local sel="$1"
    [[ -z "$sel" ]] && return 1

    local idx="$(_zsh_jumper_extract_index "$sel")"
    [[ "$idx" =~ ^[0-9]+$ ]] || return 1
    (( idx < 1 || idx > ${#_zj_words[@]} )) && return 1

    local pos="${_zj_positions[$idx]}"
    local target="${_zj_words[$idx]}"
    local base="${target#\$}"
    local var_name="${${(U)base}//[^A-Z0-9]/_}"
    local end_pos=$((pos + ${#target}))

    BUFFER="${BUFFER:0:$pos}\"\$${var_name}\"${BUFFER:$end_pos}"
    CURSOR=$((pos + 1))
    zle push-line
    # Escape double quotes in target for assignment
    local escaped_target="${target//\"/\\\"}"
    BUFFER="${var_name}=\"${escaped_target}\""
    CURSOR=$((${#var_name} + 1))
}

_zsh_jumper_do_replace() {
    local sel="$1"
    [[ -z "$sel" ]] && return 1

    local idx="$(_zsh_jumper_extract_index "$sel")"
    [[ "$idx" =~ ^[0-9]+$ ]] || return 1
    (( idx < 1 || idx > ${#_zj_words[@]} )) && return 1

    local pos="${_zj_positions[$idx]}"
    local target="${_zj_words[$idx]}"
    local end_pos=$((pos + ${#target}))
    BUFFER="${BUFFER:0:$pos}${BUFFER:$end_pos}"
    CURSOR=$pos
}

zle -N zsh-jumper-widget

# ------------------------------------------------------------------------------
# Keybindings
# ------------------------------------------------------------------------------

zsh-jumper-setup-bindings() {
    emulate -L zsh

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

    zle -D zsh-jumper-widget 2>/dev/null

    unfunction zsh-jumper-widget _zsh_jumper_load_config \
               _zsh_jumper_invoke_picker _zsh_jumper_tokenize \
               _zsh_jumper_supports_binds _zsh_jumper_do_jump _zsh_jumper_do_wrap \
               _zsh_jumper_do_help _zsh_jumper_do_var _zsh_jumper_do_replace \
               _zsh_jumper_adapter_fzf _zsh_jumper_adapter_fzf-tmux \
               _zsh_jumper_adapter_sk _zsh_jumper_adapter_peco \
               _zsh_jumper_adapter_percol _zsh_jumper_extract_index \
               _zsh_jumper_build_overlay _zsh_jumper_hint_to_index \
               zsh-jumper-setup-bindings zsh-jumper-unload 2>/dev/null

    unset '_zj_words' '_zj_positions' '_zj_result_key' '_zj_result_selection' \
          '_zj_invoke_prompt' '_zj_invoke_header' '_zj_invoke_binds' \
          '_zj_invoke_preview_args' 'ZshJumper[dir]'
    (( ${#ZshJumper} == 0 )) && unset ZshJumper

    return 0
}

# Register unload hook if zinit supports it
if (( $+functions[@zsh-plugin-run-on-unload] )); then
    @zsh-plugin-run-on-unload 'zsh-jumper-unload'
fi

return 0
