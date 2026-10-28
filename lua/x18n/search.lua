local M = {}

function M.select(items)
  local init = require 'x18n'
  if #items == 0 then
    init.notify 'no matches'
    return
  end
  vim.ui.select(items, {
    prompt = 'x18n keys',
    format_item = function(item)
      return ('%s = %s (%s)'):format(item.key, item.value, item.locale)
    end,
  }, function(choice)
    if not choice or not choice.definition then
      return
    end
    vim.lsp.util.jump_to_location(choice.definition, 'utf-16')
  end)
end

---@param query string? Empty/nil prompts interactively.
function M.run(query)
  if not query or query == '' then
    query = vim.fn.input 'x18n search: '
    if query == '' then
      return
    end
  end
  local client = require('x18n').get_client()
  if not client then
    return
  end
  client:request('x18n/search', { query = query }, function(err, result)
    if err then
      return require('x18n').notify(err.message, vim.log.levels.WARN)
    end
    vim.schedule(function()
      M.select(result or {})
    end)
  end)
end

return M
