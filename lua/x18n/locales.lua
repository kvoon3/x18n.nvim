local M = {}

local lsp = require 'x18n.lsp'

local info = nil
local warming = false
local display_override = nil

--- Fire the x18n/projects request without waiting, filling the cache when the
--- answer lands. Called from completion and on server changes, where blocking
--- (vim.wait) would freeze the UI.
function M.warm()
  local client = require('x18n').client()
  if not client or warming then
    return
  end
  warming = true
  lsp.custom_request(client, 'x18n/projects', {}, function(err, result)
    warming = false
    if not err then
      info = result
    end
  end)
end

--- Fetch project info (locales, display locale) from the server, blocking briefly.
---@param force boolean? Re-fetch even when cached.
---@return table? projects
function M.projects(force)
  if info and not force then
    return info
  end
  local client = require('x18n').get_client()
  if not client then
    return nil
  end
  local done = false
  lsp.custom_request(client, 'x18n/projects', {}, function(err, result)
    info = err and nil or result
    done = true
  end)
  vim.wait(2000, function()
    return done
  end, 50)
  return info
end

--- The locales of the first project, source locale first as the server orders them.
---@return string[]
function M.locales()
  local projects = info or M.projects()
  if not projects or #projects == 0 then
    return {}
  end
  local out = {}
  for _, l in ipairs(projects[1].locales or {}) do
    out[#out + 1] = l.code
  end
  return out
end

--- The cached locale list without any server traffic. Completion uses this: it
--- must not block, so a cold cache returns nothing and warms for next time.
---@return string[]
function M.cached()
  if not info or #info == 0 then
    return {}
  end
  local out = {}
  for _, l in ipairs(info[1].locales or {}) do
    out[#out + 1] = l.code
  end
  return out
end

--- The locale currently shown in hovers and decorations. Non-blocking: the
--- explicit switch wins while the projects cache is cold.
---@return string?
function M.display_locale()
  local projects = info
  if not projects then
    M.warm()
    return display_override
  end
  return (projects[1] and projects[1].displayLocale) or display_override
end

--- Keep the cached project info in step after a display-locale switch.
---@param locale string
function M.set_display(locale)
  display_override = locale
  if info and info[1] then
    info[1].displayLocale = locale
  end
  M.warm()
end

--- The key details at a position.
---@param client vim.lsp.Client
---@param uri string
---@param position table LSP position, already in UTF-16 columns
---@param on_result fun(info: table?)
function M.key_info(client, uri, position, on_result)
  lsp.custom_request(client, 'x18n/keyInfo', {
    uri = uri,
    position = position,
  }, function(err, result)
    on_result(not err and result or nil)
  end)
end

---@alias x18n.KeyLocation {code: string?, location: table}

---@class x18n.KeyLocations
---@field paired boolean
---@field [integer] x18n.KeyLocation

---@param locales table[]
---@param count integer
---@return string[]?
local function present_codes(locales, count)
  local codes = {}
  for _, locale in ipairs(locales) do
    if locale.present then
      codes[#codes + 1] = locale.code
    end
  end
  if #codes ~= count then
    return nil
  end
  return codes
end

--- Every locale definition of the key at a position, paired with its code.
--- The server sorts implementation locations by project locale order; keyInfo
--- says which locales actually define the key.
---@param on_result fun(pairs: x18n.KeyLocations, info: table?)
function M.key_locations(client, uri, position, on_result)
  M.key_info(client, uri, position, function(value)
    client:request('textDocument/implementation', {
      textDocument = { uri = uri },
      position = position,
    }, function(err, locations)
      locations = not err and locations or {}
      local codes = value and value.locales and present_codes(value.locales, #locations) or nil
      local result = { paired = codes ~= nil }
      for i, location in ipairs(locations) do
        result[i] = { code = codes and codes[i] or nil, location = location }
      end
      on_result(result, value)
    end)
  end)
end

--- The definition for a locale, falling back to the first locale.
---@param pairs x18n.KeyLocations
---@param code string?
---@return table? location
function M.location_for(pairs, code)
  code = code or M.display_locale()
  if pairs.paired ~= false then
    for _, pair in ipairs(pairs) do
      if pair.code == code then
        return pair.location
      end
    end
  end
  return pairs[1] and pairs[1].location
end

--- Cycle the display locale to the next entry and refresh everything visible.
---@return string? the new locale
function M.next()
  local locales = M.locales()
  if #locales == 0 then
    return nil
  end
  local projects = M.projects()
  local current = projects and projects[1].displayLocale or locales[1]
  local idx = 1
  for i, code in ipairs(locales) do
    if code == current then
      idx = i
      break
    end
  end
  local next_locale = locales[idx % #locales + 1]
  require('x18n.actions').set_display_locale(next_locale)
  --[[ setDisplayLocale changes what the server reports back; refill without blocking. ]]
  info = nil
  M.warm()
  return next_locale
end

return M
