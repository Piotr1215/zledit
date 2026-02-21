#!/usr/bin/env bash
# zledit action: var (extract to variable)
# Args: $1 = token, $2 = index (1-based)
# Env:  ZJ_BUFFER, ZJ_POSITIONS
# Output: new buffer to stdout
# Metadata: mode:pushline, pushline command via fd 3

set -eo pipefail

TOKEN="$1"
INDEX="$2"

[[ -z "$TOKEN" || -z "$INDEX" || -z "$ZJ_BUFFER" || -z "$ZJ_POSITIONS" ]] && exit 1

# Get position from ZJ_POSITIONS
IFS=$'\n' read -r -d '' -a positions <<< "$ZJ_POSITIONS" || true
pos="${positions[$((INDEX - 1))]}"

[[ -z "$pos" ]] && exit 1

# Strip quotes and $ prefix for variable name generation
base="$TOKEN"
base="${base#\$}"      # Strip leading $
base="${base#\"}"      # Strip leading "
base="${base%\"}"      # Strip trailing "
base="${base#\'}"      # Strip leading '
base="${base%\'}"      # Strip trailing '

# Generate variable name (uppercase, replace non-alphanumeric with _)
var_name=$(echo "$base" | tr '[:lower:]' '[:upper:]' | sed 's/[^A-Z0-9]/_/g')

# Replace ALL occurrences right-to-left (pushline mode bypasses batch-apply)
IFS=$'\n' read -r -d '' -a words <<< "$ZJ_WORDS" || true
ref="\"\$${var_name}\""
new_buffer="$ZJ_BUFFER"

# Collect all positions of this token, sort descending
all_pos=()
for i in "${!words[@]}"; do
    [[ "${words[$i]}" == "$TOKEN" ]] && all_pos+=("${positions[$i]}")
done
IFS=$'\n' sorted=($(printf '%s\n' "${all_pos[@]}" | sort -rn)); unset IFS

for p in "${sorted[@]}"; do
    end_pos=$((p + ${#TOKEN}))
    new_buffer="${new_buffer:0:$p}${ref}${new_buffer:$end_pos}"
done

# For the assignment, use the original base value (unquoted content)
# Escape double quotes in base for assignment
escaped_base="${base//\"/\\\"}"
pushed_line="export ${var_name}=\"${escaped_base}\""

# Output new buffer to stdout
echo "$new_buffer"

# Metadata via fd 3 (skip if fd 3 not open)
if [[ -e /dev/fd/3 ]]; then
    echo "mode:pushline" >&3
    echo "pushline:$pushed_line" >&3
fi
