local M = {}

local util = require 'x18n.util'
local lsp = require 'x18n.lsp'

---@class x18n.PromptTarget
---@field project string resolved project name, always passed to the server
---@field locale string  display locale, required by x18n/translatePrompt

--- The non-source locales of a project, in the server's order.
---@param info table ProjectInfo
---@return string[]
local function targets(info)
  local out = {}
  for _, locale in ipairs(info.locales or {}) do
    if locale.code ~= info.sourceLocale then
      out[#out + 1] = locale.code
    end
  end
  return out
end

---@param projects table[]
---@param name string?
---@return table?
local function project_info(projects, name)
  if not name then
    return projects[1]
  end
  for _, candidate in ipairs(projects) do
    if candidate.name == name then
      return candidate
    end
  end
end

--- The server's effective display locale for a project, resolved from the
--- ProjectInfo cache. The source locale is the server's own fallback when the
--- display locale is not part of the project. Fails loudly when an explicit
--- project is not in the cache; silence would send the wrong project's locale.
---@param projects table[] ProjectInfo list
---@param project string? project of the key under the cursor, when known
---@param locale_arg string? explicit locale from the command line
---@return x18n.PromptTarget?
local function target(projects, project, locale_arg)
  local info = project_info(projects, project)
  if not info then
    require('x18n').notify('unknown project ' .. project, vim.log.levels.WARN)
    return nil
  end
  local available = targets(info)
  if #available == 0 then
    require('x18n').notify('no target locale to translate to', vim.log.levels.WARN)
    return nil
  end
  local codes = table.concat(available, ', ')
  if locale_arg and locale_arg ~= '' then
    for _, code in ipairs(available) do
      if code == locale_arg then
        return { project = info.name, locale = locale_arg }
      end
    end
    if locale_arg == info.sourceLocale then
      require('x18n').notify(
        ('cannot translate to the source locale %s; target locales: %s'):format(locale_arg, codes),
        vim.log.levels.WARN
      )
    else
      require('x18n').notify(('unknown locale %s; target locales: %s'):format(locale_arg, codes), vim.log.levels.WARN)
    end
    return nil
  end
  if info.displayLocale and info.displayLocale ~= info.sourceLocale then
    return { project = info.name, locale = info.displayLocale }
  end
  return { project = info.name, locale = available[1] }
end

--- The key under the cursor, only when this buffer's own x18n client can see
--- one. Cursor-sensitive, so the buffer-attached client is mandatory. Returns
--- the project even for a resource subtree, where the key is not an exact
--- target and must not narrow the prompt. Silent on failure.
---@return string? key, string? project
local function key_at_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local client = vim.lsp.get_clients({ bufnr = bufnr, name = 'x18n' })[1]
  if not client then
    return nil, nil
  end
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local done, at = false, nil
  lsp.custom_request(client, 'x18n/keyAt', {
    uri = vim.uri_from_bufnr(bufnr),
    position = { line = row - 1, character = util.to_utf16(bufnr, row - 1, col) },
  }, function(err, result)
    at = not err and result or nil
    done = true
  end)
  vim.wait(2000, function()
    return done
  end, 25)
  if not at then
    return nil, nil
  end
  return at.type == 'key' and at.key or nil, at.project
end

--- Copy the display-locale translate prompt, narrowed to the key under the
--- cursor when there is one. Asynchronous: the registers fill when the server
--- answers. No key is not an error; the project-wide prompt is the fallback.
---@param locale_arg string? explicit target locale
---@return boolean started false when no request could start
function M.copy(locale_arg)
  local init = require 'x18n'
  local client = init.get_client()
  if not client then
    return false
  end
  local projects = require('x18n.locales').projects()
  if not projects or #projects == 0 then
    init.notify('the server reports no projects', vim.log.levels.WARN)
    return false
  end
  local key, key_project = key_at_cursor()
  local resolved = target(projects, key_project, locale_arg)
  if not resolved then
    return false
  end
  local params = { project = resolved.project, locale = resolved.locale }
  if key then
    params.keys = { key }
  end
  lsp.custom_request(client, 'x18n/translatePrompt', params, function(err, result)
    if err then
      return init.notify(err.message, vim.log.levels.WARN)
    end
    local prompt = result or ''
    local for_key = key and (' for ' .. key) or ''
    if prompt:find('Nothing to do:', 1, true) then
      return init.notify(('nothing to translate to %s%s'):format(resolved.locale, for_key), vim.log.levels.WARN)
    end
    vim.fn.setreg('"', prompt)
    vim.fn.setreg('+', prompt)
    init.notify(('copied %s translate prompt%s'):format(resolved.locale, for_key))
  end)
  return true
end

return M
