# Design Principles

Engineering notes on zledit's architecture.

## Core Philosophy

**Pure shell logic, external tools only for UI.**

The tokenizer, position tracking, and buffer manipulation are pure zsh - no external dependencies. FZF/skim/peco are only used for the fuzzy picker UI.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   zledit-widget                 │
│         (orchestration, overlay, instant mode)      │
└─────────────────────┬───────────────────────────────┘
                      │
        ┌─────────────┼─────────────┐
        ▼             ▼             ▼
┌───────────┐  ┌───────────┐  ┌─────────────────┐
│ tokenizer │  │  actions  │  │ picker adapters │
│  (pure)   │  │  (pure)   │  │ (ports pattern) │
└───────────┘  └───────────┘  └─────────────────┘
                                      │
                    ┌─────────┬───────┼───────┬─────────┐
                    ▼         ▼       ▼       ▼         ▼
                  fzf    fzf-tmux    sk     peco    percol
```

**Layers:**

1. **Tokenizer** - Pure zsh. Parses BUFFER, produces parallel arrays
2. **Actions** - Pure zsh. Jump, wrap, help, var, replace, batch-apply
3. **Picker Adapters** - Ports & adapters pattern. Same interface, different backends
4. **Widget** - Orchestration. Overlay hints, instant mode, glues layers together

## Configuration

Config read once at plugin load, stored in `Zledit` associative array:

```zsh
_zledit_load_config() {
    zstyle -s ':zledit:' overlay val; Zledit[overlay]="${val:-on}"
    zstyle -s ':zledit:' fzf-wrap-key val; Zledit[wrap-key]="${val:-ctrl-s}"
    # ... etc
}
```

**Why load once?** Reading zstyle during widget execution caused output leakage in some terminal configurations.

## Picker Adapters (Ports & Adapters)

Each adapter implements the same interface:

```zsh
# Input: stdin (items), _ze_invoke_* variables (config)
# Output: _ze_result_key (action), _ze_result_selection (item)
# Return: 0 success, 1 cancelled

_zledit_adapter_fzf()
_zledit_adapter_fzf-tmux()
_zledit_adapter_sk()
_zledit_adapter_peco()
_zledit_adapter_percol()
```

Adding a new picker = implement one function.

## Overlay & Instant Mode

EasyMotion-style hints via `region_highlight`:

```zsh
_zledit_highlight_hints() {
    region_highlight=()
    # Find [x] patterns, add "fg=yellow,bold" highlighting
}
```

Instant mode uses fzf's `rebind` action - letter keys start unbound, `;` rebinds them for direct jump.

**Overlay cleanup:** After picker exits, we clear the overlay from terminal scrollback:
```zsh
print -n '\e[1A\e[2K'  # CSI cursor up + CSI erase line
```
Standard VT100 codes - works in all modern terminals.

## Tokenizer Design

### Scope (intentional constraints)

This tokenizer is **word-based, not shell-grammar-aware**.

- Splits on whitespace only
- Quotes are literal characters, not delimiters
- `echo "hello world"` produces 3 tokens: `echo`, `"hello`, `world"`
- Escapes, subshells, variable expansion - all out of scope

This is intentional. Shell grammar parsing is a different beast entirely - state machines, nested quotes, escape handling. That's a v2 tokenizer, not an extension of this one.

### Problem

The naive approach `words=(${=BUFFER})` loses position information. To place the cursor correctly, we need to know where each word starts in the original buffer.

### Failed Approaches

**Search-based position finding:**
```zsh
# Find position by searching through buffer
pos="${remaining[(i)$target]}"
```

Problems:
- Pattern matching fails on special chars (`--flag`, `$VAR`)
- O(n) per lookup, O(n²) total
- Edge cases with duplicate words

### Solution: Single-Pass Tokenizer

Parse once, record positions during tokenization:

```zsh
_zledit_tokenize() {
    _ze_words=()
    _ze_positions=()

    local i=0 word_start=-1 in_word=0
    while (( i < ${#BUFFER} )); do
        if [[ "${BUFFER:$i:1}" == [[:space:]] ]]; then
            if (( in_word )); then
                _ze_words+=("${BUFFER:$word_start:$((i - word_start))}")
                _ze_positions+=($word_start)
                in_word=0
            fi
        elif (( ! in_word )); then
            word_start=$i
            in_word=1
        fi
        (( i++ ))
    done
    # Handle trailing word...
}
```

**Benefits:**
- O(n) single pass
- O(1) position lookup: `_ze_positions[$idx]`
- No pattern matching - handles all characters
- Parallel arrays keep data aligned

### Edge Cases Handled

| Input | Behavior |
|-------|----------|
| Multiple spaces | Skipped, positions correct |
| Leading/trailing space | Trimmed, first word positioned correctly |
| Tabs, newlines | Treated as whitespace |
| `--flag` | Literal match, no pattern issues |
| `VAR=value` | Single token, equals preserved |
| `$VAR` | Literal, no expansion |
| 500+ words | O(n), tested |

## Action Design

Actions receive only the selection string. They access `_ze_words` and `_ze_positions` directly:

```zsh
_zledit_do_jump() {
    local sel="$1"
    local idx="${sel%%:*}"

    # Bounds check
    (( idx < 1 || idx > ${#_ze_words[@]} )) && return 1

    # Direct lookup - O(1)
    local pos="${_ze_positions[$idx]}"
    CURSOR=$pos
}
```

**Why not pass arrays as arguments?**

- Simpler function signatures
- Avoids argument parsing bugs (the `--` separator issue)
- Arrays are already scoped to the widget invocation

## Testing Strategy

Tests covering:

1. **Unit tests** - Tokenizer, batch-replace, binding conversion in isolation
2. **Edge cases** - Unicode, special chars, long strings, trailing newlines
3. **Integration** - Full widget behavior, action scripts
4. **Regression** - Specific bugs (e.g., `--` in commands, `$()` newline stripping)
5. **Performance** - Load time (<200ms), tokenize 100x (<150ms), memory leak detection (<400KB)

Tests run in isolated zsh subshells:
```zsh
result=$(zsh -c '
    source ./zledit.plugin.zsh
    BUFFER="test input"
    _zledit_tokenize
    echo "${_ze_positions[1]}"
')
```

**Why subshells?**
- Clean state per test
- No cross-test pollution
- Matches real plugin loading

## Lessons Learned

1. **Avoid `||` for defaults in zsh widgets** - Can trigger trace output
2. **Pattern matching is fragile** - Use character iteration for reliability
3. **Test the tokenizer separately** - Most bugs are position-related
4. **Parallel arrays > objects** - Zsh doesn't have objects, parallel arrays work well

## Failure Modes

Where we deliberately do nothing:

| Scenario | Behavior | Rationale |
|----------|----------|-----------|
| BUFFER changes mid-flow | Undefined | Widget is synchronous, shouldn't happen |
| Empty BUFFER | Early return | Nothing to jump to |
| Index out of bounds | Return 1, no-op | Guard in every action |
| Picker cancelled | Redisplay, no-op | User intent is clear |
| Action rearranges buffer | Batch skipped | Prefix/tail guards detect structural changes |
| `$()` strips trailing newlines | Normalized before comparison | Known shell behavior |

Invariants the widget relies on:
- BUFFER is stable during widget execution
- `_ze_words` and `_ze_positions` are aligned (same length)
- Positions are valid indices into current BUFFER

## Extensibility

Two extension points: **Previewers** (custom preview for token patterns) and **Actions** (custom scripts for token manipulation). All built-in actions (wrap, help, var, replace) use the same external script interface as user-defined actions.

### Configuration

Single config file for both previewers and actions:

```zsh
zstyle ':zledit:' config ~/.config/zledit/config.toml
```

### TOML Parser

Minimal subset parser (no external dependencies):
- `[[array]]` headers for tables of tables
- `key = 'value'` and `key = "value"`
- `#` comments

```zsh
_zledit_parse_toml() {
    # Reads file line-by-line
    # Extracts [[previewers]] and [[actions]] blocks
    # Returns: count:pattern1:desc1:script1:pattern2:desc2:script2:...
}
```

### Previewers

Match token against regex patterns, run first matching script.

```toml
[[previewers]]
pattern = '^https?://'
description = 'URL preview'
script = '~/.config/zledit/scripts/url-preview.sh'

[[previewers]]
pattern = '\.(json|yaml|yml)$'
description = 'Structured data'
script = '/usr/bin/cat'
```

**Script interface:**
- `$1` = token to preview
- Output to stdout for fzf preview window

### Actions

Custom scripts triggered by FZF key bindings. User-defined actions override built-in defaults.

```toml
[[actions]]
binding = 'ctrl-u'
description = 'upper'
script = '~/.config/zledit/scripts/uppercase.sh'
```

**Script Interface:**

Arguments:
- `$1` = selected token
- `$2` = token index (1-based)

Environment variables:
- `ZJ_BUFFER` = current command line
- `ZJ_POSITIONS` = newline-delimited start positions
- `ZJ_WORDS` = newline-delimited tokens
- `ZJ_CURSOR` = current cursor position
- `ZJ_PICKER` = active picker (fzf, fzf-tmux, sk, peco, percol)

**Output Protocol (fd 3):**

Actions output the new buffer to stdout and metadata to file descriptor 3:

```bash
#!/usr/bin/env bash
TOKEN="$1"
upper=$(echo "$TOKEN" | tr '[:lower:]' '[:upper:]')

# New buffer to stdout
echo "${ZJ_BUFFER//$TOKEN/$upper}"

# Metadata to fd 3 (skip if not open)
if [[ -e /dev/fd/3 ]]; then
    echo "mode:replace" >&3
    echo "cursor:10" >&3
fi
```

| Key | Value | Description |
|-----|-------|-------------|
| `mode` | `replace` | Apply stdout as new buffer (default) |
| | `display` | Print stdout to terminal, don't change buffer |
| | `pushline` | Save buffer, show `pushline:` command for user to execute |
| | `pushline-exec` | Save buffer, execute `pushline:` command immediately |
| | `error` | Show `message:` as error, abort |
| | `deferred` | Don't modify buffer; widget handles via `zle recursive-edit` |
| `cursor` | `N` | Set cursor to position N |
| `pushline` | `cmd` | Command to show/execute (for pushline modes) |
| `message` | `text` | Error message (for error mode) |

**Legacy Exit Codes:**

For backwards compatibility when fd 3 is not used:
- 0 = apply stdout as new buffer (supports CURSOR:N override)
- 1 = error, show stderr message
- 2 = display mode (print stdout, no buffer change)
- 3 = push-line (format: `buffer\n---ZJ_PUSHLINE---\ncommand`, user presses Enter)
- 4 = push-line + auto-execute (same format, executes immediately)

**History avoidance:** For pushline modes, prepend a space to the pushed command:
```bash
echo " ${EDITOR:-vim} \"$file\""  # leading space = skipped by HIST_IGNORE_SPACE
```
Prevents helper commands from polluting shell history.

**Example action script:**

```bash
#!/usr/bin/env bash
# uppercase.sh - convert token to UPPERCASE
set -eo pipefail

TOKEN="$1"
INDEX="$2"

[[ -z "$TOKEN" || -z "$INDEX" || -z "$ZJ_BUFFER" || -z "$ZJ_POSITIONS" ]] && exit 1

# Parse positions array
IFS=$'\n' read -r -d '' -a positions <<< "$ZJ_POSITIONS" || true
pos="${positions[$((INDEX - 1))]}"
[[ -z "$pos" ]] && exit 1

# Transform token
upper=$(echo "$TOKEN" | tr '[:lower:]' '[:upper:]')

# Replace in buffer
end_pos=$((pos + ${#TOKEN}))
new_buffer="${ZJ_BUFFER:0:$pos}${upper}${ZJ_BUFFER:$end_pos}"

echo "$new_buffer"

# Metadata via fd 3
if [[ -e /dev/fd/3 ]]; then
    echo "mode:replace" >&3
fi
```

See `examples/` for more sample scripts.

## Batch-Apply

When identical tokens appear multiple times (e.g., `sre-haiku` in a multiline kubectl command), actions apply to all occurrences by default.

### Algorithm

After an action modifies BUFFER at the selected token's position:

1. Strip trailing newlines from saved buffer (command substitution in action scripts eats them)
2. Verify prefix (before token) unchanged - catches move/swap actions
3. Verify tail (after token) unchanged - catches rearrangements
4. Extract replacement text by diffing old and new buffer at the known position
5. Find all other positions with identical token text
6. Sort positions descending, apply replacements right-to-left

Right-to-left avoids cascading offset adjustments. Positions after the first replacement shift by `delta = len(replacement) - len(original)`, positions before don't shift.

### Safety Guards

| Guard | What it catches |
|-------|----------------|
| Prefix mismatch | Action modified buffer before the token (move/swap) |
| Tail mismatch | Action rearranged the buffer structure |
| Trailing newline normalization | `$()` strips trailing newlines from action script output |
| `_ze_single_mode` | User explicitly chose single-token mode via Alt+1 |

### Single Mode

Alt+1 exits fzf, shows a second picker listing available actions. The selected action runs with `_ze_single_mode=1`, which `_zledit_batch_replace` checks and skips.

## Future Considerations

**v2 scope (separate tokenizer, not extension):**
- Quote-aware tokenization - state machine, escape handling, nested quotes
- Would need feature flag and aggressive tests

**Smaller additions:**
- Syntax highlighting - colors for flags, paths, vars
- History integration - jump to words from previous commands
