# Extensibility Guide

Step-by-step guide for writing custom previewers and actions.

## How It Works

Place your config file anywhere. Point zledit to it via zstyle:

```zsh
zstyle ':zledit:' config /path/to/config.toml
```

The plugin loads your config at startup and registers previewers and actions in the order they appear. User-defined bindings take precedence over built-in defaults.

## Quick Start

1. Create a TOML config file:
```toml
[[actions]]
binding = 'ctrl-u'
description = 'upper'
script = '/path/to/your/uppercase.sh'
```

2. Write your script (put it wherever you like):
```bash
#!/usr/bin/env bash
set -eo pipefail

TOKEN="$1"
INDEX="$2"

[[ -z "$TOKEN" || -z "$INDEX" || -z "$ZJ_BUFFER" || -z "$ZJ_POSITIONS" ]] && exit 1

IFS=$'\n' read -r -d '' -a positions <<< "$ZJ_POSITIONS" || true
pos="${positions[$((INDEX - 1))]}"
[[ -z "$pos" ]] && exit 1

upper=$(echo "$TOKEN" | tr '[:lower:]' '[:upper:]')
end_pos=$((pos + ${#TOKEN}))

echo "${ZJ_BUFFER:0:$pos}${upper}${ZJ_BUFFER:$end_pos}"
```

3. Make it executable:
```bash
chmod +x /path/to/your/uppercase.sh
```

4. Reload shell and test with `Ctrl+X /` then `Ctrl+U` on a token.

## Writing Actions

Actions manipulate the command line buffer. They receive the selected token and must output the modified buffer.

### Input

Your script receives:

| Source | Content |
|--------|---------|
| `$1` | Selected token text |
| `$2` | Token index (1-based) |
| `ZJ_BUFFER` | Current command line |
| `ZJ_POSITIONS` | Newline-separated start positions |
| `ZJ_WORDS` | Newline-separated tokens |
| `ZJ_CURSOR` | Current cursor position |
| `ZJ_PICKER` | Active picker (fzf, fzf-tmux, sk) |

### Output & Exit Codes

| Exit | Behavior |
|------|----------|
| 0 | Apply stdout as new buffer |
| 1 | Error - show stderr message |
| 2 | Display mode - print stdout, no buffer change |
| 3 | Push-line - save buffer, show pushed command (user presses Enter) |
| 4 | Push-line + auto-execute - save buffer, execute pushed command immediately |

For exit codes 3 and 4, use this output format:
```
original_buffer_to_restore
---ZJ_PUSHLINE---
command_to_execute
```

Example: Smart edit action that opens files in editor then returns to original command:
```bash
echo "$ZJ_BUFFER"
echo "---ZJ_PUSHLINE---"
echo "\${EDITOR:-vim} \"$TOKEN\""
exit 4
```

### Cursor Position

By default, cursor stays at the original token position. To override, add `CURSOR:N` as the last line:
```
echo hello world
CURSOR:5
```

### Nested Pickers

If your action needs a secondary picker (like wrap showing wrapper options), use `ZJ_PICKER`:

```bash
if [[ "$ZJ_PICKER" == "fzf-tmux" ]]; then
    selected=$(echo "$options" | fzf-tmux --reverse --prompt="pick> ")
else
    selected=$(echo "$options" | fzf --height=15 --reverse --prompt="pick> ")
fi
```

### Example: Lowercase Action

```bash
#!/usr/bin/env bash
set -eo pipefail

TOKEN="$1"
INDEX="$2"

[[ -z "$TOKEN" || -z "$INDEX" || -z "$ZJ_BUFFER" || -z "$ZJ_POSITIONS" ]] && exit 1

# Parse positions
IFS=$'\n' read -r -d '' -a positions <<< "$ZJ_POSITIONS" || true
pos="${positions[$((INDEX - 1))]}"
[[ -z "$pos" ]] && exit 1

# Transform
lower=$(echo "$TOKEN" | tr '[:upper:]' '[:lower:]')

# Replace in buffer
end_pos=$((pos + ${#TOKEN}))
echo "${ZJ_BUFFER:0:$pos}${lower}${ZJ_BUFFER:$end_pos}"
```

### Example: Delete Token

```bash
#!/usr/bin/env bash
set -eo pipefail

TOKEN="$1"
INDEX="$2"

[[ -z "$TOKEN" || -z "$INDEX" || -z "$ZJ_BUFFER" || -z "$ZJ_POSITIONS" ]] && exit 1

IFS=$'\n' read -r -d '' -a positions <<< "$ZJ_POSITIONS" || true
pos="${positions[$((INDEX - 1))]}"
[[ -z "$pos" ]] && exit 1

end_pos=$((pos + ${#TOKEN}))
echo "${ZJ_BUFFER:0:$pos}${ZJ_BUFFER:$end_pos}"
```

## Writing Previewers

Previewers show context in fzf's preview window. They match tokens by regex pattern.

### Input

| Source | Content |
|--------|---------|
| `$1` | Token to preview (with index prefix stripped) |

### Output

Write preview content to stdout. No special formatting needed.

### Example: URL Preview

```bash
#!/usr/bin/env bash
TOKEN="$1"

if command -v curl &>/dev/null; then
    title=$(curl -sL --max-time 3 "$TOKEN" 2>/dev/null | \
            grep -oP '(?<=<title>).*(?=</title>)' | head -1)
    echo "URL: $TOKEN"
    echo "Title: ${title:-Unable to fetch}"
else
    echo "URL: $TOKEN"
    echo "(curl not available)"
fi
```

### Example: JSON Preview

```bash
#!/usr/bin/env bash
TOKEN="$1"

if [[ -f "$TOKEN" ]] && command -v jq &>/dev/null; then
    jq -C '.' "$TOKEN" 2>/dev/null || cat "$TOKEN"
elif [[ -f "$TOKEN" ]]; then
    cat "$TOKEN"
else
    echo "File not found: $TOKEN"
fi
```

### Config

```toml
[[previewers]]
pattern = '^https?://'
description = 'URL preview'
script = '/path/to/url-preview.sh'

[[previewers]]
pattern = '\.(json)$'
description = 'JSON files'
script = '/path/to/json-preview.sh'
```

Patterns are matched in order. First match wins.

## Config File Reference

```toml
# config.toml

# Previewers - match tokens by pattern
[[previewers]]
pattern = '^https?://'           # regex pattern
description = 'URL preview'      # shown in debug
script = '/path/to/script.sh'    # must be executable

# Actions - triggered by fzf keybinding
[[actions]]
binding = 'ctrl-u'               # fzf key syntax
description = 'upper'            # shown in header
script = '/path/to/script.sh'    # must be executable
```

Paths starting with `~` expand to `$HOME`.

## Overriding Built-ins

User actions override built-in defaults when bindings collide. To replace `Ctrl+S` (wrap):

```toml
[[actions]]
binding = 'ctrl-s'
description = 'my-wrap'
script = '/path/to/my-wrap.sh'
```

Built-in defaults load after user config, skipping any binding already registered.

## Debugging

Enable debug mode:
```zsh
zstyle ':zledit:' debug on
```

Logs go to `/tmp/zledit-debug.log`.

Test scripts manually:
```bash
export ZJ_BUFFER="echo hello world"
export ZJ_POSITIONS=$'0\n5\n11'
./scripts/uppercase.sh "hello" "2"
```

## Reference Examples

See `examples/` in the repository:
- `examples/actions/uppercase.sh` - case conversion
- `examples/actions/lowercase.sh` - case conversion
- `examples/previewers/url-preview.sh` - fetch URL title
- `examples/config.toml` - sample configuration

## Technical Reference

For the complete interface specification, exit codes, and protocol details, see [design.md](design.md#extensibility).
