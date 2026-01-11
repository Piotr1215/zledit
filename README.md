# zsh-jumper

Jump to any word on the current command line via fuzzy picker.

Long commands are tedious to navigate. Instead of holding arrow keys or `Ctrl+Left` repeatedly, fuzzy-search any word and jump straight to it.

```bash
$ kubectl get pods -n kube-system --output wide
                    ▲
              [Ctrl+X /]
                    │
  ┌─────────────────┴─────────────────────────────────────┐
  │ [a]kubectl [s]get [d]pods [f]-n [g]kube-system ...    │  ← overlay hints
  ├───────────────────────────────────────────────────────┤
  │      jump>                                            │
  │  [a] 1: kubectl                                       │
  │  [s] 2: get                                           │
  │> [d] 3: pods                                          │
  │  [f] 4: -n                                            │
  │  [g] 5: kube-system                                   │
  │  [h] 6: --output                                      │
  │  [j] 7: wide                                          │
  └───────────────────────────────────────────────────────┘
```

Both numbered indices AND letter hints (a, s, d, f...) are shown. The overlay on the command line shows `[a]kubectl [s]get [d]pods` so you can see which letter jumps where without looking away.

Press `;` to enter **instant mode**: then press a letter key (a, s, d...) to jump immediately to that word.

## Features

- **Multiple picker support**: fzf, fzf-tmux, sk (skim), peco, percol
- **Auto-detection**: Prefers fzf-tmux when in tmux, falls back to available picker
- **Overlay hints**: EasyMotion-style `[a] [s] [d]` labels on command line (fzf/sk)
- **Instant jump**: Press `;` then a letter to jump without fuzzy searching
- **Configurable**: Custom keybindings, picker options via zstyle
- **Fast**: ~0.2ms load time (see [Performance](#performance))
- **Wrap/Surround**: Wrap tokens in quotes, brackets, or command substitution
- **Help integration**: Show help for selected flags or commands
- **Variable extraction**: Convert tokens to shell variables
- **Path preview**: Preview file/directory contents in fzf panel

## Requirements

One of: [fzf](https://github.com/junegunn/fzf), [sk/skim](https://github.com/lotabout/skim), [peco](https://github.com/peco/peco), or [percol](https://github.com/mooz/percol)

## Installation

### zinit

```zsh
zinit light Piotr1215/zsh-jumper
```

### antigen

```zsh
antigen bundle Piotr1215/zsh-jumper
```

### oh-my-zsh

```sh
git clone https://github.com/Piotr1215/zsh-jumper ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-jumper
```

Then add `zsh-jumper` to plugins in `.zshrc`:

```zsh
plugins=(... zsh-jumper)
```

### sheldon

```toml
[plugins.zsh-jumper]
github = "Piotr1215/zsh-jumper"
```

### zplug

```zsh
zplug "Piotr1215/zsh-jumper"
```

### Manual

```zsh
source /path/to/zsh-jumper/zsh-jumper.plugin.zsh
```

## Usage

Press `Ctrl+X /` (default) on a command line with multiple words. Select a word to jump cursor there.

### FZF Actions (inside picker)

With FZF, additional actions available via key combos (shown in header):

| Key | Action |
|-----|--------|
| `Enter` | Jump to selected token |
| `Ctrl+S` | Wrap token in `"..."`, `'...'`, `$(...)`, etc. |
| `Ctrl+H` | Show `--help` for selected flag/command |
| `Ctrl+E` | Extract token to `UPPERCASE` variable (uses push-line) |
| `Ctrl+R` | Replace token (delete and position cursor for typing with tab completion) |
| `;` | Enter instant mode (then press a-z to jump) |

**Tip**: `Ctrl+R` deletes the token and leaves cursor in place - you get full zsh tab completion for the replacement text.

**Instant mode**: Press `;` while in the picker, then press a hint letter (a, s, d, f...) to jump directly to that word. The overlay on your command line shows which letter maps to which word.

Variable extraction converts `my-gpu` to `MY_GPU="my-gpu"` and `"$MY_GPU"` in the command. Special characters become underscores.

**Custom FZF keys** (if defaults conflict with your setup):
```zsh
zstyle ':zsh-jumper:' fzf-wrap-key 'ctrl-s'
zstyle ':zsh-jumper:' fzf-help-key 'ctrl-h'
zstyle ':zsh-jumper:' fzf-var-key 'ctrl-e'
zstyle ':zsh-jumper:' fzf-replace-key 'ctrl-r'
zstyle ':zsh-jumper:' fzf-instant-key ';'    # key to enter instant mode
```

**Disable overlay hints**:
```zsh
zstyle ':zsh-jumper:' overlay off
```

### Path Preview (FZF only)

File/directory tokens show a preview panel (`bat` with fallback to `head`). Extracts paths from `VAR=/path` format.

```zsh
zstyle ':zsh-jumper:' preview off              # disable
zstyle ':zsh-jumper:' preview-window 'bottom:40%'  # position
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
zstyle ':zsh-jumper:' disable-bindings yes
bindkey -M viins '^X/' zsh-jumper-widget
bindkey -M vicmd '^X/' zsh-jumper-widget
```

## Configuration

Configure via zstyle in your `.zshrc` **before** loading the plugin:

```zsh
# Force specific picker (default: auto-detect)
zstyle ':zsh-jumper:' picker fzf

# Custom picker options
zstyle ':zsh-jumper:' picker-opts '--height=50% --reverse --border'

# Cursor position after jump: start (default), middle, end
zstyle ':zsh-jumper:' cursor end

# Custom keybinding (default: ^X/)
zstyle ':zsh-jumper:' binding '^J'

# Disable default keybinding (define your own)
zstyle ':zsh-jumper:' disable-bindings yes
bindkey '^X^J' zsh-jumper-widget
```

## Picker Priority

1. Explicit `zstyle ':zsh-jumper:' picker`
2. `fzf-tmux` (when `$TMUX` is set)
3. `fzf`
4. `sk` (skim)
5. `peco`
6. `percol`

## Performance

Measured load time:

```
% zmodload zsh/zprof && source zsh-jumper.plugin.zsh && zprof
num  calls                time            self            name
-------------------------------------------------------------------------------
 1)    1           0.23     0.23  100.00%  zsh-jumper-setup-bindings
```

## Architecture

Core logic is pure zsh - external pickers (fzf/skim/peco) only handle UI.

```
tokenizer (pure)  →  actions (pure)  →  picker (external)
     ↓                    ↓
 _zj_words[]        jump/wrap/var
 _zj_positions[]    (O(1) lookup)
```

The single-pass tokenizer records word positions during parsing. Actions access `_zj_positions[$idx]` directly for O(1) lookup.

See [docs/design.md](docs/design.md) for engineering details.

## Extensibility (Advanced)

The plugin works out of the box with built-in actions. For power users who want custom behavior, extensibility is opt-in via TOML config:

```zsh
zstyle ':zsh-jumper:' config ~/.config/zsh-jumper/config.toml
```

```toml
# Custom previewer for URLs
[[previewers]]
pattern = '^https?://'
description = 'URL preview'
script = '~/.config/zsh-jumper/scripts/url-preview.sh'

# Custom action bound to Ctrl+U
[[actions]]
binding = 'ctrl-u'
description = 'upper'
script = '~/.config/zsh-jumper/scripts/uppercase.sh'
```

User-defined actions override built-in defaults when bindings collide.

See [docs/extensibility-guide.md](docs/extensibility-guide.md) for writing custom scripts, and [docs/design.md](docs/design.md) for the technical reference.

## Testing

```bash
zsh tests/test_plugin.zsh
```

Tests run in isolated subshells to ensure clean state. Covers tokenizer edge cases (unicode, special chars, long buffers), action behavior, and integration.

## Credits

The EasyMotion-style overlay hints feature was inspired by [@DehanLUO](https://github.com/DehanLUO)'s thoughtful [feature suggestion](https://github.com/Piotr1215/zsh-jumper/issues/4) and their [zsh-easymotion](https://github.com/DehanLUO/.config/blob/main/zsh/zsh-easymotion/zsh-easymotion.zsh) implementation.

## License

MIT
