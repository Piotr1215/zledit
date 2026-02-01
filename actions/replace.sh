#!/usr/bin/env bash
# zledit action: replace (delete token)
# Args: $1 = token, $2 = index (1-based)
# Env:  ZJ_BUFFER, ZJ_POSITIONS
# Output: new buffer with token removed
# Metadata: mode:replace, cursor at deletion point

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

# Output new buffer to stdout
echo "${ZJ_BUFFER:0:$pos}${ZJ_BUFFER:$end_pos}"

# Metadata via fd 3 (skip if fd 3 not open)
if [[ -e /dev/fd/3 ]]; then
    echo "mode:replace" >&3
    echo "cursor:$pos" >&3
fi
