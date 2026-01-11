#!/usr/bin/env bash
# Example action: Convert token to lowercase
# Binding suggestion: ctrl-l

set -eo pipefail

TOKEN="$1"
INDEX="$2"

[[ -z "$TOKEN" || -z "$INDEX" || -z "$ZJ_BUFFER" || -z "$ZJ_POSITIONS" ]] && exit 1

IFS=$'\n' read -r -d '' -a positions <<< "$ZJ_POSITIONS" || true
pos="${positions[$((INDEX - 1))]}"
[[ -z "$pos" ]] && exit 1

lower=$(echo "$TOKEN" | tr '[:upper:]' '[:lower:]')
end_pos=$((pos + ${#TOKEN}))

# Output new buffer (cursor defaults to token position)
echo "${ZJ_BUFFER:0:$pos}${lower}${ZJ_BUFFER:$end_pos}"
