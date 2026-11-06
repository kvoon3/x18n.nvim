local M = {}

local util = require 'x18n.util'
local lsp = require 'x18n.lsp'

local function qf_item(entry, kind, label, loc)
  local range = loc and loc.range or { start = { line = 0, character = 0 } }
  local item = {
    text = ('[%s] %s'):format(label, entry.key),
    type = kind,
  }
  if loc and loc.uri then
    local fname = vim.uri_to_fname(loc.uri)
    local bufnr = vim.fn.bufadd(fname)
    if vim.fn.bufloaded(bufnr) == 0 then
      vim.fn.bufload(bufnr)
    end
    local row, col = util.to_byte(bufnr, range.start)
    item.filename = fname
    item.lnum = row + 1
    item.col = col + 1
  end
  return item
end

local function entry_items(entry, kind, label)
  local locations = entry.locations or (entry.location and { entry.location }) or {}
  if #locations == 0 then
    return { qf_item(entry, kind, label, nil) }
  end
  local items = {}
  for _, loc in ipairs(locations) do
    items[#items + 1] = qf_item(entry, kind, label, loc)
  end
  return items
end

function M.show(report)
  local sections = {
    { report.missing, 'E', 'missing' },
    { report.unused, 'W', 'unused' },
  }
  local items = {}
  for _, section in ipairs(sections) do
    for _, entry in ipairs(section[1] or {}) do
      for _, item in ipairs(entry_items(entry, section[2], section[3])) do
        items[#items + 1] = item
      end
    end
  end
  table.sort(items, function(a, b)
    if a.filename ~= b.filename then
      return (a.filename or '') < (b.filename or '')
    end
    return (a.lnum or 0) < (b.lnum or 0)
  end)

  if #items == 0 then
    require('x18n').notify 'no missing or unused keys'
    return
  end
  vim.fn.setqflist(items)
  vim.cmd 'copen'
end

function M.run()
  local client = require('x18n').get_client()
  if not client then
    return
  end
  lsp.custom_request(client, 'x18n/usageReport', {}, function(err, result)
    require('x18n').debug(
      ('usageReport err=%s unused=%s missing=%s'):format(
        tostring(err),
        tostring(result and result.unused and #result.unused),
        tostring(result and result.missing and #result.missing)
      )
    )
    if err then
      return require('x18n').notify(err.message, vim.log.levels.WARN)
    end
    vim.schedule(function()
      M.show(result or {})
    end)
  end)
end

return M
