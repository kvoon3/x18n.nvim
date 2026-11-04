-- Headless harness: boots nvim with the plugin, copies the test fixture to a
-- temp dir, opens its fixture file, waits for the x18n server to report ready,
-- then runs assertions.
-- Usage: nvim -l test/harness.lua <script.lua>

local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h'):gsub('/playground$', '')
local script = assert(arg[1], 'usage: nvim -l test/harness.lua <script.lua>')
-- The opt-out test declares its setup variant in its filename.
local decorations_disabled = script:find('decorations_disabled', 1, true) ~= nil

--[[ Tests never touch the vendored upstream playground: copy the pristine
  fixture to a temp dir and point the server at that copy. The fixture needs no
  node_modules: the server aliases @x18n/core and the presets to its own
  installation when it loads the config. ]]
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
-- Pin the server to the fork binary linked at the repo root by default, so
-- tests exercise the exact server the protocol was written against. Set
-- X18N_LSP_BIN to run the same tests against the published upstream server.
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
-- -l mode skips filetype detection, which the LSP attach rules key on.
vim.cmd 'filetype detect'
assert(vim.bo.filetype == 'javascript', 'filetype detection failed, got ' .. vim.bo.filetype)
assert(wait_for(server_ready), 'x18n server did not attach to src/main.js')

-- The server indexes after initialize; wait until decorations report a real locale.
if not decorations_disabled then
  wait_for(function()
    return #vim.api.nvim_buf_get_extmarks(0, require('x18n.decorations').namespace(), 0, -1, {}) > 0
  end)
end

local chunk = assert(loadfile(script))
chunk {
  playground = playground_fixture,
  wait_for = wait_for,
  buf = vim.api.nvim_get_current_buf(),
  upstream = vim.env.X18N_UPSTREAM == '1',
}
vim.cmd 'qa!'
