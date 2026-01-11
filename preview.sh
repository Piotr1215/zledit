#!/usr/bin/env bash
# zsh-jumper preview handler
# Custom previewers via ZJ_PREVIEWER_PATTERNS and ZJ_PREVIEWER_SCRIPTS
set -eo pipefail

# Extract token from fzf selection "[x] N: value"
TOKEN="$1"
TOKEN="${TOKEN#*: }"         # Strip "[x] N: " prefix only
export TOKEN

# Check custom previewers (raw token, scripts handle sanitization)
if [[ -n "$ZJ_PREVIEWER_PATTERNS" && -n "$ZJ_PREVIEWER_SCRIPTS" ]]; then
    IFS=$'\n' read -r -d '' -a patterns <<< "$ZJ_PREVIEWER_PATTERNS" || true
    IFS=$'\n' read -r -d '' -a scripts <<< "$ZJ_PREVIEWER_SCRIPTS" || true

    for i in "${!patterns[@]}"; do
        [[ ! -x "${scripts[$i]}" ]] && continue
        if [[ "$TOKEN" =~ ${patterns[$i]} ]]; then
            "${scripts[$i]}" "$TOKEN" && exit 0
        fi
    done
fi

# Default: file/directory preview
if [[ -d "$TOKEN" ]]; then
    ls -la "$TOKEN" 2>/dev/null
elif [[ -f "$TOKEN" ]]; then
    command -v bat &>/dev/null && bat --style=plain --color=always -n --line-range=:30 "$TOKEN" 2>/dev/null || head -30 "$TOKEN" 2>/dev/null
fi
