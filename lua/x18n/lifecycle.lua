local M = {}

local lsp = require 'x18n.lsp'

local function clients()
  return vim.lsp.get_clients { name = 'x18n' }
end

local function wait_detached()
  vim.wait(3000, function()
    return #clients() == 0
  end, 25)
end

--- True while at least one x18n client runs.
---@return boolean
function M.is_enabled()
  return #clients() > 0
end

--- Start the client for the current buffer. Safe when it already runs.
---@return boolean enabled
function M.enable()
  local init = require 'x18n'
  vim.lsp.enable('x18n', true)
  if not lsp.start() then
    init.notify('no x18n project root for this buffer', vim.log.levels.WARN)
    return false
  end
  init.notify 'x18n enabled'
  return true
end

--- Stop every client and prevent root-marker autostart until :X18nEnable.
---@return boolean disabled
function M.disable()
  local init = require 'x18n'
  vim.lsp.enable('x18n', false)
  lsp.stop()
  wait_detached()
  require('x18n.decorations').clear_all()
  init.notify 'x18n disabled'
  return true
end

--- Restart the client, which reloads the project from disk.
---@return boolean reloaded
function M.reload()
  local init = require 'x18n'
  vim.lsp.enable('x18n', true)
  lsp.stop()
  wait_detached()
  require('x18n.decorations').clear_all()
  if not lsp.start() then
    init.notify('no x18n project root for this buffer', vim.log.levels.WARN)
    return false
  end
  init.notify 'x18n reloaded'
  return true
end

return M
