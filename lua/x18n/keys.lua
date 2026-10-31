local M = {}

local util = require 'x18n.util'

--- All keys of the workspace from the server's symbol index.
---@param on_result fun(entries: {key: string, value: string, location: table?}[])
local function list(client, on_result)
  client:request('workspace/symbol', { query = '' }, function(err, result)
    if err then
      return require('x18n').notify(err.message, vim.log.levels.WARN)
    end
    local entries = {}
    for _, sym in ipairs(result or {}) do
      entries[#entries + 1] = {
        key = sym.name,
        value = sym.containerName or '',
        location = sym.location,
      }
    end
    if #entries >= 500 then
      require('x18n').notify 'showing the first 500 keys'
    end
    vim.schedule(function()
      on_result(entries)
    end)
  end)
end

local actions = {
  --- Jump to the key's definition.
  jump = function(entry)
    if entry.location then
      util.jump(entry.location)
    end
  end,
  --- Copy the key, e.g. to paste into a t('...') call.
  copy_key = function(entry)
    vim.fn.setreg('"', entry.key)
    vim.fn.setreg('+', entry.key)
    require('x18n').notify(('copied %s'):format(entry.key))
  end,
}

--- Pick from all keys; the chosen action runs against the selection.
---@param action 'jump'|'copy_key'?
function M.pick(action)
  action = action or 'jump'
  local client = require('x18n').get_client()
  if not client then
    return
  end
  list(client, function(entries)
    if #entries == 0 then
      return require('x18n').notify 'no keys indexed'
    end
    vim.ui.select(entries, {
      prompt = 'x18n keys',
      format_item = function(entry)
        return ('%s = %s'):format(entry.key, entry.value)
      end,
    }, function(choice)
      if choice then
        actions[action](choice)
      end
    end)
  end)
end

return M
