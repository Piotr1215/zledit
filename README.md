# zledit

**Z**sh **L**ine **Edit**or toolkit - fuzzy navigation and in-place editing for your command line.

[![Load](https://img.shields.io/endpoint?cacheSeconds=300&url=https%3A%2F%2Fgist.githubusercontent.com%2FPiotr1215%2Fff146261d69233bc22353774c4540492%2Fraw%2Fzledit-load.json)](#metrics)
[![Parse](https://img.shields.io/endpoint?cacheSeconds=300&url=https%3A%2F%2Fgist.githubusercontent.com%2FPiotr1215%2Fff146261d69233bc22353774c4540492%2Fraw%2Fzledit-tokenize.json)](#metrics)
[![Leak](https://img.shields.io/endpoint?cacheSeconds=300&url=https%3A%2F%2Fgist.githubusercontent.com%2FPiotr1215%2Fff146261d69233bc22353774c4540492%2Fraw%2Fzledit-memory.json)](#metrics)

Jump to any word on the current command line via fuzzy picker.

Long commands are tedious to navigate. Instead of holding arrow keys or `Ctrl+Left` repeatedly, fuzzy-search any word and jump straight to it.

```bash
$ kubectl get pods -n kube-system --output wide
                    ▲
              [Ctrl+X /]
                    │
→ [a]kubectl [s]get [d]pods [f]-n [g]kube-system [h]--output [j]wide   ← overlay
┌─────────────────────────────────────┬────────────────────────────────────────┐
│ jump>                               │ kubectl controls the Kubernetes...     │
│ ^S:wrap | ^E:var | ^R:replace | ^M:m|                                        │
│─────────────────────────────────────│                                        │
│> 1: kubectl                         │ Basic Commands (Beginner):             │
│  2: get                             │   create    Create a resource          │
│  3: pods                            │   expose    Expose a resource          │
│  4: -n                              │   run       Run a particular image     │
│  5: kube-system                     │   set       Set specific features      │
│  6: --output                        │                                        │
│  7: wide                            │ Basic Commands (Intermediate):         │
└─────────────────────────────────────┴────────────────────────────────────────┘
```

The overlay shows letter hints (`[a]kubectl [s]get [d]pods`) for instant jump. The picker has numbered items for fuzzy search, with `--help` preview on the right.

Press `;` to enter **instant mode**: press a letter key (a, s, d...) to jump directly to that word.

## Features

- **Multiple picker support**: fzf, fzf-tmux, sk (skim), peco, percol
- **Auto-detection**: Prefers fzf-tmux when in tmux, falls back to available picker
- **Overlay hints**: EasyMotion-style `[a] [s] [d]` labels on command line for instant jump
- **Instant jump**: Press `;` then a letter to jump without fuzzy searching
- **Configurable**: Custom keybindings, picker options via zstyle
- **Fast**: ~0.2ms load time (see [Performance](#performance))
- **Wrap/Surround**: Wrap tokens in quotes, brackets, or command substitution
- **Move/Swap**: Swap token positions via secondary picker
- **Variable extraction**: Convert tokens to shell variables
- **Smart preview**: Command help (`--help`/`tldr`/`man`), file contents, directory listings

## Requirements

One of: [fzf](https://github.com/junegunn/fzf), [sk/skim](https://github.com/lotabout/skim), [peco](https://github.com/peco/peco), or [percol](https://github.com/mooz/percol)

## Installation

### zinit

```zsh
zinit light Piotr1215/zledit
```

### antigen

```zsh
antigen bundle Piotr1215/zledit
```

### oh-my-zsh

```sh
git clone https://github.com/Piotr1215/zledit ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zledit
```

Then add `zledit` to plugins in `.zshrc`:

```zsh
plugins=(... zledit)
```

### sheldon

```toml
[plugins.zledit]
github = "Piotr1215/zledit"
```

### zplug

```zsh
zplug "Piotr1215/zledit"
```

### Manual

```zsh
source /path/to/zledit/zledit.plugin.zsh
```

## Usage

Press `Ctrl+X /` (default) on a command line with multiple words. Select a word to jump cursor there.

### FZF Actions (inside picker)

With FZF, additional actions available via key combos (shown in header):

| Key | Action |
|-----|--------|
| `Enter` | Jump to selected token |
| `Ctrl+S` | Wrap token in `"..."`, `'...'`, `$(...)`, etc. |
| `Ctrl+E` | Extract token to `UPPERCASE` variable (uses push-line) |
| `Ctrl+R` | Replace token (delete and position cursor for typing) |
| `Ctrl+M` | Move/swap token with another position |
| `;` | Enter instant mode (then press a-z to jump) |

**Tip**: `Ctrl+R` deletes the token and leaves cursor in place - you get full zsh tab completion for the replacement text.

**Instant mode**: Press `;` while in the picker, then press a hint letter (a, s, d, f...) to jump directly to that word. The overlay on your command line shows which letter maps to which word.

Variable extraction converts `my-gpu` to `MY_GPU="my-gpu"` and `"$MY_GPU"` in the command. Special characters become underscores.

**Complex edits**: For heavy multiline editing, `Ctrl+X Ctrl+E` (edit in `$EDITOR`) still shines. zledit is for quick navigation and token manipulation.

**Custom FZF keys** (if defaults conflict with your setup):
```zsh
zstyle ':zledit:' fzf-wrap-key 'ctrl-s'
zstyle ':zledit:' fzf-var-key 'ctrl-e'
zstyle ':zledit:' fzf-replace-key 'ctrl-r'
zstyle ':zledit:' fzf-move-key 'ctrl-m'
zstyle ':zledit:' fzf-instant-key ';'    # key to enter instant mode
```

**Disable overlay hints**:
```zsh
zstyle ':zledit:' overlay off
```

### Preview Panel (FZF only)

The preview panel shows contextual information:

- **Commands**: `--help` output (with `bat` syntax highlighting), fallback to `tldr`, then `man`
- **Files**: Content preview via `bat` (or `head`)
- **Directories**: `ls -la` listing

Scroll preview with `Ctrl+D` / `Ctrl+U`.

```zsh
zstyle ':zledit:' preview off              # disable
zstyle ':zledit:' preview-window 'bottom:40%'  # position
```

### Multiline Commands

Multiline commands with backslash are also supported, for example:

```bash
$ docker run -d \
    --name my-container \
    --network host \
    nginx:latest
```

Words are split on whitespace (spaces, tabs, newlines). Line continuation backslashes are filtered out, so you see only actual command tokens in the picker.

### Vi mode

For vi mode users, bind to both insert and command modes:

```zsh
zstyle ':zledit:' disable-bindings yes
bindkey -M viins '^X/' zledit-widget
bindkey -M vicmd '^X/' zledit-widget
```

## Configuration

Configure via zstyle in your `.zshrc` **before** loading the plugin:

```zsh
# Force specific picker (default: auto-detect)
zstyle ':zledit:' picker fzf

# Custom picker options
zstyle ':zledit:' picker-opts '--height=50% --reverse --border'

# Cursor position after jump: start (default), middle, end
zstyle ':zledit:' cursor end

# Custom keybinding (default: ^X/)
zstyle ':zledit:' binding '^J'

# Disable default keybinding (define your own)
zstyle ':zledit:' disable-bindings yes
bindkey '^X^J' zledit-widget
```

**List registered config:**

```bash
zledit-list  # shows config paths, actions, previewers
```

## Picker Priority

1. Explicit `zstyle ':zledit:' picker`
2. `fzf-tmux` (when `$TMUX` is set)
3. `fzf`
4. `sk` (skim)
5. `peco`
6. `percol`

## Architecture

Core logic is pure zsh - external pickers (fzf/skim/peco) only handle UI.

```
tokenizer (pure)  →  actions (pure)  →  picker (external)
     ↓                    ↓
 _ze_words[]        jump/wrap/var
 _ze_positions[]    (O(1) lookup)
```

The single-pass tokenizer records word positions during parsing. Actions access `_ze_positions[$idx]` directly for O(1) lookup.

See [docs/design.md](docs/design.md) for engineering details.

## Metrics

CI measures and enforces thresholds on every commit:

| Metric | What it measures | Threshold |
|--------|------------------|-----------|
| **Load** | Time to source the plugin | < 200ms |
| **Parse** | Tokenize a 10-word command 100× | < 150ms |
| **Leak** | Memory delta after 10 load/unload cycles | < 400KB |

**Leak** checks for memory that isn't freed on `zledit-unload`. A 5-cycle warmup runs first (zsh internals allocate once), then 10 more cycles. Growth beyond 400KB fails CI.

## Extensibility (Advanced)

The plugin works out of the box with built-in actions. For power users who want custom behavior, extensibility is opt-in via TOML config:

```zsh
zstyle ':zledit:' config ~/.config/zledit/config.toml
```

```toml
# Custom previewer for URLs
[[previewers]]
pattern = '^https?://'
description = 'URL preview'
script = '~/.config/zledit/scripts/url-preview.sh'

# Custom action bound to Ctrl+U
[[actions]]
binding = 'ctrl-u'
description = 'upper'
script = '~/.config/zledit/scripts/uppercase.sh'
```

User-defined actions override built-in defaults when bindings collide.

**Introspection**: Run `zledit-list` to see all registered actions and previewers.

See [docs/extensibility-guide.md](docs/extensibility-guide.md) for writing custom scripts, and [docs/design.md](docs/design.md) for the technical reference.

## Testing

```bash
zsh tests/test_plugin.zsh
```

Tests run in isolated subshells to ensure clean state. Covers tokenizer edge cases (unicode, special chars, long buffers), action behavior, and integration.

## Credits

The EasyMotion-style overlay hints feature was inspired by [@DehanLUO](https://github.com/DehanLUO)'s thoughtful [feature suggestion](https://github.com/Piotr1215/zledit/issues/4) and their [zsh-easymotion](https://github.com/DehanLUO/.config/blob/main/zsh/zsh-easymotion/zsh-easymotion.zsh) implementation.

## License

MIT
