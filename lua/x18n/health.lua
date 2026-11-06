local M = {}

---@type string
local MINIMUM_SERVER = '0.1.13'

---@param actual string?
---@param required string
---@return boolean
local function version_at_least(actual, required)
  local function parts(version)
    local major, minor, patch = (version or ''):match '^(%d+)%.(%d+)%.(%d+)'
    return tonumber(major), tonumber(minor), tonumber(patch)
  end
  local major, minor, patch = parts(actual)
  local required_major, required_minor, required_patch = parts(required)
  if not major then
    return false
  end
  if major ~= required_major then
    return major > required_major
  end
  if minor ~= required_minor then
    return minor > required_minor
  end
  return patch >= required_patch
end

function M.check()
  vim.health.start 'x18n.nvim'

  if vim.fn.has 'nvim-0.11' == 1 then
    vim.health.ok 'Neovim 0.11 or newer'
  else
    vim.health.error 'Neovim 0.11 or newer is required (vim.lsp.config)'
  end

  if vim.fn.executable 'x18n-lsp' == 1 then
    vim.health.ok '`x18n-lsp` found on PATH'
  else
    vim.health.warn '`x18n-lsp` not found — install it with `npm install -g @x18n/lsp`'
  end

  local clients = vim.lsp.get_clients { name = 'x18n' }
  if #clients > 0 then
    vim.health.ok(('x18n-lsp is running (%d instance)'):format(#clients))
    local version = clients[1].server_info and clients[1].server_info.version
    if not version then
      vim.health.warn(('x18n-lsp version unknown; x18n.nvim needs %s or newer'):format(MINIMUM_SERVER))
    elseif version_at_least(version, MINIMUM_SERVER) then
      vim.health.ok(('x18n-lsp %s'):format(version))
    else
      vim.health.error(
        ('x18n-lsp %s is older than %s; upgrade with `npm install -g @x18n/lsp`'):format(version, MINIMUM_SERVER)
      )
    end
  else
    vim.health.info 'not attached in this session — open a buffer in a project x18n recognizes'
  end
end

return M
