#!/usr/bin/env bash
# zsh-jumper action: wrap (wrap token with quotes/brackets)
# Args: $1 = token, $2 = index (1-based)
# Env:  ZJ_BUFFER, ZJ_POSITIONS, ZJ_PICKER (optional: fzf-tmux, fzf, sk)
# Output: new buffer with wrapped token
# Exit: 0

set -eo pipefail

TOKEN="$1"
INDEX="$2"

[[ -z "$TOKEN" || -z "$INDEX" || -z "$ZJ_BUFFER" || -z "$ZJ_POSITIONS" ]] && exit 1

# Get position from ZJ_POSITIONS
IFS=$'\n' read -r -d '' -a positions <<< "$ZJ_POSITIONS" || true
pos="${positions[$((INDEX - 1))]}"

[[ -z "$pos" ]] && exit 1

# Wrapper options
wrappers='"..."   double quote
'"'"'...'"'"'   single quote
"$..."  quoted variable
${...}  variable expansion
$(...)  command substitution
`...`   backtick / legacy subshell
[...]   square brackets / test
{...}   curly braces / brace expansion
(...)   parentheses / subshell
<...>   angle brackets / redirect'

# Determine picker - prefer ZJ_PICKER env var, then detect
picker="${ZJ_PICKER:-}"
if [[ -z "$picker" ]]; then
    if [[ -n "$TMUX" ]] && command -v fzf-tmux &>/dev/null; then
        picker="fzf-tmux"
    elif command -v fzf &>/dev/null; then
        picker="fzf"
    else
        exit 1
    fi
fi

# Use picker to select wrapper
if [[ "$picker" == "fzf-tmux" ]]; then
    selected=$(echo "$wrappers" | fzf-tmux --reverse --prompt="wrap> " --header="Select wrapper") || exit 1
elif [[ "$picker" == "sk" ]]; then
    selected=$(echo "$wrappers" | sk --height=15 --reverse --prompt="wrap> " --header="Select wrapper") || exit 1
else
    selected=$(echo "$wrappers" | fzf --height=15 --reverse --prompt="wrap> " --header="Select wrapper") || exit 1
fi

[[ -z "$selected" ]] && exit 1

# Parse selection
wrapper_type="${selected%%[[:space:]]*}"

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
    *)         exit 1 ;;
esac

# Apply wrapper
end_pos=$((pos + ${#TOKEN}))
new_buffer="${ZJ_BUFFER:0:$pos}${open}${TOKEN}${close}${ZJ_BUFFER:$end_pos}"

# Cursor after opening wrapper (on the wrapped content)
cursor_pos=$((pos + ${#open}))

echo "$new_buffer"
echo "CURSOR:${cursor_pos}"
