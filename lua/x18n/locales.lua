local M = {}

-- Cache of the projects/locales reply, refreshed on demand.
local info = nil

--- Fetch project info (locales, display locale) from the server.
--- Cached: the locale list only changes when the config changes.
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
  client:request('x18n/projects', {}, function(err, result)
    info = err and nil or result
    done = true
  end)
  vim.wait(2000, function() return done end, 50)
  return info
end

--- The locales of the first project, source locale first as the server orders them.
---@return string[]
function M.locales()
  local projects = M.projects()
  if not projects or #projects == 0 then
    return {}
  end
  local out = {}
  for _, l in ipairs(projects[1].locales or {}) do
    out[#out + 1] = l.code
  end
  return out
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
  -- setDisplayLocale changes what the server reports back; drop the cache.
  info = nil
  return next_locale
end

return M
