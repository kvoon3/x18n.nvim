local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h'):gsub('/playground$', '')
local script = assert(arg[1], 'usage: nvim -l test/harness.lua <script.lua>')
local decorations_disabled = script:find('decorations_disabled', 1, true) ~= nil

local fixture = plugin_root .. '/test/fixture'
--[[ Outside nvim's tempname root: vim.fn.tempname() is reaped by nvim on exit
  while the server may still be shutting down, and diagnostics/cache writes go
  through node_modules during the run. One directory per process keeps
  concurrent suite runs apart. ]]
local playground_fixture = ('%s/x18n-nvim-test-%d'):format(vim.uv.os_tmpdir(), vim.fn.getpid())
vim.fn.delete(playground_fixture, 'rf')
vim.fn.mkdir(playground_fixture, 'p')
--[[ macOS /tmp and /var are symlinks; the server reports realpaths, so pin the
  fixture root to one. Tests compare item data roots against ctx.playground. ]]
playground_fixture = vim.uv.fs_realpath(playground_fixture) or playground_fixture
local copied = vim.fn.system { 'rsync', '-a', fixture .. '/', playground_fixture .. '/' }
assert(vim.v.shell_error == 0, 'fixture copy failed: ' .. copied)
vim.api.nvim_create_autocmd('VimLeavePre', {
  callback = function()
    vim.fn.delete(playground_fixture, 'rf')
  end,
})

vim.opt.runtimepath:prepend(plugin_root)
local bin = vim.env.X18N_LSP_BIN or (plugin_root .. '/node_modules/@x18n/lsp/bin.mjs')
local opts = {
  lsp = {
    cmd = { 'node', bin, '--stdio' },
  },
}
if decorations_disabled then
  opts.decorations = false
end
require('x18n').setup(opts)

local function wait_for(cond, timeout_ms)
  timeout_ms = timeout_ms or 15000
  local expired = vim.uv.now() + timeout_ms
  while vim.uv.now() < expired do
    if cond() then
      return true
    end
    vim.wait(100, function()
      return cond()
    end, 50)
    vim.cmd 'redraw'
  end
  return cond()
end

local function server_ready()
  local client = vim.lsp.get_clients({ name = 'x18n' })[1]
  return client ~= nil
end

vim.cmd('edit ' .. playground_fixture .. '/src/main.js')
--[[ -l mode skips filetype detection, which the LSP attach rules key on. ]]
vim.cmd 'filetype detect'
assert(vim.bo.filetype == 'javascript', 'filetype detection failed, got ' .. vim.bo.filetype)
assert(wait_for(server_ready), 'x18n server did not attach to src/main.js')

if not decorations_disabled then
  wait_for(function()
    return #vim.api.nvim_buf_get_extmarks(0, require('x18n.decorations').namespace(), 0, -1, {}) > 0
  end)
end

local function key_info_available()
  local client = vim.lsp.get_clients({ name = 'x18n' })[1]
  if not client then
    return false
  end
  local done, supported = false, false
  client:request('x18n/keyInfo', {
    uri = vim.uri_from_bufnr(0),
    position = { line = 0, character = 0 },
  }, function(err)
    supported = err == nil
    done = true
  end)
  assert(
    wait_for(function()
      return done
    end, 5000),
    'x18n/keyInfo probe timed out'
  )
  return supported
end

local upstream = not key_info_available()
if upstream then
  print 'server has no x18n/keyInfo: fork-only tests skip'
end

local chunk = assert(loadfile(script))
chunk {
  playground = playground_fixture,
  plugin_root = plugin_root,
  wait_for = wait_for,
  buf = vim.api.nvim_get_current_buf(),
  upstream = upstream,
}
vim.cmd 'qa!'
