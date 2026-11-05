local ctx = ...
local lifecycle = require 'x18n.lifecycle'
local ns = require('x18n.decorations').namespace()

if ctx.upstream then
  require('x18n.decorations').setup {
    mode = 'conceal',
    debounce_ms = 100,
    show_locale_file_eol_translation = true,
    show_locale_file_eol_usage = true,
  }
end

vim.cmd 'runtime! plugin/x18n.lua'

local function clients(bufnr)
  return vim.lsp.get_clients { bufnr = bufnr, name = 'x18n' }
end

local function marks(bufnr)
  return #vim.api.nvim_buf_get_extmarks(bufnr or ctx.buf, ns, 0, -1, {})
end

assert(#clients() > 0, 'baseline client missing')
assert(lifecycle.is_enabled() == true, 'is_enabled false while running')
assert(
  ctx.wait_for(function()
    return marks() > 0
  end, 5000),
  'baseline marks missing'
)

assert(lifecycle.disable() == true, 'disable returned false')
assert(#clients() == 0, 'client survived disable')
assert(lifecycle.is_enabled() == false, 'is_enabled true after disable')
assert(marks() == 0, 'marks survived disable')
assert(vim.wo.conceallevel == 0, 'conceallevel survived disable')

vim.cmd('edit ' .. ctx.playground .. '/locales/en.json')
vim.cmd 'filetype detect'
ctx.wait_for(function()
  return false
end, 600)
local ebuf = vim.api.nvim_get_current_buf()
assert(#clients(ebuf) == 0, 'disabled autostart attached to en.json')

assert(lifecycle.enable() == true, 'enable returned false')
assert(
  ctx.wait_for(function()
    return #clients(ebuf) > 0
  end, 8000),
  'enable did not attach to en.json'
)
assert(
  ctx.wait_for(function()
    return marks(ebuf) > 0
  end, 8000),
  'locale EOL marks did not return'
)

local old_id = clients(ebuf)[1].id
assert(lifecycle.reload() == true, 'reload returned false')
assert(
  ctx.wait_for(function()
    local list = clients(ebuf)
    return #list > 0 and list[1].id ~= old_id
  end, 8000),
  'reload did not start a new client'
)
assert(vim.lsp.get_client_by_id(old_id) == nil, 'old client survived reload')
assert(
  ctx.wait_for(function()
    return marks(ebuf) > 0
  end, 8000),
  'marks did not return after reload'
)

vim.cmd 'X18nDisable'
assert(#clients() == 0, 'X18nDisable left a client')
vim.cmd 'X18nEnable'
assert(
  ctx.wait_for(function()
    return #clients() > 0
  end, 8000),
  'X18nEnable did not start a client'
)
print 'lifecycle ok'
