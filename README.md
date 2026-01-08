# zsh-jumper

Jump to any word on the current command line via fuzzy picker.

Long commands are tedious to navigate. Instead of holding arrow keys or `Ctrl+Left` repeatedly, fuzzy-search any word and jump straight to it.

```bash
$ kubectl get pods -n kube-system --output wide
                    ▲
              [Ctrl+X /]
                    │
         ┌──────────┴──────────┐
         │      jump>          │
         │  kubectl            │
         │  get                │
         │> pods               │
         │  -n                 │
         │  kube-system        │
         │  --output           │
         │  wide               │
         └─────────────────────┘
```

## Features

- **Multiple picker support**: fzf, fzf-tmux, sk (skim), peco, percol
- **Auto-detection**: Prefers fzf-tmux when in tmux, falls back to available picker
- **Configurable**: Custom keybindings, picker options via zstyle
- **Fast**: ~0.2ms load time (see [Performance](#performance))
- **Clean**: Follows Zsh Plugin Standard, supports unloading

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

**Tip**: After jumping, use `Alt+D` to delete the word, or `Ctrl+W` to delete backward - useful for quick replacements.

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

```
% zmodload zsh/zprof && source zsh-jumper.plugin.zsh && zprof
num  calls                time            self            name
-------------------------------------------------------------------------------
 1)    1           0.23     0.23  100.00%  zsh-jumper-setup-bindings
```

**0.2ms** to load. No dependencies, no background processes.

## License

MIT
