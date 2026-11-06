local M = {}

---@param info table KeyInfoResult from the server
---@return string[] lines
function M.render(info)
  local title = ('x18n %s'):format(info.key)
  if info.label and info.label ~= '' then
    title = title .. ' ' .. info.label
  end
  local usages = info.usages or 0
  local usage = usages == 0 and 'no usages' or ('%d usage%s'):format(usages, usages == 1 and '' or 's')
  local out = { title .. ' · ' .. usage }
  if #info.locales > 0 then
    out[#out + 1] = ''
    local rows = {}
    for _, l in ipairs(info.locales) do
      local tags = {}
      if l.source then
        tags[#tags + 1] = 'source'
      end
      if l.outdated then
        tags[#tags + 1] = 'outdated'
      end
      local name = l.flag and l.flag ~= '' and (l.flag .. ' ' .. l.code) or l.code
      if #tags > 0 then
        name = ('%s (%s)'):format(name, table.concat(tags, ', '))
      end
      local value
      if not l.present then
        value = '— missing'
      elseif l.value == nil then
        value = '— no value'
      elseif l.value == '' then
        value = '— empty'
      else
        value = l.value:gsub('[\r\n]+', ' ')
      end
      if l.state and l.state ~= '' then
        value = value .. ' (' .. l.state:gsub('%-', ' ') .. ')'
      end
      rows[#rows + 1] = { name, value }
    end
    local width = 1
    for _, row in ipairs(rows) do
      width = math.max(width, vim.fn.strdisplaywidth(row[1]))
    end
    for _, row in ipairs(rows) do
      out[#out + 1] = (row[1] .. string.rep(' ', width - vim.fn.strdisplaywidth(row[1]) + 2) .. row[2]):gsub('%s+$', '')
    end
  end
  if #info.threads > 0 then
    out[#out + 1] = ''
    for _, t in ipairs(info.threads) do
      out[#out + 1] = ('review %s: %s'):format(t.locale, t.state)
    end
  end
  return out
end

return M
