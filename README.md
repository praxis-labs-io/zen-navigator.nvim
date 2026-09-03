# zen-navigator.nvim

`Ctrl-h/j/k/l` navigation that walks across **Neovim splits** and
**[ZenTerm](https://github.com/praxis-labs-io/zen-term) panes** as one motion.
The `vim-tmux-navigator` idea, without tmux, and backend-agnostic: it works on
ZenTerm's default Ghostty backend with no process-probing.

Press `Ctrl-h` at the left edge of your Neovim splits and focus crosses into the
ZenTerm pane on the left. From a shell pane, `Ctrl-h` walks back into Neovim and
continues through its splits.

## How it works

Both detection and hand-off ride ZenTerm's nav socket (`$ZEN_SOCK`), which
ZenTerm injects into every pane along with a per-pane token (`$ZEN_PANE`):

- On `VimEnter`/`VimResume` the plugin tells ZenTerm this pane is running Neovim
  (and clears it on `VimLeave`/`VimSuspend`), so ZenTerm's key guard lets
  `Ctrl-hjkl` reach Neovim instead of moving pane focus.
- That claim is held on a single open connection. ZenTerm clears the pane's flag
  when the connection closes, so a crash or a `kill -9` releases `Ctrl-hjkl` back
  to pane nav the moment Neovim dies, with no autocmd needed.
- When Neovim is at its edge split and can't move further, it asks ZenTerm to
  move pane focus in that direction.

Outside ZenTerm (`$ZEN_SOCK` and `$ZEN_PANE` unset) every mapping falls back to a
plain `wincmd`, so the plugin is inert anywhere else and your config stays
portable.

## Requirements

- [ZenTerm](https://github.com/praxis-labs-io/zen-term) 0.1.0 or later. The
  crash-safe flag below needs a ZenTerm newer than 1.2.0.
- Neovim 0.7+ (uses `vim.keymap`, `vim.api.nvim_create_autocmd`).

## Install

Both sides opt in, and both steps are required. This is not a default rebind:
ZenTerm's own `⌘-hjkl` pane nav is untouched, and the plugin only diverts a chord
ZenTerm already treats as pane nav.

### 1. The plugin

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "zen-term/zen-navigator.nvim",
  event = "VeryLazy",
  opts = {},
}
```

Or with [packer](https://github.com/wbthomason/packer.nvim):

```lua
use({ "zen-term/zen-navigator.nvim", config = function() require("zen-navigator").setup() end })
```

### 2. ZenTerm keybinds

Give ZenTerm the chord to hand off. Add these to `~/.config/zen-term/config`, or
set them in ZenTerm's Settings (`⌘,`) under Keybinds:

```
keybind = nav_left=ctrl+h
keybind = nav_down=ctrl+j
keybind = nav_up=ctrl+k
keybind = nav_right=ctrl+l
```

The `keybind = <action>=<chord>` shape matters, action first. ZenTerm ignores
unknown config keys without complaining, so a line written the other way around
does nothing and reports nothing.

## Configuration

```lua
require("zen-navigator").setup({
  -- Set false to bind Ctrl-hjkl yourself, calling require("zen-navigator").navigate("h").
  default_mappings = true,
})
```

## Caveats

- **Ctrl-hjkl is claimed when you opt in.** Non-Neovim TUIs (htop, less) in a
  shell pane lose those keys to pane nav. That is the same tradeoff tmux and
  kitty make. ZenTerm's default `⌘-hjkl` never has this problem.
- **The crash-safe flag needs a ZenTerm newer than 1.2.0.** On 1.2.0 and
  earlier the flag only clears on `VimLeave`/`VimSuspend`, so a hard crash
  leaves it set and `Ctrl-h` reaches the recovered shell and does nothing until
  it is reset. ZenTerm's `⌘-hjkl` fallback always works either way.

## Protocol

The socket contract is documented at
[`docs/nvim-navigator-protocol.md`](https://github.com/praxis-labs-io/zen-term/blob/main/docs/nvim-navigator-protocol.md)
in the ZenTerm releases repo. Both ends are written against it, and nothing in it
depends on the terminal backend.
