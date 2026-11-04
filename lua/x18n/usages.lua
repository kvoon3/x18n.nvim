local M = {}

local util = require 'x18n.util'

local function describe(location)
  local path = vim.uri_to_fname(location.uri)
  local bufnr = vim.fn.bufadd(path)
  vim.fn.bufload(bufnr)
  local row, col = util.to_byte(bufnr, location.range.start)
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''
  line = line:gsub('^%s+', ''):gsub('%s+$', '')
  return ('%s:%d:%d  %s'):format(vim.fn.fnamemodify(path, ':~:.'), row + 1, col + 1, line:sub(1, 80))
end

--- Jump to the usages of the key under the cursor. One hit opens directly,
--- several go through vim.ui.select. Returns false when no key is found or the
--- server does not answer in time, so a keymap can chain to references.
---@return boolean handled
function M.jump_under_cursor()
  local init = require 'x18n'
  local client = init.get_client()
  if not client then
    return false
  end
  local bufnr = vim.api.nvim_get_current_buf()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local done, locations, err = false, nil, nil
  client:request('textDocument/references', {
    textDocument = { uri = vim.uri_from_bufnr(bufnr) },
    position = { line = row - 1, character = util.to_utf16(bufnr, row - 1, col) },
    context = { includeDeclaration = false },
  }, function(request_err, result)
    err, locations = request_err, result
    done = true
  end)
  vim.wait(2000, function()
    return done
  end, 25)
  if not done then
    return false
  end
  if err then
    init.notify(err.message, vim.log.levels.WARN)
    return false
  end
  if not locations or #locations == 0 then
    --[[ references cannot tell "not on a key" from "key with no usages"; keyAt
      can, and upstream reports the two differently. ]]
    local key, checked = nil, false
    client:request('x18n/keyAt', {
      uri = vim.uri_from_bufnr(bufnr),
      position = { line = row - 1, character = util.to_utf16(bufnr, row - 1, col) },
    }, function(key_err, key_result)
      if not key_err and key_result then
        key = key_result.key
      end
      checked = true
    end)
    vim.wait(2000, function()
      return checked
    end, 25)
    if not key then
      if (init.config.usage or {}).notify_no_key ~= false then
        init.notify 'no i18n key under the cursor'
      end
      return false
    end
    init.notify(('no usages for %s'):format(key))
    return false
  end
  if #locations == 1 then
    util.jump(locations[1])
    return true
  end
  vim.ui.select(locations, {
    prompt = 'x18n usages',
    format_item = describe,
  }, function(choice)
    if choice then
      util.jump(choice)
    end
  end)
  return true
end

return M
