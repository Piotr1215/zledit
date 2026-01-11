#!/usr/bin/env bash
# Example previewer: Fetch URL title and preview
# Pattern: ^https?://

TOKEN="$1"
[[ -z "$TOKEN" ]] && TOKEN="$TOKEN"  # fallback to env var

# Quick curl to get page title
if command -v curl &>/dev/null; then
    title=$(curl -sL --max-time 3 "$TOKEN" 2>/dev/null | grep -oP '(?<=<title>).*(?=</title>)' | head -1)
    echo "URL: $TOKEN"
    echo "Title: ${title:-Unable to fetch}"
else
    echo "URL: $TOKEN"
    echo "(curl not available for preview)"
fi
