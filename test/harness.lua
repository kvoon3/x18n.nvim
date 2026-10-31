-- Headless harness: boots nvim with the plugin, opens the playground fixture,
-- waits for the x18n server to report ready, then runs assertions.
-- Usage: nvim -l test/harness.lua <script.lua>

local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h'):gsub('/playground$', '')
local playground = plugin_root .. '/playground'

vim.opt.runtimepath:prepend(plugin_root)
require('x18n').setup {}

local function wait_for(cond, timeout_ms)
  timeout_ms = timeout_ms or 15000
  local expired = vim.uv.now() + timeout_ms
  while vim.uv.now() < expired do
    if cond() then
      return true
    end
    vim.wait(100, function() return cond() end, 50)
    vim.cmd 'redraw'
  end
  return cond()
end

local function server_ready()
  local client = vim.lsp.get_clients({ name = 'x18n' })[1]
  return client ~= nil
end

vim.cmd('edit ' .. playground .. '/src/main.js')
-- -l mode skips filetype detection, which the LSP attach rules key on.
vim.cmd 'filetype detect'
assert(vim.bo.filetype == 'javascript', 'filetype detection failed, got ' .. vim.bo.filetype)
assert(wait_for(server_ready), 'x18n server did not attach to src/main.js')

-- The server indexes after initialize; wait until decorations report a real locale.
wait_for(function()
  return #vim.api.nvim_buf_get_extmarks(0, require('x18n.decorations').namespace(), 0, -1, {}) > 0
end)

local script = assert(arg[1], 'usage: nvim -l test/harness.lua <script.lua>')
local chunk = assert(loadfile(script))
chunk({
  playground = playground,
  wait_for = wait_for,
  buf = vim.api.nvim_get_current_buf(),
})
vim.cmd 'qa!'
