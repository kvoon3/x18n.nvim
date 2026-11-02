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
  require('x18n.locales').set_display(locale)
  init.notify('display locale: ' .. locale)
  require('x18n.decorations').refresh_attached()
end

--- List the key's locale definitions in the quickfix, the same list-first flow
--- as `grr` for references. A single definition jumps directly. Returns false
--- when the cursor is not on an x18n key or no client owns this buffer.
---@return boolean handled
function M.definition()
  local bufnr = vim.api.nvim_get_current_buf()
  local client = vim.lsp.get_clients({ bufnr = bufnr, name = 'x18n' })[1]
  if not client then
    return false
  end
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local locales = require 'x18n.locales'
  --[[ Warm the project cache before the fallback pairing and the markers. An
    upstream server has no structured hover, so key_locations falls back to the
    cached locale names; a cold cache would otherwise drop every definition. ]]
  local projects = locales.projects()
  local done, definitions, hover = false, nil, nil
  locales.key_locations(client, vim.uri_from_bufnr(bufnr), {
    line = row - 1,
    character = util.to_utf16(bufnr, row - 1, col),
  }, function(result, value)
    definitions = result
    hover = value
    done = true
  end)
  vim.wait(2000, function() return done end, 25)
  if not done or not definitions or #definitions == 0 then
    return false
  end
  if #definitions == 1 then
    return util.jump(definitions[1].location)
  end
  --[[ The key's own project carries the source and display markers. The
    structured hover names it; an upstream server without that field falls
    back to the first project. ]]
  local project
  if hover and hover.project then
    for _, candidate in ipairs(projects or {}) do
      if candidate.name == hover.project then
        project = candidate
        break
      end
    end
  end
  project = project or (projects and projects[1])
  local source = project and project.sourceLocale
  local display = project and project.displayLocale or locales.display_locale()
  --[[ Build the quickfix items in the definitions order. locations_to_items
    sorts and groups by URI, which would pair the locale labels with the wrong
    files whenever the server order differs from filename order. ]]
  local items = {}
  for _, definition in ipairs(definitions) do
    local location = definition.location
    local path = vim.uri_to_fname(location.uri)
    local file = vim.fn.bufadd(path)
    vim.fn.bufload(file)
    local line_row, line_col = util.to_byte(file, location.range.start)
    local line = vim.api.nvim_buf_get_lines(file, line_row, line_row + 1, false)[1] or ''
    local markers = {}
    if definition.code == source then
      markers[#markers + 1] = 'source'
    end
    if definition.code == display then
      markers[#markers + 1] = 'display'
    end
    local suffix = #markers > 0 and (' (' .. table.concat(markers, ', ') .. ')') or ''
    items[#items + 1] = {
      filename = path,
      lnum = line_row + 1,
      col = line_col + 1,
      text = ('[%s%s] %s'):format(definition.code, suffix, line),
      user_data = { locale = definition.code },
    }
  end
  vim.fn.setqflist({}, ' ', {
    title = 'x18n definitions',
    items = items,
    context = { method = 'textDocument/implementation', bufnr = bufnr },
  })
  vim.cmd 'copen'
  return true
end

--- Offer one add action per locale missing the key under the cursor. Works on
--- a code usage and on a missing-translation warning line in a locale file.
--- Returns false when no partially translated key is under the cursor, so the
--- Ctrl+. chain can fall back to the native code actions.
---@return boolean handled
function M.code_action()
  local bufnr = vim.api.nvim_get_current_buf()
  local client = vim.lsp.get_clients({ bufnr = bufnr, name = 'x18n' })[1]
  if not client then
    return false
  end
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local uri = vim.uri_from_bufnr(bufnr)
  local position = { line = row - 1, character = util.to_utf16(bufnr, row - 1, col) }
  local key_done, key_at = false, nil
  client:request('x18n/keyAt', { uri = uri, position = position }, function(err, result)
    key_at = not err and result or nil
    key_done = true
  end)
  vim.wait(2000, function() return key_done end, 25)
  if not key_at or not key_at.key then
    return false
  end
  local locales = require 'x18n.locales'
  local hover_done, hover = false, nil
  locales.hover_value(client, uri, position, function(value)
    hover = value
    hover_done = true
  end)
  vim.wait(2000, function() return hover_done end, 25)
  if not hover or not hover.locales then
    return false
  end
  local choices = {}
  for _, locale in ipairs(hover.locales) do
    if locale.value == nil then
      choices[#choices + 1] = {
        code = locale.code,
        title = ('Add "%s" to %s'):format(key_at.key, locale.code),
      }
    end
  end
  if #choices == 0 then
    return false
  end
  --[[ No `kind` hint here: snacks treats kind='codeaction' as real LSP actions
    and reads item.action/item.ctx, which these client-built entries lack. The
    select belongs to whichever picker the user configured. ]]
  vim.ui.select(choices, {
    prompt = 'x18n missing translations',
    format_item = function(choice)
      return choice.title
    end,
  }, function(choice)
    if choice then
      require('x18n.add_key').add_one(key_at.key, choice.code)
    end
  end)
  return true
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

--- Copy the resolved key from inside the translations float.
local function set_copy_keymap(bufnr, key)
  local cfg = require('x18n').config.translation_popup or {}
  local keys = cfg.keys and cfg.keys.copy_key or { '<C-y>' }
  if type(keys) == 'string' then
    keys = { keys }
  end
  for _, lhs in ipairs(keys) do
    vim.keymap.set('n', lhs, function()
      vim.fn.setreg('"', key)
      vim.fn.setreg('+', key)
      require('x18n').notify('copied ' .. key)
    end, { buffer = bufnr, nowait = true, desc = 'x18n: copy key' })
  end
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
      --[[ The fork's hover carries the data structured in result.x18n; upstream
        answers only markdown, which x18n/hover also knows how to reformat. ]]
      local hover = require 'x18n.hover'
      local key = result.x18n and result.x18n.value and result.x18n.value.key
      local lines = result.x18n and result.x18n.value and hover.from_value(result.x18n.value)
        or hover.format(vim.lsp.util.convert_input_to_markdown_lines(result.contents))
      key = key or (lines and lines[1] and lines[1]:match '^x18n%s+(.+)$')
      if lines and #lines > 0 then
        shown = true
        vim.schedule(function()
          --[[ The native preview machinery: anchored at the cursor, closes on
            cursor movement, `q` dismisses, and a second invocation focuses the
            open float instead of stacking another. No border or title here:
            float styling belongs to the user's config. ]]
          local fbuf = vim.lsp.util.open_floating_preview(lines, nil, {
            focus_id = 'x18n/translations',
          })
          if fbuf and key then
            set_copy_keymap(fbuf, key)
          end
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
      vim.lsp.util.open_floating_preview(vim.split(result or 'nothing to explain', '\n'), nil, {
        focus_id = 'x18n/explain',
        close_events = {},
      })
    end)
  end)
end

local fallbacks = { gh = {}, gd = {}, ['<C-.>'] = {} } -- lhs -> bufnr -> captured binding

local function fallback(bufnr, lhs, native)
  if fallbacks[lhs][bufnr] == nil then
    local existing = vim.fn.maparg(lhs, 'n', false, true)
    fallbacks[lhs][bufnr] = existing and existing.callback or native
  end
  return fallbacks[lhs][bufnr]
end

--- Chain `gh` and `gd` on x18n buffers: the translations popup or the locale
--- definitions on a key, the binding that was there before elsewhere (usually
--- LSP hover and definition). Safe to call again: other clients attach after
--- x18n and their LspAttach hooks rebind the keys plain, so init.lua re-runs
--- this on every attach and the original fallback is kept from the first
--- capture.
function M.default_keymaps(bufnr)
  local gh = fallback(bufnr, 'gh', function()
    vim.lsp.buf.hover()
  end)
  vim.keymap.set('n', 'gh', function()
    if not M.show_translations() then
      return gh()
    end
  end, { buffer = bufnr, desc = 'x18n: translations popup or hover' })
  local gd = fallback(bufnr, 'gd', function()
    vim.lsp.buf.definition()
  end)
  vim.keymap.set('n', 'gd', function()
    if not M.definition() then
      return gd()
    end
  end, { buffer = bufnr, desc = 'x18n: locale definitions or definition' })
  local code_action = fallback(bufnr, '<C-.>', function()
    vim.lsp.buf.code_action()
  end)
  vim.keymap.set({ 'n', 'v' }, '<C-.>', function()
    if not M.code_action() then
      return code_action()
    end
  end, { buffer = bufnr, desc = 'x18n: missing translations or code actions' })
end

return M
