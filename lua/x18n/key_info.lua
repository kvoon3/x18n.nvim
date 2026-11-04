local M = {}

-- Render x18n/keyInfo as aligned plain text for the translations float. The
-- server returns raw values; this module owns the presentation.

---@param info table KeyInfoResult from the server
---@return string[] lines
function M.render(info)
  local title = ('x18n %s'):format(info.key)
  if info.label and info.label ~= '' then
    title = title .. ' ' .. info.label
  end
  local out = { title }
  if #info.locales > 0 then
    out[#out + 1] = ''
    local rows = {}
    for _, l in ipairs(info.locales) do
      local suffix = l.source and ' (source)' or ''
      if l.changed and l.changed ~= '' then
        suffix = suffix .. ' · ' .. l.changed
      end
      if l.outdated then
        suffix = suffix .. ' · outdated'
      end
      local value
      if not l.present then
        value = '_missing_'
      elseif l.value == nil then
        value = '_no value_'
      elseif l.value == '' then
        value = '_empty_'
      else
        value = l.value
      end
      if l.state and l.state ~= '' then
        value = value .. ' (' .. l.state:gsub('%-', ' ') .. ')'
      end
      rows[#rows + 1] = {
        ('%s %s%s'):format(l.flag or '', l.code, suffix),
        value,
      }
    end
    local w = { 1, 2 }
    for _, r in ipairs(rows) do
      for c = 1, 2 do
        w[c] = math.max(w[c], vim.fn.strdisplaywidth(r[c]))
      end
    end
    for _, r in ipairs(rows) do
      out[#out + 1] = (r[1] .. string.rep(' ', w[1] - vim.fn.strdisplaywidth(r[1]) + 2) .. r[2]):gsub('%s+$', '')
    end
  end
  if #info.threads > 0 then
    out[#out + 1] = ''
    for _, t in ipairs(info.threads) do
      out[#out + 1] = ('review %s: %s'):format(t.locale, t.state)
    end
  end
  out[#out + 1] = ''
  out[#out + 1] = ('%d usage%s'):format(info.usages, info.usages == 1 and '' or 's')
  return out
end

return M
