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

typeset -ga _zj_previewer_patterns _zj_previewer_descriptions _zj_previewer_scripts
typeset -ga _zj_action_bindings _zj_action_descriptions _zj_action_scripts

_zsh_jumper_parse_toml() {
    emulate -L zsh
    local file="$1" target_array="$2"
    [[ ! -f "$file" ]] && return 1

    local line in_target=0 current_idx=0
    local -A current_item
    typeset -a match mbegin mend

    # Clear output arrays based on target
    case "$target_array" in
        previewers)
            _zj_previewer_patterns=()
            _zj_previewer_descriptions=()
            _zj_previewer_scripts=()
            ;;
        actions)
            _zj_action_bindings=()
            _zj_action_descriptions=()
            _zj_action_scripts=()
            ;;
    esac

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "${line// /}" || "$line" == \#* ]] && continue
        if [[ "$line" =~ '^\[\[([a-zA-Z_]+)\]\]' ]]; then
            (( in_target )) && _zsh_jumper_save_toml_item "$target_array"
            if [[ "${match[1]}" == "$target_array" ]]; then
                in_target=1; current_item=()
            else
                in_target=0
            fi
            continue
        fi
        if (( in_target )) && [[ "$line" =~ '^[[:space:]]*([a-zA-Z_]+)[[:space:]]*=[[:space:]]*(.+)' ]]; then
            local key="${match[1]}" value="${match[2]}"
            [[ "$value" == \"*\" ]] && value="${value#\"}"; value="${value%\"}"
            [[ "$value" == \'*\' ]] && value="${value#\'}"; value="${value%\'}"
            current_item[$key]="$value"
        fi
    done < "$file"
    (( in_target )) && _zsh_jumper_save_toml_item "$target_array"
    return 0
}

_zsh_jumper_save_toml_item() {
    local target="$1"
    case "$target" in
        previewers)
            [[ -n "${current_item[pattern]}" && -n "${current_item[script]}" ]] && {
                _zj_previewer_patterns+=("${current_item[pattern]}")
                _zj_previewer_descriptions+=("${current_item[description]:-custom}")
                local script="${current_item[script]}"
                [[ "$script" == "~"* ]] && script="$HOME${script#"~"}"
                _zj_previewer_scripts+=("$script")
            }
            ;;
        actions)
            [[ -n "${current_item[binding]}" && -n "${current_item[script]}" ]] && {
                _zj_action_bindings+=("${current_item[binding]}")
                _zj_action_descriptions+=("${current_item[description]:-custom}")
                local script="${current_item[script]}"
                [[ "$script" == "~"* ]] && script="$HOME${script#"~"}"
                _zj_action_scripts+=("$script")
            }
            ;;
    esac
    current_item=()
}

# Load default built-in actions from plugin's actions/ directory
_zsh_jumper_load_default_actions() {
    emulate -L zsh
    local dir="${ZshJumper[dir]}/actions"

    # Default actions with their configured keybindings
    # Format: binding:description:script
    local -a defaults=(
        "${ZshJumper[wrap-key]}:wrap:${dir}/wrap.sh"
        "${ZshJumper[help-key]}:help:${dir}/help.sh"
        "${ZshJumper[var-key]}:var:${dir}/var.sh"
        "${ZshJumper[replace-key]}:replace:${dir}/replace.sh"
    )

    local entry binding desc script
    for entry in "${defaults[@]}"; do
        binding="${entry%%:*}"
        entry="${entry#*:}"
        desc="${entry%%:*}"
        script="${entry#*:}"

        # Only add if script exists and binding not already registered (user override)
        [[ ! -x "$script" ]] && continue

        # Check if binding already registered by user config (skip if already in array)
        (( ${_zj_action_bindings[(Ie)$binding]} )) && continue

        _zj_action_bindings+=("$binding")
        _zj_action_descriptions+=("$desc")
        _zj_action_scripts+=("$script")
    done
}

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
    zstyle -s ':zsh-jumper:' debug val; ZshJumper[debug]="${val:-off}"

    # Extensibility config - unified or separate files
    zstyle -s ':zsh-jumper:' config val
    if [[ -n "$val" ]]; then
        [[ "$val" == "~"* ]] && val="$HOME${val#"~"}"
        _zsh_jumper_parse_toml "$val" previewers
        _zsh_jumper_parse_toml "$val" actions
    else
        zstyle -s ':zsh-jumper:' previewer-config val
        [[ -n "$val" ]] && {
            [[ "$val" == "~"* ]] && val="$HOME${val#"~"}"
            _zsh_jumper_parse_toml "$val" previewers
        }
        zstyle -s ':zsh-jumper:' action-config val
        [[ -n "$val" ]] && {
            [[ "$val" == "~"* ]] && val="$HOME${val#"~"}"
            _zsh_jumper_parse_toml "$val" actions
        }
    fi

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

    # Load default actions (after user config, so user can override)
    _zsh_jumper_load_default_actions
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
    [[ -n "${ZshJumper[picker-opts]}" ]] && base_opts+=(${(z)ZshJumper[picker-opts]})

    [[ "${ZshJumper[debug]}" == "on" ]] && {
        echo "FZF: $cmd ${base_opts[*]} prompt=${_zj_invoke_prompt}" >> /tmp/zsh-jumper-debug.log
    }

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

# Build preview command
# Returns preview command string via REPLY
_zsh_jumper_build_preview_cmd() {
    emulate -L zsh
    # Simple approach: use external script to avoid quoting hell
    local script="${ZshJumper[dir]}/preview.sh"
    if [[ -x "$script" ]]; then
        # Inline env vars for fzf-tmux compatibility (tmux panes don't inherit exports)
        local env_prefix=""
        if (( ${#_zj_previewer_patterns[@]} > 0 )); then
            local patterns="${(pj:\n:)_zj_previewer_patterns}"
            local scripts="${(pj:\n:)_zj_previewer_scripts}"
            env_prefix="ZJ_PREVIEWER_PATTERNS=${(qq)patterns} ZJ_PREVIEWER_SCRIPTS=${(qq)scripts} "
        fi
        REPLY="${env_prefix}$script {}"
    else
        # Fallback inline preview (no custom previewers)
        REPLY='t="{}"; t="${t#*: }"; t="${t//\"/}"; [ -d "$t" ] && ls -la "$t" 2>/dev/null || [ -f "$t" ] && head -30 "$t" 2>/dev/null'
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
        local ik=${ZshJumper[instant-key]}

        # Build header and bindings dynamically from action arrays
        local ai binding desc key_display
        local -a header_parts=()
        for ai in {1..${#_zj_action_bindings[@]}}; do
            binding="${_zj_action_bindings[$ai]}"
            [[ -z "$binding" ]] && continue
            desc="${_zj_action_descriptions[$ai]}"
            key_display="${binding#ctrl-}"
            [[ "$binding" == ctrl-* ]] && key_display="^${(U)key_display}"
            header_parts+=("${key_display}:${desc}")
        done
        header_parts+=("${ik}+a-z:jump")
        header="${(j: | :)header_parts}"

        # Build hint key bindings and unbind/rebind lists
        # Letter keys start unbound (for fuzzy search), instant-key rebinds them
        local hint_binds="" unbinds="" rebinds="" k
        for k in a s d f g h j k l q w e r t y u i o p z x c v b n m; do
            hint_binds+=",$k:print(hint-$k)+accept"
            unbinds+="${unbinds:+,}$k"
            rebinds+="${rebinds:+,}$k"
        done

        binds="enter:print()+accept"

        # Add all action bindings (both built-in and custom use same mechanism)
        for ai in {1..${#_zj_action_bindings[@]}}; do
            [[ -z "${_zj_action_bindings[$ai]}" ]] && continue
            binds+=",${_zj_action_bindings[$ai]}:print(action-${ai})+accept"
        done

        binds+="$hint_binds"
        # Start with letter keys unbound; instant-key rebinds them
        binds+=",start:unbind($unbinds)"
        binds+=",${ik}:rebind($rebinds)"

        if [[ "${ZshJumper[preview]}" != "off" ]]; then
            _zsh_jumper_build_preview_cmd
            local preview_cmd="$REPLY"
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

    # Invoke picker
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
        action-*)
            # All actions (built-in and custom) use external scripts
            local action_idx="${_zj_result_key#action-}"
            _zsh_jumper_do_custom_action "$action_idx" "${selections[@]}"
            ;;
        *)
            # Default: jump to selection
            _zsh_jumper_do_jump "${selections[@]}"
            ;;
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

# Execute custom action script
# Args: $1 = action index, $2 = selection string
# Script interface:
#   args: $1 = selected token, $2 = token index (1-based)
#   env:  ZJ_BUFFER = current command line
#         ZJ_WORDS = newline-separated tokens
#         ZJ_POSITIONS = newline-separated positions (0-based byte offsets)
#         ZJ_CURSOR = current cursor position
#   stdout: new command line (replaces BUFFER)
#   exit codes:
#     0 = apply stdout as new BUFFER
#     1 = error (show stderr)
#     2 = display mode (show stdout in terminal, no buffer change)
#     3 = push-line mode (format: "new_buffer\n---ZJ_PUSHLINE---\npushed_line")
_zsh_jumper_do_custom_action() {
    emulate -L zsh
    local action_idx="$1" sel="$2"
    [[ -z "$sel" ]] && return 1

    # Validate action index
    (( action_idx < 1 || action_idx > ${#_zj_action_scripts[@]} )) && return 1

    local script="${_zj_action_scripts[$action_idx]}"
    [[ ! -x "$script" ]] && {
        zle -M "zsh-jumper: action script not executable: $script"
        return 1
    }

    # Get selected token
    local token_idx="$(_zsh_jumper_extract_index "$sel")"
    [[ "$token_idx" =~ ^[0-9]+$ ]] || return 1
    (( token_idx < 1 || token_idx > ${#_zj_words[@]} )) && return 1
    local token="${_zj_words[$token_idx]}"

    # Export environment for script
    local result stderr_file=$(mktemp)
    result=$(
        export ZJ_BUFFER="$BUFFER"
        export ZJ_WORDS="${(pj:\n:)_zj_words}"
        export ZJ_POSITIONS="${(pj:\n:)_zj_positions}"
        export ZJ_CURSOR="$CURSOR"
        export ZJ_PICKER="${ZshJumper[picker]}"
        "$script" "$token" "$token_idx" 2>"$stderr_file"
    )
    local exit_code=$?
    local stderr_out=$(<"$stderr_file"); rm -f "$stderr_file"

    case $exit_code in
        0)  # Apply stdout as new buffer (CURSOR:N overrides, else token position)
            if [[ -n "$result" ]]; then
                local last_line="${result##*$'\n'}"
                if [[ "$last_line" =~ ^CURSOR:([0-9]+)$ ]]; then
                    BUFFER="${result%$'\n'*}"
                    CURSOR="${match[1]}"
                else
                    BUFFER="${result%$'\n'}"  # Strip trailing newline
                    CURSOR="${_zj_positions[$token_idx]}"  # Default to token position
                fi
            fi
            ;;
        1)  # Error
            [[ -n "$stderr_out" ]] && zle -M "action failed: $stderr_out"
            return 1
            ;;
        2)  # Display mode - show output in terminal
            if [[ -n "$result" ]]; then
                print
                print -r -- "$result"
                print
            fi
            ;;
        3)  # Push-line mode - for variable extraction
            if [[ "$result" == *"---ZJ_PUSHLINE---"* ]]; then
                local new_buffer="${result%%---ZJ_PUSHLINE---*}"
                local pushed_line="${result#*---ZJ_PUSHLINE---}"
                new_buffer="${new_buffer%$'\n'}"  # Strip trailing newline
                pushed_line="${pushed_line#$'\n'}"  # Strip leading newline
                BUFFER="$new_buffer"
                CURSOR="${_zj_positions[$token_idx]}"  # Token position
                zle push-line
                BUFFER="$pushed_line"
                CURSOR=${#BUFFER}
            fi
            ;;
    esac
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
               _zsh_jumper_load_default_actions \
               _zsh_jumper_invoke_picker _zsh_jumper_tokenize \
               _zsh_jumper_supports_binds _zsh_jumper_do_jump \
               _zsh_jumper_do_custom_action \
               _zsh_jumper_adapter_fzf _zsh_jumper_adapter_fzf-tmux \
               _zsh_jumper_adapter_sk _zsh_jumper_adapter_peco \
               _zsh_jumper_adapter_percol _zsh_jumper_extract_index \
               _zsh_jumper_build_overlay _zsh_jumper_hint_to_index \
               _zsh_jumper_build_preview_cmd \
               _zsh_jumper_parse_toml _zsh_jumper_save_toml_item \
               zsh-jumper-setup-bindings zsh-jumper-unload 2>/dev/null

    unset '_zj_words' '_zj_positions' '_zj_result_key' '_zj_result_selection' \
          '_zj_invoke_prompt' '_zj_invoke_header' '_zj_invoke_binds' \
          '_zj_invoke_preview_args' 'ZshJumper[dir]' \
          '_zj_previewer_patterns' '_zj_previewer_descriptions' '_zj_previewer_scripts' \
          '_zj_action_bindings' '_zj_action_descriptions' '_zj_action_scripts'
    (( ${#ZshJumper} == 0 )) && unset ZshJumper

    return 0
}

# Register unload hook if zinit supports it
if (( $+functions[@zsh-plugin-run-on-unload] )); then
    @zsh-plugin-run-on-unload 'zsh-jumper-unload'
fi

return 0
