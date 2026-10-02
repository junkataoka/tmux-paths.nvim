# tmux-paths.nvim

Pick file paths and URLs printed in **other tmux panes** and open them in Neovim.

Built for the common setup of an AI CLI (GitHub Copilot CLI, Claude Code, etc.) in one
split and Neovim in the other: the CLI prints `/long/session-state/path/file.md` or a
URL, and instead of copy-mode → yank → `:e <paste>`, you hit one key.

## Features

- Scans scrollback of sibling panes (current window or whole session)
- Joins soft-wrapped lines, so long paths aren't cut in half
- Only lists paths that exist (resolved against each pane's cwd; `~` and relative paths OK)
- `path:42` jumps to line 42
- Newest first, deduplicated, with file preview
- URLs → `vim.ui.open()`, directories → file picker scoped to that dir

## Requirements

- Neovim >= 0.10
- tmux
- [folke/snacks.nvim](https://github.com/folke/snacks.nvim) with `picker` enabled

## Install (lazy.nvim)

```lua
{
  'junkataoka/tmux-paths.nvim',
  dependencies = { 'folke/snacks.nvim' },
  cmd = 'TmuxPaths',
  keys = {
    { '<leader>so', '<cmd>TmuxPaths<cr>', desc = 'Paths/URLs from other tmux panes' },
  },
  opts = {},
}
```

## Configuration

Defaults:

```lua
require('tmux-paths').setup {
  lines = 3000,       -- scrollback lines to scan per pane
  scope = 'window',   -- 'window' | 'session'
  show_urls = true,   -- include http(s) URLs
}
```

## Usage

`:TmuxPaths` or your mapping. Lua API:

```lua
require('tmux-paths').pick()     -- open picker
require('tmux-paths').collect()  -- raw items { text, file?, url?, pos? }
```

## License

MIT
