#!/usr/bin/env bash
# zsh-jumper action: help (show help for token)
# Args: $1 = token
# Env:  ZJ_WORDS
# Output: help text to display
# Exit: 2 (display mode - shows output but doesn't modify buffer)

set -eo pipefail

TOKEN="$1"

[[ -z "$TOKEN" || -z "$ZJ_WORDS" ]] && exit 1

# Get command (first word)
IFS=$'\n' read -r -d '' -a words <<< "$ZJ_WORDS" || true
cmd="${words[0]}"

help_text=""

# If token is a flag and command exists, search command's help
if [[ "$TOKEN" == -* ]] && command -v "$cmd" &>/dev/null; then
    help_output=$("$cmd" --help 2>&1 || true)
    # Find lines containing the flag
    matching=$(echo "$help_output" | grep -F -- "$TOKEN" | head -20)
    if [[ -n "$matching" ]]; then
        help_text="=== $cmd: $TOKEN ===
$matching"
    fi
# If token itself is a command
elif command -v "$TOKEN" &>/dev/null; then
    help_text="=== $TOKEN ===
$("$TOKEN" --help 2>&1 | head -30 || true)"
fi

if [[ -n "$help_text" ]]; then
    echo "$help_text"
    exit 2
else
    echo "No help for: $TOKEN" >&2
    exit 1
fi
