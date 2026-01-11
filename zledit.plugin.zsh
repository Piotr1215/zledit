#!/usr/bin/env zsh
# zledit - Jump to any word on the current line via fuzzy picker
# https://github.com/decoder/zledit

# Standardized $0 handling (Zsh Plugin Standard)
0="${ZERO:-${${0:#$ZSH_ARGZERO}:-${(%):-%N}}}"
0="${${(M)0:#/*}:-$PWD/$0}"

typeset -gA Zledit
Zledit[dir]="${0:h}"

# ------------------------------------------------------------------------------
# Configuration (read once at load time)
# ------------------------------------------------------------------------------
# Configure via zstyle BEFORE loading the plugin:
#   zstyle ':zledit:' picker fzf
#   zstyle ':zledit:' picker-opts '--height=10 --reverse'
#   zstyle ':zledit:' disable-bindings yes
#   zstyle ':zledit:' preview off
#   zstyle ':zledit:' preview-window 'right:50%:wrap'
# ------------------------------------------------------------------------------

typeset -ga _ze_previewer_patterns _ze_previewer_descriptions _ze_previewer_scripts
typeset -ga _ze_action_bindings _ze_action_descriptions _ze_action_scripts

_zledit_parse_toml() {
    emulate -L zsh
    local file="$1" target_array="$2"
    [[ ! -f "$file" ]] && return 1

    local line in_target=0 current_idx=0
    local -A current_item
    typeset -a match mbegin mend

    # Clear output arrays based on target
    case "$target_array" in
        previewers)
            _ze_previewer_patterns=()
            _ze_previewer_descriptions=()
            _ze_previewer_scripts=()
            ;;
        actions)
            _ze_action_bindings=()
            _ze_action_descriptions=()
            _ze_action_scripts=()
            ;;
    esac

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "${line// /}" || "$line" == \#* ]] && continue
        if [[ "$line" =~ '^\[\[([a-zA-Z_]+)\]\]' ]]; then
            (( in_target )) && _zledit_save_toml_item "$target_array"
            if [[ "${match[1]}" == "$target_array" ]]; then
                in_target=1; current_item=()
            else
                in_target=0
            fi
            continue
        fi
        if (( in_target )) && [[ "$line" =~ '^[[:space:]]*([a-zA-Z_]+)[[:space:]]*=[[:space:]]*(.+)' ]]; then
            local key="${match[1]}" value="${match[2]}"
            if [[ "$value" == \"*\" ]]; then
                value="${value#\"}"; value="${value%\"}"
            elif [[ "$value" == \'*\' ]]; then
                value="${value#\'}"; value="${value%\'}"
            fi
            current_item[$key]="$value"
        fi
    done < "$file"
    (( in_target )) && _zledit_save_toml_item "$target_array"
    return 0
}

_zledit_save_toml_item() {
    local target="$1"
    case "$target" in
        previewers)
            [[ -n "${current_item[pattern]}" && -n "${current_item[script]}" ]] && {
                _ze_previewer_patterns+=("${current_item[pattern]}")
                _ze_previewer_descriptions+=("${current_item[description]:-custom}")
                local script="${current_item[script]}"
                [[ "$script" == "~"* ]] && script="$HOME${script#"~"}"
                _ze_previewer_scripts+=("$script")
            }
            ;;
        actions)
            [[ -n "${current_item[binding]}" && -n "${current_item[script]}" ]] && {
                _ze_action_bindings+=("${current_item[binding]}")
                _ze_action_descriptions+=("${current_item[description]:-custom}")
                local script="${current_item[script]}"
                [[ "$script" == "~"* ]] && script="$HOME${script#"~"}"
                _ze_action_scripts+=("$script")
            }
            ;;
    esac
    current_item=()
}

# Load default built-in actions from plugin's actions/ directory
_zledit_load_default_actions() {
    emulate -L zsh
    local dir="${Zledit[dir]}/actions"

    # Default actions with their configured keybindings
    # Format: binding:description:script
    local -a defaults=(
        "${Zledit[wrap-key]}:wrap:${dir}/wrap.sh"
        "${Zledit[var-key]}:var:${dir}/var.sh"
        "${Zledit[replace-key]}:replace:${dir}/replace.sh"
        "${Zledit[move-key]}:move:${dir}/move.sh"
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
        (( ${_ze_action_bindings[(Ie)$binding]} )) && continue

        _ze_action_bindings+=("$binding")
        _ze_action_descriptions+=("$desc")
        _ze_action_scripts+=("$script")
    done
}

_zledit_load_config() {
    emulate -L zsh
    local val

    # Read all zstyle config once and store in Zledit array
    zstyle -s ':zledit:' overlay val; Zledit[overlay]="${val:-on}"
    zstyle -s ':zledit:' preview val; Zledit[preview]="${val:-on}"
    zstyle -s ':zledit:' preview-window val; Zledit[preview-window]="${val:-right:50%:wrap}"
    zstyle -s ':zledit:' cursor val; Zledit[cursor]="${val:-start}"
    zstyle -s ':zledit:' picker-opts val; Zledit[picker-opts]="$val"

    # FZF action keys
    zstyle -s ':zledit:' fzf-wrap-key val; Zledit[wrap-key]="${val:-ctrl-s}"
    zstyle -s ':zledit:' fzf-var-key val; Zledit[var-key]="${val:-ctrl-e}"
    zstyle -s ':zledit:' fzf-replace-key val; Zledit[replace-key]="${val:-ctrl-r}"
    zstyle -s ':zledit:' fzf-move-key val; Zledit[move-key]="${val:-ctrl-t}"
    zstyle -s ':zledit:' fzf-instant-key val; Zledit[instant-key]="${val:-;}"
    zstyle -s ':zledit:' debug val; Zledit[debug]="${val:-off}"

    # Extensibility config - unified or separate files
    zstyle -s ':zledit:' config val
    if [[ -n "$val" ]]; then
        [[ "$val" == "~"* ]] && val="$HOME${val#"~"}"
        _zledit_parse_toml "$val" previewers
        _zledit_parse_toml "$val" actions
    else
        zstyle -s ':zledit:' previewer-config val
        [[ -n "$val" ]] && {
            [[ "$val" == "~"* ]] && val="$HOME${val#"~"}"
            _zledit_parse_toml "$val" previewers
        }
        zstyle -s ':zledit:' action-config val
        [[ -n "$val" ]] && {
            [[ "$val" == "~"* ]] && val="$HOME${val#"~"}"
            _zledit_parse_toml "$val" actions
        }
    fi

    # Detect picker (prefer explicit config, then auto-detect)
    zstyle -s ':zledit:' picker val
    if [[ -n "$val" ]]; then
        (( $+commands[$val] )) && Zledit[picker]="$val"
    elif [[ -n "$TMUX" ]] && (( $+commands[fzf-tmux] )); then
        Zledit[picker]="fzf-tmux"
    elif (( $+commands[fzf] )); then
        Zledit[picker]="fzf"
    elif (( $+commands[sk] )); then
        Zledit[picker]="sk"
    elif (( $+commands[peco] )); then
        Zledit[picker]="peco"
    elif (( $+commands[percol] )); then
        Zledit[picker]="percol"
    fi

    # Load default actions (after user config, so user can override)
    _zledit_load_default_actions
}

_zledit_load_config

# Result variables (set by adapters)
typeset -g _ze_result_key _ze_result_selection

# ------------------------------------------------------------------------------
# Picker Adapters (Ports & Adapters pattern)
# ------------------------------------------------------------------------------
# Each adapter implements the same interface:
#   Input:  items via stdin, config via _ze_invoke_* variables
#   Output: _ze_result_key (action), _ze_result_selection (chosen item)
#   Return: 0 = success, 1 = cancelled/error
# ------------------------------------------------------------------------------

# Shared helper for fzf-like pickers (fzf, fzf-tmux, sk)
# Args: $1=command, $2=height (empty for fzf-tmux which uses tmux pane)
_zledit_adapter_fzflike() {
    local cmd="$1"
    local -a base_opts=(${2:+--height=$2} --reverse)
    [[ -n "${Zledit[picker-opts]}" ]] && base_opts+=(${(z)Zledit[picker-opts]})

    [[ "${Zledit[debug]}" == "on" ]] && {
        echo "FZF: $cmd ${base_opts[*]} prompt=${_ze_invoke_prompt}" >> /tmp/zledit-debug.log
    }

    local result
    if [[ -n "$_ze_invoke_binds" ]]; then
        result=$($cmd "${base_opts[@]}" \
            --prompt="$_ze_invoke_prompt" \
            --header="$_ze_invoke_header" \
            --bind "$_ze_invoke_binds" \
            "${_ze_invoke_preview_args[@]}")
        _ze_result_key="${result%%$'\n'*}"
        _ze_result_selection="${result#*$'\n'}"
    else
        result=$($cmd "${base_opts[@]}" --prompt="$_ze_invoke_prompt")
        _ze_result_key=""
        _ze_result_selection="$result"
    fi
    [[ -n "$_ze_result_selection" ]]
}

_zledit_adapter_fzf() { _zledit_adapter_fzflike fzf 40%; }
_zledit_adapter_fzf-tmux() { _zledit_adapter_fzflike fzf-tmux; }
_zledit_adapter_sk() { _zledit_adapter_fzflike sk 40%; }

# Shared helper for simple pickers (no bind support)
_zledit_adapter_simple() {
    local cmd="$1"
    local -a base_opts=()
    [[ -n "${Zledit[picker-opts]}" ]] && base_opts=(${(z)Zledit[picker-opts]})

    _ze_result_key=""
    _ze_result_selection=$($cmd "${base_opts[@]}" --prompt="$_ze_invoke_prompt")
    [[ -n "$_ze_result_selection" ]]
}

_zledit_adapter_peco() { _zledit_adapter_simple peco; }
_zledit_adapter_percol() { _zledit_adapter_simple percol; }

# ------------------------------------------------------------------------------
# Port: Unified Picker Interface
# ------------------------------------------------------------------------------
# Usage:
#   printf '%s\n' "${items[@]}" | _zledit_invoke_picker <picker> <prompt> [header] [binds] [preview_args...]
# Returns:
#   _ze_result_key - action key (empty for basic selection)
#   _ze_result_selection - selected item(s)
# ------------------------------------------------------------------------------

_zledit_invoke_picker() {
    local picker="$1" prompt="$2" header="$3" binds="$4"
    shift 4
    local -a preview_args=("$@")

    # Set invocation context for adapter
    _ze_invoke_prompt="$prompt"
    _ze_invoke_header="$header"
    _ze_invoke_binds="$binds"
    _ze_invoke_preview_args=("${preview_args[@]}")

    # Clear results
    _ze_result_key=""
    _ze_result_selection=""

    # Dispatch to adapter
    local adapter_fn="_zledit_adapter_${picker}"
    if (( $+functions[$adapter_fn] )); then
        $adapter_fn
    else
        echo "zledit: unknown picker '$picker'" >&2
        return 1
    fi
}

_zledit_supports_binds() {
    [[ "$1" == fzf* || "$1" == sk ]]
}

# ------------------------------------------------------------------------------
# Overlay (visual hints on command line)
# ------------------------------------------------------------------------------

# Hint keys: home row first, then top row, then bottom
typeset -ga _ze_hint_keys=(a s d f g h j k l q w e r t y u i o p z x c v b n m)

_zledit_build_overlay() {
    local -a hints=(a s d f g h j k l q w e r t y u i o p z x c v b n m)
    local i=1 pos word last_end=0 result=""
    while (( i <= ${#_ze_words[@]} )); do
        pos=${_ze_positions[$i]}
        word=${_ze_words[$i]}
        result+="${BUFFER:$last_end:$((pos - last_end))}"
        (( i <= ${#hints[@]} )) && result+="[${hints[$i]}]${word}" || result+="[${i}]${word}"
        last_end=$((pos + ${#word}))
        (( i++ ))
    done
    result+="${BUFFER:$last_end}"
    REPLY="$result"
}

# Highlight hint keys [a] [s] [27] etc with color via region_highlight
_zledit_highlight_hints() {
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
_zledit_hint_to_index() {
    local hint="$1" i
    for i in {1..${#_ze_hint_keys[@]}}; do
        [[ "${_ze_hint_keys[$i]}" == "$hint" ]] && { echo "$i"; return 0; }
    done
    # Fallback: if it's a number, use directly
    [[ "$hint" =~ ^[0-9]+$ ]] && echo "$hint"
}

# ------------------------------------------------------------------------------
# Tokenizer
# ------------------------------------------------------------------------------

_zledit_tokenize() {
    emulate -L zsh
    _ze_words=()
    _ze_positions=()

    local i=0 word_start=-1 in_word=0
    local len=${#BUFFER}

    while (( i < len )); do
        if [[ "${BUFFER:$i:1}" == [[:space:]] ]]; then
            if (( in_word )); then
                local word="${BUFFER:$word_start:$((i - word_start))}"
                [[ "$word" != "\\" ]] && {
                    _ze_words+=("$word")
                    _ze_positions+=($word_start)
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
            _ze_words+=("$word")
            _ze_positions+=($word_start)
        }
    fi
}

# Build preview command
# Returns preview command string via REPLY
_zledit_build_preview_cmd() {
    emulate -L zsh
    # Simple approach: use external script to avoid quoting hell
    local script="${Zledit[dir]}/preview.sh"
    if [[ -x "$script" ]]; then
        # Inline env vars for fzf-tmux compatibility (tmux panes don't inherit exports)
        local env_prefix=""
        if (( ${#_ze_previewer_patterns[@]} > 0 )); then
            local patterns="${(pj:\n:)_ze_previewer_patterns}"
            local scripts="${(pj:\n:)_ze_previewer_scripts}"
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

zledit-widget() {
    emulate -L zsh
    setopt local_options no_xtrace no_verbose

    local picker="${Zledit[picker]}"
    if [[ -z "$picker" ]]; then
        zle -M "zledit: no picker found (install fzf, sk, peco, or percol)"
        return 1
    fi

    _zledit_tokenize
    [[ ${#_ze_words[@]} -eq 0 ]] && return 0

    # Build numbered list for fzf (letters shown via overlay after instant-key)
    local -a numbered
    local i
    for i in {1..${#_ze_words[@]}}; do
        numbered+=("$i: ${_ze_words[$i]}")
    done

    # Use pre-loaded config from Zledit array (no zstyle reads during widget)
    local header="" binds=""
    local -a preview_args=()

    if _zledit_supports_binds "$picker"; then
        local ik=${Zledit[instant-key]}

        # Build header and bindings dynamically from action arrays
        local ai binding desc key_display
        local -a header_parts=()
        for ai in {1..${#_ze_action_bindings[@]}}; do
            binding="${_ze_action_bindings[$ai]}"
            [[ -z "$binding" ]] && continue
            desc="${_ze_action_descriptions[$ai]}"
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
        for ai in {1..${#_ze_action_bindings[@]}}; do
            [[ -z "${_ze_action_bindings[$ai]}" ]] && continue
            binds+=",${_ze_action_bindings[$ai]}:print(action-${ai})+accept"
        done

        binds+="$hint_binds"
        # Letter keys unbound initially; instant-key rebinds them for direct jump
        binds+=",start:unbind($unbinds)"
        binds+=",${ik}:rebind($rebinds)"
        # Preview scroll
        binds+=",ctrl-d:preview-page-down,ctrl-u:preview-page-up"

        if [[ "${Zledit[preview]}" != "off" ]]; then
            _zledit_build_preview_cmd
            local preview_cmd="$REPLY"
            preview_args=(--preview "$preview_cmd" --preview-window "${Zledit[preview-window]}")
        fi
    fi

    # Always save original buffer (for safe restoration)
    local saved_buffer="$BUFFER"

    # Show overlay on command line with highlighted hints
    if [[ "${Zledit[overlay]}" != "off" ]]; then
        _zledit_build_overlay
        BUFFER="$REPLY"
        _zledit_highlight_hints
        zle -R
    fi

    # Invoke picker
    zle -I
    printf '%s\n' "${numbered[@]}" | _zledit_invoke_picker "$picker" "jump> " "$header" "$binds" "${preview_args[@]}"

    # Clear overlay line from terminal scrollback (move up, clear line)
    [[ "${Zledit[overlay]}" != "off" ]] && print -n '\e[1A\e[2K'

    # Restore original buffer and clear highlights
    region_highlight=()
    BUFFER="$saved_buffer"

    # Handle instant hint keys (hint-a, hint-s, etc)
    if [[ "$_ze_result_key" == hint-* ]]; then
        local hint_char="${_ze_result_key#hint-}"
        local hint_idx="$(_zledit_hint_to_index "$hint_char")"
        if [[ -n "$hint_idx" ]] && (( hint_idx >= 1 && hint_idx <= ${#_ze_words[@]} )); then
            _zledit_do_jump "${hint_idx}: ${_ze_words[$hint_idx]}"
        fi
        zle reset-prompt
        return 0
    fi

    [[ -z "$_ze_result_selection" ]] && { zle reset-prompt; return 0; }

    # Handle result based on action key
    local -a selections=("${(@f)_ze_result_selection}")

    case "$_ze_result_key" in
        action-*)
            # All actions (built-in and custom) use external scripts
            local action_idx="${_ze_result_key#action-}"
            _zledit_do_custom_action "$action_idx" "${selections[@]}"
            ;;
        *)
            # Default: jump to selection
            _zledit_do_jump "${selections[@]}"
            ;;
    esac

    zle reset-prompt
}

# ------------------------------------------------------------------------------
# Actions
# ------------------------------------------------------------------------------

# Extract index from selection format: "a: word" or "123: word"
# Returns numeric index (1-based)
_zledit_extract_index() {
    local sel="$1" key
    # Extract key before colon
    key="${sel%%:*}"
    # If it's a single letter, convert to index
    if [[ "$key" =~ ^[a-z]$ ]]; then
        _zledit_hint_to_index "$key"
    else
        echo "$key"
    fi
}

_zledit_do_jump() {
    local sel="$1"
    [[ -z "$sel" ]] && return 1

    local idx="$(_zledit_extract_index "$sel")"
    [[ "$idx" =~ ^[0-9]+$ ]] || return 1
    (( idx < 1 || idx > ${#_ze_words[@]} )) && return 1

    local pos="${_ze_positions[$idx]}"
    local target="${_ze_words[$idx]}"

    case "${Zledit[cursor]}" in
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
#     4 = push-line + auto-execute (same format, but executes pushed_line immediately)
_zledit_do_custom_action() {
    emulate -L zsh
    local action_idx="$1" sel="$2"
    [[ -z "$sel" ]] && return 1

    # Validate action index
    (( action_idx < 1 || action_idx > ${#_ze_action_scripts[@]} )) && return 1

    local script="${_ze_action_scripts[$action_idx]}"
    [[ ! -x "$script" ]] && {
        zle -M "zledit: action script not executable: $script"
        return 1
    }

    # Get selected token
    local token_idx="$(_zledit_extract_index "$sel")"
    [[ "$token_idx" =~ ^[0-9]+$ ]] || return 1
    (( token_idx < 1 || token_idx > ${#_ze_words[@]} )) && return 1
    local token="${_ze_words[$token_idx]}"

    # Export environment for script
    local result stderr_file=$(mktemp)
    result=$(
        export ZJ_BUFFER="$BUFFER"
        export ZJ_WORDS="${(pj:\n:)_ze_words}"
        export ZJ_POSITIONS="${(pj:\n:)_ze_positions}"
        export ZJ_CURSOR="$CURSOR"
        export ZJ_PICKER="${Zledit[picker]}"
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
                    CURSOR="${_ze_positions[$token_idx]}"  # Default to token position
                fi
            fi
            ;;
        1)  # Error
            [[ -n "$stderr_out" ]] && zle -M "zledit: action failed: $stderr_out"
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
                new_buffer="${new_buffer%$'\n'}"
                pushed_line="${pushed_line#$'\n'}"
                BUFFER="$new_buffer"
                CURSOR="${_ze_positions[$token_idx]}"
                zle push-line
                # Check for CURSOR:N in pushed_line
                local last_line="${pushed_line##*$'\n'}"
                if [[ "$last_line" =~ ^CURSOR:([0-9]+)$ ]]; then
                    BUFFER="${pushed_line%$'\n'*}"
                    CURSOR="${match[1]}"
                else
                    BUFFER="$pushed_line"
                    CURSOR=${#BUFFER}
                fi
            fi
            ;;
        4)  # Push-line + auto-execute
            if [[ "$result" == *"---ZJ_PUSHLINE---"* ]]; then
                local new_buffer="${result%%---ZJ_PUSHLINE---*}"
                local pushed_line="${result#*---ZJ_PUSHLINE---}"
                new_buffer="${new_buffer%$'\n'}"
                pushed_line="${pushed_line#$'\n'}"
                BUFFER="$new_buffer"
                zle push-line
                BUFFER="$pushed_line"
                zle accept-line
            fi
            ;;
    esac
}

zle -N zledit-widget

# ------------------------------------------------------------------------------
# Keybindings
# ------------------------------------------------------------------------------

zledit-setup-bindings() {
    emulate -L zsh

    if zstyle -t ':zledit:' disable-bindings; then
        return 0
    fi

    local key
    zstyle -s ':zledit:' binding key || key='^X/'
    bindkey "$key" zledit-widget
}

zledit-setup-bindings

# ------------------------------------------------------------------------------
# List registered actions/previewers
# ------------------------------------------------------------------------------

zledit-list() {
    emulate -L zsh
    local i val
    print "Config:"
    print "  plugin:  ${Zledit[dir]}"
    zstyle -s ':zledit:' config val && print "  config:  $val"
    print "  picker:  ${Zledit[picker]}"
    print "  binding: $(bindkey | grep zledit-widget | awk '{print $1}')"
    print "\nActions:"
    for i in {1..${#_ze_action_bindings[@]}}; do
        printf "  %-10s %-10s %s\n" "${_ze_action_bindings[$i]}" "${_ze_action_descriptions[$i]}" "${_ze_action_scripts[$i]}"
    done
    print "\nPreviewers:"
    for i in {1..${#_ze_previewer_patterns[@]}}; do
        printf "  %-12s %s\n" "${_ze_previewer_descriptions[$i]}" "${_ze_previewer_scripts[$i]}"
    done
}

# ------------------------------------------------------------------------------
# Unload (for plugin managers like zinit)
# ------------------------------------------------------------------------------

zledit-unload() {
    emulate -L zsh

    zle -D zledit-widget 2>/dev/null

    unfunction zledit-widget _zledit_load_config \
               _zledit_load_default_actions \
               _zledit_invoke_picker _zledit_tokenize \
               _zledit_supports_binds _zledit_do_jump \
               _zledit_do_custom_action \
               _zledit_adapter_fzf _zledit_adapter_fzf-tmux \
               _zledit_adapter_sk _zledit_adapter_peco \
               _zledit_adapter_percol _zledit_adapter_fzflike \
               _zledit_adapter_simple _zledit_extract_index \
               _zledit_build_overlay _zledit_hint_to_index \
               _zledit_highlight_hints _zledit_build_preview_cmd \
               _zledit_parse_toml _zledit_save_toml_item \
               zledit-setup-bindings zledit-list zledit-unload 2>/dev/null

    unset '_ze_words' '_ze_positions' '_ze_result_key' '_ze_result_selection' \
          '_ze_invoke_prompt' '_ze_invoke_header' '_ze_invoke_binds' \
          '_ze_invoke_preview_args' '_ze_hint_keys' \
          '_ze_previewer_patterns' '_ze_previewer_descriptions' '_ze_previewer_scripts' \
          '_ze_action_bindings' '_ze_action_descriptions' '_ze_action_scripts'
    unset Zledit

    return 0
}

# Register unload hook if zinit supports it
if (( $+functions[@zsh-plugin-run-on-unload] )); then
    @zsh-plugin-run-on-unload 'zledit-unload'
fi

return 0
