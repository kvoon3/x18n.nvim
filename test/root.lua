local lsp = require 'x18n.lsp'
local scratch = vim.fn.tempname()
vim.fn.mkdir(scratch .. '/repo/app/sub/src', 'p')
vim.fn.mkdir(scratch .. '/repo/project/src', 'p')
vim.fn.mkdir(scratch .. '/empty/src', 'p')
vim.fn.writefile({ '{}' }, scratch .. '/repo/package.json')
vim.fn.writefile({ '{}' }, scratch .. '/repo/app/sub/package.json')
vim.fn.writefile({ 'export default {}' }, scratch .. '/repo/app/x18n.config.ts')
vim.fn.writefile({ '{}' }, scratch .. '/repo/project/composer.json')

local markers = { 'x18n.config.ts', 'package.json', 'composer.json', '.git' }
local function real(path)
  return vim.uv.fs_realpath(path) or path
end

local function resolve(path)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, path)
  local root
  lsp.root_dir_for(markers)(buf, function(dir)
    root = dir
  end)
  vim.api.nvim_buf_delete(buf, { force = true })
  return root and real(root)
end

assert(
  resolve(scratch .. '/repo/app/sub/src/code.ts') == real(scratch .. '/repo/app'),
  'x18n config did not win over a nearer package.json'
)
assert(
  resolve(scratch .. '/repo/project/src/code.php') == real(scratch .. '/repo/project'),
  'root package.json shadowed the closer composer.json'
)
assert(resolve(scratch .. '/empty/src/code.js') == nil, 'a marker-less tree produced a root')
print 'root ok'
