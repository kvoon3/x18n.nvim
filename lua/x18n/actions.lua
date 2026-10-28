local M = {}

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

return M
