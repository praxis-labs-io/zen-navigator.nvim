# Contributing

## Setup

Neovim 0.7 or later, and [ZenTerm](https://github.com/praxis-labs-io/zen-term)
1.3.0 or later with the pane-nav keybinds from the README. Point your plugin
manager at the clone instead of the published repo:

```lua
{ dir = "~/path/to/zen-navigator.nvim", event = "VeryLazy", opts = {} }
```

## Verifying

There is no automated suite: the behavior lives in the hand-off between Neovim
and ZenTerm's socket. Before you open a pull request, in ZenTerm:

- `Ctrl-h/j/k/l` walks Neovim splits, then crosses into the neighboring pane at
  each edge.
- From a shell pane, the same keys walk back into Neovim.
- Quit Neovim, and kill it with `kill -9`: either way `Ctrl-h` in that pane
  goes back to plain pane nav.
- Outside ZenTerm, every mapping is a plain `wincmd`.

## Boundaries

Both ends speak the socket contract in
[`docs/nvim-navigator-protocol.md`](https://github.com/praxis-labs-io/zen-term/blob/main/docs/nvim-navigator-protocol.md).
A change that needs a new message starts there.

## Pull requests

- One subject per pull request. Implementation, cleanup and unrelated
  refactors are separate commits.
- Say in the description which of the checks above you ran.
- If the change alters behavior a user sees, the README says so.

Report a vulnerability privately, from the Security tab, rather than in an issue.
