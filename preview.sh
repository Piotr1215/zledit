#!/usr/bin/env bash
# zsh-jumper preview handler
# Custom previewers are passed via ZJ_PREVIEWER_PATTERNS and ZJ_PREVIEWER_SCRIPTS
set -eo pipefail

# Extract token from fzf selection "[prefix] N: value"
TOKEN="$1"
TOKEN="${TOKEN#*: }"         # Strip "prefix N: "
TOKEN="${TOKEN#\[*\] }"      # Strip "[x] " if still present
TOKEN="${TOKEN//\"/}"        # Strip double quotes
TOKEN="${TOKEN//\'/}"        # Strip single quotes
[[ "$TOKEN" == *=* ]] && TOKEN="${TOKEN##*=}"    # VAR=value -> value
[[ "$TOKEN" == ~* ]] && TOKEN="$HOME${TOKEN#\~}" # Expand tilde

export TOKEN

# Check custom previewers (patterns and scripts passed via env)
if [[ -n "$ZJ_PREVIEWER_PATTERNS" && -n "$ZJ_PREVIEWER_SCRIPTS" ]]; then
    # Read patterns and scripts into arrays
    IFS=$'\n' read -r -d '' -a patterns <<< "$ZJ_PREVIEWER_PATTERNS" || true
    IFS=$'\n' read -r -d '' -a scripts <<< "$ZJ_PREVIEWER_SCRIPTS" || true

    for i in "${!patterns[@]}"; do
        pattern="${patterns[$i]}"
        script="${scripts[$i]}"

        # Skip if script doesn't exist or isn't executable
        [[ ! -x "$script" ]] && continue

        # Match pattern against token (extended regex)
        if [[ "$TOKEN" =~ $pattern ]]; then
            # Execute script with token as argument
            # Script contract: output preview to stdout, exit 0
            "$script" "$TOKEN" && exit 0
        fi
    done
fi

# Legacy hook support (deprecated, for backwards compatibility)
HOOK="${HOME}/.config/zsh-jumper/preview-hook.sh"
if [[ -x "$HOOK" ]] && "$HOOK"; then
    exit 0
fi

# Default: file/directory preview
if [[ -d "$TOKEN" ]]; then
    ls -la "$TOKEN" 2>/dev/null
elif [[ -f "$TOKEN" ]]; then
    if command -v bat &>/dev/null; then
        bat --style=plain --color=always -n --line-range=:30 "$TOKEN" 2>/dev/null
    else
        head -30 "$TOKEN" 2>/dev/null
    fi
fi
