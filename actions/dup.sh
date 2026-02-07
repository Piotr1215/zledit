#!/usr/bin/env bash
# zledit action: dup (duplicate token)
# Args: $1 = token, $2 = index (1-based)
# Env:  ZJ_BUFFER, ZJ_POSITIONS
# Output: new buffer with token duplicated
# Metadata: mode:replace, cursor on second copy

set -eo pipefail

TOKEN="$1"
INDEX="$2"

[[ -z "$TOKEN" || -z "$INDEX" || -z "$ZJ_BUFFER" || -z "$ZJ_POSITIONS" ]] && exit 1

# Get position from ZJ_POSITIONS
IFS=$'\n' read -r -d '' -a positions <<< "$ZJ_POSITIONS" || true
pos="${positions[$((INDEX - 1))]}"

[[ -z "$pos" ]] && exit 1

# Insert duplicate after token with space separator
end_pos=$((pos + ${#TOKEN}))
new_buffer="${ZJ_BUFFER:0:$end_pos} ${TOKEN}${ZJ_BUFFER:$end_pos}"

# Cursor at start of the duplicate (for editing)
cursor_pos=$((end_pos + 1))

echo "$new_buffer"

# Metadata via fd 3 (skip if fd 3 not open)
if [[ -e /dev/fd/3 ]]; then
    echo "mode:replace" >&3
    echo "cursor:$cursor_pos" >&3
fi
