#!/usr/bin/env bash
# zsh-jumper action: replace (delete token)
# Args: $1 = token, $2 = index (1-based)
# Env:  ZJ_BUFFER, ZJ_WORDS, ZJ_POSITIONS
# Output: new buffer with token removed + cursor position
# Exit: 0

set -eo pipefail

TOKEN="$1"
INDEX="$2"

[[ -z "$TOKEN" || -z "$INDEX" || -z "$ZJ_BUFFER" || -z "$ZJ_POSITIONS" ]] && exit 1

# Get position from ZJ_POSITIONS (newline-separated, 0-indexed array)
IFS=$'\n' read -r -d '' -a positions <<< "$ZJ_POSITIONS" || true
pos="${positions[$((INDEX - 1))]}"

[[ -z "$pos" ]] && exit 1

# Calculate end position
end_pos=$((pos + ${#TOKEN}))

# Remove token from buffer (cursor defaults to token position)
echo "${ZJ_BUFFER:0:$pos}${ZJ_BUFFER:$end_pos}"
