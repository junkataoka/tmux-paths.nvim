if vim.g.loaded_tmux_paths then
  return
end
vim.g.loaded_tmux_paths = true

vim.api.nvim_create_user_command('TmuxPaths', function()
  require('tmux-paths').pick()
end, { desc = 'Pick paths/URLs from other tmux panes' })
