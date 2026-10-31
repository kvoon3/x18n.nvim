local M = {}

local util = require 'x18n.util'

--- Progress per locale as "en 3/3" style short lines.
---@param project table ProjectInfo
---@param progress table? ProgressResult
---@return string[]
local function locale_lines(project, progress)
  local coverage = {}
  if progress then
    for _, p in ipairs(progress.projects) do
      if p.name == project.name then
        for _, l in ipairs(p.locales) do
          coverage[l.locale] = l
        end
      end
    end
  end
  local out = {}
  for _, locale in ipairs(project.locales) do
    local marker = locale.code == project.sourceLocale and ' (source)' or ''
    local c = coverage[locale.code]
    local progress_text = c and (' %d/%d translated'):format(c.translated, c.total) or ''
    local missing = c and #c.missing > 0 and (' missing %d'):format(#c.missing) or ''
    local flag = locale.flag and (locale.flag .. ' ') or ''
    out[#out + 1] = ('  %s%s%s%s%s'):format(flag, locale.code, marker, progress_text, missing)
  end
  return out
end

--- Show project, locales, display locale, key count and translation progress.
function M.show()
  local init = require 'x18n'
  local client = init.get_client()
  if not client then
    return
  end
  local projects = require('x18n.locales').projects(true)
  if not projects or #projects == 0 then
    return init.notify 'the server reports no projects'
  end

  local progress = nil
  local done = false
  client:request('x18n/progress', {}, function(err, result)
    progress = err and nil or result
    done = true
  end)
  vim.wait(2000, function() return done end, 50)

  local lines = {}
  for _, project in ipairs(projects) do
    if #lines > 0 then
      lines[#lines + 1] = ''
    end
    lines[#lines + 1] = ('%s (%d keys)'):format(project.name, project.keys)
    lines[#lines + 1] = '  root ' .. project.root
    for _, l in ipairs(locale_lines(project, progress)) do
      lines[#lines + 1] = l
    end
    lines[#lines + 1] = '  display locale ' .. project.displayLocale
  end
  util.preview('x18n status', lines)
end

return M
