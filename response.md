Thanks so much for taking the time to write this detailed issue and test my plugin! Really appreciate the thoughtful feedback.

Our goals diverge slightly - with [this PR](https://github.com/Piotr1215/zsh-jumper/pull/3) I'm doubling down on fzf integration with various actions:
- **Wrap** (`Ctrl+S`): surround token in quotes, `$(...)`, `${...}`, etc
- **Variable extraction** (`Ctrl+E`): convert `my-value` → `MY_VALUE="my-value"` with `"$MY_VALUE"` in command
- **Replace** (`Ctrl+R`): delete token and position cursor for tab-completion replacement
- **Help** (`Ctrl+H`): show `--help` for flags/commands

Your [zsh-easymotion](https://github.com/DehanLUO/.config/blob/main/zsh/zsh-easymotion/zsh-easymotion.zsh) implementation is great! I adopted the `region_highlight` approach for colored hint labels. I've combined it with the fzf picker as an opt-in instant mode - press `;` in fzf to toggle it, then letter keys jump directly. The instant key is configurable via `zstyle ':zsh-jumper:' fzf-instant-key`.

Thanks for the error report about fzf-tmux - I primarily use fzf-tmux in tmux but hadn't tested all code paths. Fixed now. Tested on Alacritty with tmux and Ghostty without tmux.

Architecture-wise, I went with ports & adapters pattern ([design doc](https://github.com/Piotr1215/zsh-jumper/blob/main/docs/design.md)) - clean split between:
- Pure zsh tokenizer (single-pass, records positions during parsing)
- Action handlers (jump/wrap/var/replace - O(1) position lookup)
- Picker adapters (fzf/sk/peco/percol)

This keeps core logic testable and picker-agnostic. See the [README](https://github.com/Piotr1215/zsh-jumper#readme) for full usage docs.

Would love more feedback and ideas from you! The overlay + instant mode combo feels pretty good now.
