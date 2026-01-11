#!/usr/bin/env bash
# zledit preview handler
set -eo pipefail

TOKEN="$1"
TOKEN="${TOKEN#*: }"  # Strip "N: " prefix
export TOKEN

# Check custom previewers first (user overrides)
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

# Command help: --help → tldr → man (with colors)
if command -v "$TOKEN" &>/dev/null; then
    # --help with bat highlighting if available
    if command -v bat &>/dev/null; then
        result=$("$TOKEN" --help 2>&1 | head -50 | bat --style=plain --color=always -l help 2>/dev/null) && [[ -n "$result" ]] && { echo "$result"; exit 0; }
    else
        result=$("$TOKEN" --help 2>&1 | head -50) && [[ -n "$result" ]] && { echo "$result"; exit 0; }
    fi
    # tldr with color as fallback
    if command -v tldr &>/dev/null; then
        result=$(tldr --color=always "$TOKEN" 2>/dev/null) && [[ -n "$result" ]] && { echo "$result"; exit 0; }
    fi
    # man with color
    if command -v man &>/dev/null; then
        GROFF_NO_SGR=1 man --color=always "$TOKEN" 2>/dev/null | head -60 && exit 0
    fi
fi

# File/directory preview (with colors)
if [[ -d "$TOKEN" ]]; then
    ls -la --color=always "$TOKEN" 2>/dev/null
elif [[ -f "$TOKEN" ]]; then
    command -v bat &>/dev/null && bat --style=plain --color=always -n --line-range=:30 "$TOKEN" 2>/dev/null || head -30 "$TOKEN" 2>/dev/null
fi
