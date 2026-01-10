# Design Principles

Engineering notes on zsh-jumper's architecture.

## Core Philosophy

**Pure shell logic, external tools only for UI.**

The tokenizer, position tracking, and buffer manipulation are pure zsh - no external dependencies. FZF/skim/peco are only used for the fuzzy picker UI.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   zsh-jumper-widget                 │
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
2. **Actions** - Pure zsh. Jump, wrap, help, var, replace
3. **Picker Adapters** - Ports & adapters pattern. Same interface, different backends
4. **Widget** - Orchestration. Overlay hints, instant mode, glues layers together

## Configuration

Config read once at plugin load, stored in `ZshJumper` associative array:

```zsh
_zsh_jumper_load_config() {
    zstyle -s ':zsh-jumper:' overlay val; ZshJumper[overlay]="${val:-on}"
    zstyle -s ':zsh-jumper:' fzf-wrap-key val; ZshJumper[wrap-key]="${val:-ctrl-s}"
    # ... etc
}
```

**Why load once?** Reading zstyle during widget execution caused output leakage in some terminal configurations.

## Picker Adapters (Ports & Adapters)

Each adapter implements the same interface:

```zsh
# Input: stdin (items), _zj_invoke_* variables (config)
# Output: _zj_result_key (action), _zj_result_selection (item)
# Return: 0 success, 1 cancelled

_zsh_jumper_adapter_fzf()
_zsh_jumper_adapter_fzf-tmux()
_zsh_jumper_adapter_sk()
_zsh_jumper_adapter_peco()
_zsh_jumper_adapter_percol()
```

Adding a new picker = implement one function.

## Overlay & Instant Mode

EasyMotion-style hints via `region_highlight`:

```zsh
_zsh_jumper_highlight_hints() {
    region_highlight=()
    # Find [x] patterns, add "fg=yellow,bold" highlighting
}
```

Instant mode uses fzf's `rebind` action - letter keys start unbound, `;` rebinds them for direct jump.

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
_zsh_jumper_tokenize() {
    _zj_words=()
    _zj_positions=()

    local i=0 word_start=-1 in_word=0
    while (( i < ${#BUFFER} )); do
        if [[ "${BUFFER:$i:1}" == [[:space:]] ]]; then
            if (( in_word )); then
                _zj_words+=("${BUFFER:$word_start:$((i - word_start))}")
                _zj_positions+=($word_start)
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
- O(1) position lookup: `_zj_positions[$idx]`
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

Actions receive only the selection string. They access `_zj_words` and `_zj_positions` directly:

```zsh
_zsh_jumper_do_jump() {
    local sel="$1"
    local idx="${sel%%:*}"

    # Bounds check
    (( idx < 1 || idx > ${#_zj_words[@]} )) && return 1

    # Direct lookup - O(1)
    local pos="${_zj_positions[$idx]}"
    CURSOR=$pos
}
```

**Why not pass arrays as arguments?**

- Simpler function signatures
- Avoids argument parsing bugs (the `--` separator issue)
- Arrays are already scoped to the widget invocation

## Testing Strategy

Tests covering:

1. **Unit tests** - Tokenizer in isolation
2. **Edge cases** - Unicode, special chars, long strings
3. **Integration** - Full widget behavior
4. **Regression** - Specific bugs (e.g., `--` in commands)

Tests run in isolated zsh subshells:
```zsh
result=$(zsh -c '
    source ./zsh-jumper.plugin.zsh
    BUFFER="test input"
    _zsh_jumper_tokenize
    echo "${_zj_positions[1]}"
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

Invariants the widget relies on:
- BUFFER is stable during widget execution
- `_zj_words` and `_zj_positions` are aligned (same length)
- Positions are valid indices into current BUFFER

## Future Considerations

**v2 scope (separate tokenizer, not extension):**
- Quote-aware tokenization - state machine, escape handling, nested quotes
- Would need feature flag and aggressive tests

**Smaller additions:**
- Syntax highlighting - colors for flags, paths, vars
- History integration - jump to words from previous commands
