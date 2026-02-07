#!/usr/bin/env bash
# zledit action: path (path manipulation)
# Args: $1 = token, $2 = index (1-based)
# Env:  ZJ_BUFFER, ZJ_POSITIONS, ZJ_PICKER
# Output: new buffer with transformed path

set -eo pipefail

TOKEN="$1"
INDEX="$2"

[[ -z "$TOKEN" || -z "$INDEX" || -z "$ZJ_BUFFER" || -z "$ZJ_POSITIONS" ]] && exit 1

# Get position from ZJ_POSITIONS
IFS=$'\n' read -r -d '' -a positions <<< "$ZJ_POSITIONS" || true
pos="${positions[$((INDEX - 1))]}"

[[ -z "$pos" ]] && exit 1

# Expand ~ for existence check
expanded_token="${TOKEN/#\~/$HOME}"

# Validate token exists on filesystem (file, dir, symlink)
# If not, silently return buffer unchanged
if [[ ! -e "$expanded_token" ]]; then
    echo "$ZJ_BUFFER"
    [[ -e /dev/fd/3 ]] && echo "mode:replace" >&3
    exit 0
fi

# Path operations menu
operations='dirname      parent directory
basename     filename only
absolute     make absolute path
no-ext       remove extension
add-bak      add .bak extension
up-one       go up one directory level
realpath     resolve symlinks'

# Determine picker
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

# Show picker
case "$picker" in
    fzf-tmux) selected=$(echo "$operations" | fzf-tmux --reverse --prompt="path> " --header="$TOKEN") || exit 1 ;;
    sk)       selected=$(echo "$operations" | sk --height=15 --reverse --prompt="path> " --header="$TOKEN") || exit 1 ;;
    *)        selected=$(echo "$operations" | fzf --height=15 --reverse --prompt="path> " --header="$TOKEN") || exit 1 ;;
esac

[[ -z "$selected" ]] && exit 1

op="${selected%%[[:space:]]*}"

# Apply transformation
case "$op" in
    dirname)   result=$(dirname "$TOKEN") ;;
    basename)  result=$(basename "$TOKEN") ;;
    absolute)
        if [[ "$TOKEN" == /* ]]; then
            result="$TOKEN"
        elif [[ "$TOKEN" == ~* ]]; then
            result="${TOKEN/#\~/$HOME}"
        else
            result="$(pwd)/$TOKEN"
        fi
        ;;
    no-ext)    result="${TOKEN%.*}" ;;
    add-bak)   result="${TOKEN}.bak" ;;
    up-one)    result=$(dirname "$TOKEN")/.. ;;
    realpath)
        if command -v realpath &>/dev/null; then
            # Use -m to handle non-existent paths
            result=$(realpath -m "$TOKEN" 2>/dev/null) || result="$TOKEN"
        else
            result="$TOKEN"
        fi
        ;;
    *)         exit 1 ;;
esac

# Build new buffer
end_pos=$((pos + ${#TOKEN}))
new_buffer="${ZJ_BUFFER:0:$pos}${result}${ZJ_BUFFER:$end_pos}"

echo "$new_buffer"

# Metadata via fd 3
if [[ -e /dev/fd/3 ]]; then
    echo "mode:replace" >&3
    echo "cursor:$pos" >&3
fi
