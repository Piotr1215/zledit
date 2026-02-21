#!/usr/bin/env bash
# zledit action: replace (deferred mode for batch-apply)
# Args: $1 = token, $2 = index (1-based)
# Env:  ZJ_BUFFER, ZJ_POSITIONS
# Signals mode:deferred via fd3 — widget handles replacement via recursive-edit

set -eo pipefail

TOKEN="$1"
INDEX="$2"

[[ -z "$TOKEN" || -z "$INDEX" || -z "$ZJ_BUFFER" || -z "$ZJ_POSITIONS" ]] && exit 1

# Metadata via fd 3 (skip if fd 3 not open)
if [[ -e /dev/fd/3 ]]; then
    echo "mode:deferred" >&3
fi
