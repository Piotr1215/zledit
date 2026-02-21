# zledit

**Z**sh **L**ine **Edit**or toolkit - fuzzy navigation and in-place editing for your command line.

[![Mentioned in Awesome](https://awesome.re/mentioned-badge.svg)](https://github.com/unixorn/awesome-zsh-plugins)
[![Load](https://img.shields.io/endpoint?cacheSeconds=300&url=https%3A%2F%2Fgist.githubusercontent.com%2FPiotr1215%2Fff146261d69233bc22353774c4540492%2Fraw%2Fzledit-load.json)](#metrics)
[![Parse](https://img.shields.io/endpoint?cacheSeconds=300&url=https%3A%2F%2Fgist.githubusercontent.com%2FPiotr1215%2Fff146261d69233bc22353774c4540492%2Fraw%2Fzledit-tokenize.json)](#metrics)
[![Leak](https://img.shields.io/endpoint?cacheSeconds=300&url=https%3A%2F%2Fgist.githubusercontent.com%2FPiotr1215%2Fff146261d69233bc22353774c4540492%2Fraw%2Fzledit-memory.json)](#metrics)

Jump to any word on the current command line via fuzzy picker.

Long commands are tedious to navigate. Instead of holding arrow keys or `Ctrl+Left` repeatedly, fuzzy-search any word and jump straight to it.

```bash
$ kubectl get pods -n kube-system --output wide
                    ▲
              [Alt+/]
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
- **Fast**: ~0.2ms load time (see [Metrics](#metrics))
- **Wrap/Surround**: Wrap tokens in quotes, brackets, or command substitution
- **Move/Swap**: Swap token positions via secondary picker
- **Variable extraction**: Convert tokens to shell variables
- **Batch-apply**: Actions apply to all identical tokens at once
- **Smart preview**: Command help (`--help`/`tldr`/`man`), file contents, directory listings

## Requirements

| Dependency | Minimum Version | Check |
|------------|-----------------|-------|
| zsh | 5.3+ | `zsh --version` |
| fzf | 0.53.0+ | `fzf --version` |

Alternative pickers (instead of fzf): [sk/skim](https://github.com/lotabout/skim), [peco](https://github.com/peco/peco), [percol](https://github.com/mooz/percol)

> **Note:** System package managers often ship outdated fzf (e.g., Ubuntu/Debian ships 0.29). Install from [GitHub releases](https://github.com/junegunn/fzf/releases) or via `git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install`

## Installation

Pick your plugin manager, then verify with `Alt+/` on any command.

<details>
<summary><b>zinit</b></summary>

```zsh
# Add to .zshrc
zinit light Piotr1215/zledit
```
</details>

<details>
<summary><b>antigen</b></summary>

```zsh
# Add to .zshrc
antigen bundle Piotr1215/zledit
```
</details>

<details>
<summary><b>oh-my-zsh</b></summary>

```bash
# 1. Clone to oh-my-zsh custom plugins
git clone https://github.com/Piotr1215/zledit \
    ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zledit

# 2. Add to plugins array in ~/.zshrc
plugins=(... zledit)

# 3. Restart shell or run: source ~/.zshrc
```

Verify oh-my-zsh path: `echo ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}`
</details>

<details>
<summary><b>sheldon</b></summary>

```toml
# Add to ~/.config/sheldon/plugins.toml
[plugins.zledit]
github = "Piotr1215/zledit"
```
</details>

<details>
<summary><b>zplug</b></summary>

```zsh
# Add to .zshrc
zplug "Piotr1215/zledit"
```
</details>

<details>
<summary><b>Manual</b></summary>

```bash
# Clone anywhere
git clone https://github.com/Piotr1215/zledit ~/.zledit

# Add to .zshrc
source ~/.zledit/zledit.plugin.zsh
```
</details>

## Usage

Press `Alt+/` (default) on a command line with multiple words. Select a word to jump cursor there.

### FZF Actions (inside picker)

With FZF, additional actions available via key combos (shown in header):

| Key | Action |
|-----|--------|
| `Enter` | Jump to selected token |
| `Ctrl+S` | Wrap token in `"..."`, `'...'`, `$(...)`, etc. |
| `Ctrl+E` | Extract token to `UPPERCASE` variable (uses push-line) |
| `Ctrl+R` | Replace token (prompts with tab completion, batch-applies) |
| `Ctrl+M` | Move/swap token with another position |
| `Alt+1` | Single mode: apply next action to selected token only (skip batch) |
| `;` | Enter instant mode (then press a-z to jump) |

**Tip**: `Ctrl+R` pre-fills the token for editing with full zsh tab completion. Press Enter to apply the replacement to all identical tokens. Press `Ctrl-G` to cancel.

**Instant mode**: Press `;` while in the picker, then press a hint letter (a, s, d, f...) to jump directly to that word. The overlay on your command line shows which letter maps to which word.

Variable extraction converts `my-gpu` to `MY_GPU="my-gpu"` and `"$MY_GPU"` in the command. Special characters become underscores.

**Batch mode**: When identical tokens appear multiple times, actions apply to all occurrences automatically. The picker shows duplicate counts like `(x2)` next to repeated tokens. Press `Alt+1` to apply to only the selected occurrence.

**Complex edits**: For heavy multiline editing, `Ctrl+X Ctrl+E` (edit in `$EDITOR`) still shines. zledit is for quick navigation and token manipulation.

### Preview Panel (FZF only)

The preview panel shows contextual information:

- **Commands**: `--help` output (with `bat` syntax highlighting), fallback to `tldr`, then `man`
- **Files**: Content preview via `bat` (or `head`)
- **Directories**: `ls -la` listing

Scroll preview with `Ctrl+D` / `Ctrl+U`. See [Configuration](#configuration) for options.

### Multiline Commands

Multiline commands with backslash are also supported, for example:

```bash
$ docker run -d \
    --name my-container \
    --network host \
    nginx:latest
```

Words are split on whitespace (spaces, tabs, newlines). Line continuation backslashes are filtered out, so you see only actual command tokens in the picker.

## Configuration

All options use zstyle. Set in `.zshrc` **before** loading the plugin.

```zsh
# Picker: fzf (default), fzf-tmux, sk, peco, percol
zstyle ':zledit:' picker fzf
zstyle ':zledit:' picker-opts '--height=50% --reverse --border'

# Keybinding (default: Alt+/)
zstyle ':zledit:' binding '^X^J'        # Ctrl+X Ctrl+J
zstyle ':zledit:' disable-bindings yes  # manual binding only

# Cursor position after jump: start (default), middle, end
zstyle ':zledit:' cursor end

# Overlay hints on command line
zstyle ':zledit:' overlay off           # disable [a] [s] [d] hints

# Preview panel
zstyle ':zledit:' preview off           # disable
zstyle ':zledit:' preview-window 'bottom:40%'

# FZF action keys (if defaults conflict with your setup)
zstyle ':zledit:' fzf-wrap-key 'ctrl-s'
zstyle ':zledit:' fzf-var-key 'ctrl-e'
zstyle ':zledit:' fzf-replace-key 'ctrl-r'
zstyle ':zledit:' fzf-move-key 'ctrl-m'
zstyle ':zledit:' fzf-instant-key ';'
zstyle ':zledit:' fzf-single-key 'alt-1'  # single-mode key (skip batch)

# Batch-apply: actions apply to all identical tokens (default: on)
zstyle ':zledit:' batch-apply off          # disable batch mode

# Vi mode: bind to both insert and command modes
zstyle ':zledit:' disable-bindings yes
bindkey -M viins '^[/' zledit-widget
bindkey -M vicmd '^[/' zledit-widget
```

**Inspect config:** `zledit-list` shows registered paths, actions, previewers.

**Picker priority:** explicit picker setting → fzf-tmux (in tmux) → fzf → sk → peco → percol

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

See [docs/extensibility-guide.md](docs/extensibility-guide.md) for writing custom scripts.

## Testing

```bash
zsh tests/test_plugin.zsh
```

## Credits

The EasyMotion-style overlay hints feature was inspired by [@DehanLUO](https://github.com/DehanLUO)'s thoughtful [feature suggestion](https://github.com/Piotr1215/zledit/issues/4) and their [zsh-easymotion](https://github.com/DehanLUO/.config/blob/main/zsh/zsh-easymotion/zsh-easymotion.zsh) implementation.

## License

MIT
