local M = {}

local util = require 'x18n.util'

--- Extract hard strings of the current buffer into locale files.
function M.extract()
  local init = require 'x18n'
  local client = init.get_client()
  if not client then
    return
  end
  --[[ The server applies the rewrite itself via workspace/applyEdit; the identical
    edit also arrives as the request result. Applying that result here too would
    double-patch the buffers, so it is only logged. ]]
  client:request('workspace/executeCommand', {
    command = 'x18n.extract',
    arguments = { { uri = vim.uri_from_bufnr(0) } },
  }, function(err, result)
    if err then
      return init.notify(err.message, vim.log.levels.WARN)
    end
    init.debug(('extract ok, %d document change(s) applied via applyEdit'):format(result and result.documentChanges and #result.documentChanges or 0))
  end)
end

--- Start the loopback web UI and open it in the browser.
function M.open_ui()
  local init = require 'x18n'
  local client = init.get_client()
  if not client then
    return
  end
  client:request('x18n/openUi', {}, function(err, result)
    if err or not result or not result.url then
      return init.notify(err and err.message or 'the UI did not start', vim.log.levels.WARN)
    end
    vim.ui.open(result.url)
  end)
end

--- Switch the locale shown in hovers, inlay hints and decorations.
---@param locale string
function M.set_display_locale(locale)
  local init = require 'x18n'
  local client = init.get_client()
  if not client then
    return
  end
  --[[ Documented as a notification, not a request: sending it as a request makes
    the server answer "Unhandled method" and stall subsequent work. ]]
  client:notify('x18n/setDisplayLocale', { locale = locale })
  init.notify('display locale: ' .. locale)
  require('x18n.decorations').refresh_attached()
end

--- Jump to the key under the cursor in the next locale file, wrapping around.
--- Works both from a translate call and from inside a locale file.
---@return string? opened uri
function M.next_definition()
  local init = require 'x18n'
  local client = init.get_client()
  if not client then
    return nil
  end
  local bufnr = vim.api.nvim_get_current_buf()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  client:request('textDocument/implementation', {
    textDocument = { uri = vim.uri_from_bufnr(bufnr) },
    position = { line = row - 1, character = util.to_utf16(bufnr, row - 1, col) },
  }, function(err, result)
    if err then
      return init.notify(err.message, vim.log.levels.WARN)
    end
    local locations = result or {}
    if #locations == 0 then
      return init.notify('no i18n key under the cursor')
    end
    local current_uri = vim.uri_from_bufnr(bufnr)
    local idx = 0
    for i, loc in ipairs(locations) do
      if loc.uri == current_uri then
        idx = i
        break
      end
    end
    local target = locations[idx % #locations + 1]
    util.jump(target)
    return target.uri
  end)
end

--- Popup with the key's value in every locale, from the server's hover data.
--- Returns false when the cursor is not on a key, so a keymap can fall back
--- (e.g. to signature help). Synchronous: the hover round trip is the wait.
---@return boolean shown
function M.show_translations()
  local init = require 'x18n'
  local client = init.get_client()
  if not client then
    return false
  end
  local bufnr = vim.api.nvim_get_current_buf()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local done, shown, cancelled = false, false, false
  client:request('textDocument/hover', {
    textDocument = { uri = vim.uri_from_bufnr(bufnr) },
    position = { line = row - 1, character = util.to_utf16(bufnr, row - 1, col) },
  }, function(err, result)
    if cancelled then
      --[[ The wait below already returned false; opening now would fire both the
      caller's fallback and the popup. ]]
      return
    end
    if not err and result and result.contents then
      local lines = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
      while #lines > 0 and lines[#lines] == '' do
        lines[#lines] = nil
      end
      if #lines > 0 then
        shown = true
        vim.schedule(function()
          util.preview('x18n', lines)
        end)
      end
    end
    done = true
  end)
  vim.wait(500, function() return done end, 25)
  if not done then
    cancelled = true
  end
  return shown
end

--- How the server understood the workspace: config files, presets, resources.
function M.explain()
  local init = require 'x18n'
  local client = init.get_client()
  if not client then
    return
  end
  client:request('x18n/explain', {}, function(err, result)
    if err then
      return init.notify(err.message, vim.log.levels.WARN)
    end
    vim.schedule(function()
      util.preview('x18n explain', vim.split(result or 'nothing to explain', '\n'))
    end)
  end)
end

return M
