#!/usr/bin/env bash
# zledit action: move (swap token positions)
# Args: $1 = token, $2 = index (1-based)
# Env:  ZJ_BUFFER, ZJ_POSITIONS, ZJ_WORDS, ZJ_PICKER

set -eo pipefail

TOKEN="$1"
INDEX="$2"

[[ -z "$TOKEN" || -z "$INDEX" || -z "$ZJ_BUFFER" || -z "$ZJ_POSITIONS" || -z "$ZJ_WORDS" ]] && exit 1

IFS=$'\n' read -r -d '' -a positions <<< "$ZJ_POSITIONS" || true
IFS=$'\n' read -r -d '' -a words <<< "$ZJ_WORDS" || true

num_tokens=${#words[@]}
(( num_tokens < 2 )) && exit 1

# Build list of other tokens
destinations=""
for i in $(seq 1 "$num_tokens"); do
    (( i == INDEX )) && continue
    destinations+="${destinations:+$'\n'}$i: ${words[$((i-1))]}"
done

# Determine picker
picker="${ZJ_PICKER:-}"
if [[ -z "$picker" ]]; then
    if [[ -n "$TMUX" ]] && command -v fzf-tmux &>/dev/null; then
        picker="fzf-tmux"
    elif command -v fzf &>/dev/null; then
        picker="fzf"
    else
        exit 1
    fi
fi

# Show picker
case "$picker" in
    fzf-tmux) selected=$(echo "$destinations" | fzf-tmux --reverse --prompt="swap with> ") || exit 1 ;;
    sk)       selected=$(echo "$destinations" | sk --height=15 --reverse --prompt="swap with> ") || exit 1 ;;
    *)        selected=$(echo "$destinations" | fzf --height=15 --reverse --prompt="swap with> ") || exit 1 ;;
esac

[[ -z "$selected" ]] && exit 1

dest_idx="${selected%%:*}"

# Get positions and tokens for swap
src_pos="${positions[$((INDEX-1))]}"
src_word="${words[$((INDEX-1))]}"
dest_pos="${positions[$((dest_idx-1))]}"
dest_word="${words[$((dest_idx-1))]}"

# Swap tokens (lower position first to avoid offset issues)
if (( src_pos < dest_pos )); then
    echo "${ZJ_BUFFER:0:$src_pos}${dest_word}${ZJ_BUFFER:$((src_pos + ${#src_word})):$((dest_pos - src_pos - ${#src_word}))}${src_word}${ZJ_BUFFER:$((dest_pos + ${#dest_word}))}"
else
    echo "${ZJ_BUFFER:0:$dest_pos}${src_word}${ZJ_BUFFER:$((dest_pos + ${#dest_word})):$((src_pos - dest_pos - ${#dest_word}))}${dest_word}${ZJ_BUFFER:$((src_pos + ${#src_word}))}"
fi

# Metadata via fd 3 (skip if fd 3 not open)
[[ -e /dev/fd/3 ]] && echo "mode:replace" >&3
