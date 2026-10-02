---@class tmux_paths.Config
---@field lines integer Scrollback lines to scan per pane
---@field scope 'window'|'session' Which panes to scan (current pane is always excluded)
---@field show_urls boolean Include http(s) URLs
local defaults = {
  lines = 3000,
  scope = 'window',
  show_urls = true,
}

local M = {}

---@type tmux_paths.Config
M.config = vim.deepcopy(defaults)

---@param opts? tmux_paths.Config
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {})
end

local function resolve(raw, cwd)
  local path = raw:gsub('^~', vim.env.HOME)
  if not path:match '^/' then
    path = cwd .. '/' .. path
  end
  return vim.fs.normalize(path)
end

local function panes()
  local args = { 'tmux', 'list-panes', '-F', '#{pane_id}\t#{pane_current_path}' }
  if M.config.scope == 'session' then
    table.insert(args, 3, '-s')
  end
  local out = vim.fn.systemlist(args)
  if vim.v.shell_error ~= 0 then
    return {}
  end
  local result = {}
  for _, l in ipairs(out) do
    local id, cwd = l:match '^(%S+)\t(.*)$'
    if id and id ~= vim.env.TMUX_PANE then
      table.insert(result, { id = id, cwd = cwd })
    end
  end
  return result
end

--- Collect paths/URLs from other tmux panes, newest first.
---@return table[]
function M.collect()
  local items, seen = {}, {}
  for _, pane in ipairs(panes()) do
    -- -J joins soft-wrapped lines so long paths stay intact
    local lines = vim.fn.systemlist {
      'tmux', 'capture-pane', '-J', '-p', '-S', '-' .. M.config.lines, '-t', pane.id,
    }
    for i = #lines, 1, -1 do
      local line = lines[i]
      if M.config.show_urls then
        for url in line:gmatch 'https?://[^%s"\'<>()]+' do
          url = url:gsub('[%.,;:%)%]]+$', '')
          if not seen[url] then
            seen[url] = true
            table.insert(items, { text = url, url = url })
          end
        end
      end
      for raw in line:gmatch '[~%.]*/[%w%._@%%%+~/%-]+[:%d]*' do
        raw = raw:gsub('[%.,;:%)]+$', '')
        local p, lnum = raw:match '^(.-):(%d+)$'
        p = p or raw
        -- skip the "//host/..." tail of URLs
        if not p:match '^//' then
          local abs = resolve(p, pane.cwd)
          local key = abs .. ':' .. (lnum or '')
          if not seen[key] and vim.uv.fs_stat(abs) then
            seen[key] = true
            table.insert(items, { text = raw, file = abs, pos = lnum and { tonumber(lnum), 0 } or nil })
          end
        end
      end
    end
  end
  return items
end

local function open(item)
  if item.url then
    vim.ui.open(item.url)
  elseif vim.fn.isdirectory(item.file) == 1 then
    Snacks.picker.files { cwd = item.file }
  else
    vim.cmd.edit(vim.fn.fnameescape(item.file))
    if item.pos then
      pcall(vim.api.nvim_win_set_cursor, 0, item.pos)
    end
  end
end

--- Open the picker.
function M.pick()
  if not vim.env.TMUX then
    vim.notify('tmux-paths: not inside tmux', vim.log.levels.WARN)
    return
  end
  if not _G.Snacks or not Snacks.picker then
    vim.notify('tmux-paths: requires folke/snacks.nvim with picker enabled', vim.log.levels.ERROR)
    return
  end
  local items = M.collect()
  if #items == 0 then
    vim.notify('tmux-paths: no paths/URLs found in other panes', vim.log.levels.INFO)
    return
  end
  Snacks.picker {
    title = 'Paths/URLs from tmux panes',
    items = items,
    format = 'text',
    preview = function(ctx)
      if ctx.item.file and vim.fn.isdirectory(ctx.item.file) == 0 then
        return Snacks.picker.preview.file(ctx)
      end
      ctx.preview:reset()
      ctx.preview:set_lines { ctx.item.url or ctx.item.file }
    end,
    confirm = function(picker, item)
      picker:close()
      if item then
        open(item)
      end
    end,
  }
end

return M
