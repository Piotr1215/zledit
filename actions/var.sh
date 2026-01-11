#!/usr/bin/env bash
# zsh-jumper action: var (extract to variable)
# Args: $1 = token, $2 = index (1-based)
# Env:  ZJ_BUFFER, ZJ_POSITIONS
# Output: new buffer + push-line content (separated by ---ZJ_PUSHLINE---)
# Exit: 3 (push-line mode)

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

# Calculate replacement - put variable reference in place of token
end_pos=$((pos + ${#TOKEN}))
new_buffer="${ZJ_BUFFER:0:$pos}\"\$${var_name}\"${ZJ_BUFFER:$end_pos}"

# For the assignment, use the original base value (unquoted content)
# Escape double quotes in base for assignment
escaped_base="${base//\"/\\\"}"
pushed_line="export ${var_name}=\"${escaped_base}\""

# Output in push-line format
echo "$new_buffer"
echo "---ZJ_PUSHLINE---"
echo "$pushed_line"

exit 3
