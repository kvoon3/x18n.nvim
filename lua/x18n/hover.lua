local M = {}

-- Render the x18n hover into aligned plain text. The kvoon3/x18n fork attaches
-- an `x18n` field to the hover response with the data pre-chewed; upstream
-- servers only ship the markdown, which this module also parses as a fallback.
-- The markdown shapes are fixed by the server, so the parsing stays
-- deliberately narrow.

--- Render the structured `x18n` hover value as aligned plain text. No markup:
--- the bundled markdown query conceals nothing, so markers would show raw.
---@param v table HoverValue from the server
---@return string[] lines
function M.from_value(v)
  local title = ('x18n %s'):format(v.key)
  if v.label and v.label ~= '' then
    title = title .. ' ' .. v.label
  end
  local out = { title }
  if #v.locales > 0 then
    out[#out + 1] = ''
    local rows = {}
    for _, l in ipairs(v.locales) do
      local suffix = l.source and ' (source)' or ''
      if l.changed and l.changed ~= '' then
        suffix = suffix .. ' · ' .. vim.trim(vim.split(l.changed, '·')[1])
      end
      if l.outdated then
        suffix = suffix .. ' · outdated'
      end
      local value = l.value == nil and '_missing_' or (l.value == '' and '_empty_' or l.value)
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
  if #v.threads > 0 then
    out[#out + 1] = ''
    for _, t in ipairs(v.threads) do
      out[#out + 1] = ('review %s: %s'):format(t.locale, t.state)
    end
  end
  out[#out + 1] = ''
  out[#out + 1] = ('%d usage%s'):format(v.usages, v.usages == 1 and '' or 's')
  return out
end

--- Cells of a markdown table row, or nil when the line is not one.
---@param line string
---@return string[]? cells
local function table_row(line)
  if not (line:byte(1) == ('|'):byte()) then
    return nil
  end
  local cells = {}
  for cell in line:gmatch '|([^|]*)' do
    cells[#cells + 1] = vim.trim(cell)
  end
  if #cells == 0 then
    return nil
  end
  return cells
end

--- The changed column arrives as "5 hours ago · 91767af · kvoon"; the revision
--- hash and the author only eat width, the relative time is the useful part.
---@param changed string
---@return string
local function shorten_changed(changed)
  local first = vim.split(changed, '·')[1]
  return first and vim.trim(first) or changed
end

--- Render parsed hover lines into an aligned table plus a clean footer.
---@param lines string[] Raw hover lines.
---@return string[] rendered
function M.format(lines)
  local out = {}
  local rows = {} -- {cells: string[]}[]
  local footer = nil
  for _, line in ipairs(lines) do
    local cells = table_row(line)
    if cells then
      --[[ The first table row is the empty header, the second the dashes; the
        data rows are everything after them. ]]
      if not line:find '---' and #cells >= 3 and cells[1] ~= '' then
        rows[#rows + 1] = cells
      end
    elseif line:match '^%*%*x18n%**' then
      --[[ Title line like **x18n** `app.title` -> "x18n app.title". ]]
      local key = line:match('`([^`]+)`')
      out[#out + 1] = 'x18n ' .. (key or line:gsub('[%*`]', ''))
    elseif line:match '^%d+ usage' then
      --[[ The command links are dead text in a scratch buffer; name the
        actions instead. Held back so the table lands above the footer. ]]
      footer = vim.trim(line:match '^(%d+ usage[^·]*)' or line)
    end
  end
  if #rows > 0 then
    out[#out + 1] = ''
    -- Column 1 is the locale, 2 the value, 3 the last-change time.
    local w = { 1, 2, 3 }
    for _, r in ipairs(rows) do
      for c = 1, 3 do
        local text = c == 3 and shorten_changed(r[c] or '') or (r[c] or '')
        w[c] = math.max(w[c], vim.fn.strdisplaywidth(text))
      end
    end
    for _, r in ipairs(rows) do
      local cols = {}
      for c = 1, 3 do
        local text = c == 3 and shorten_changed(r[c] or '') or (r[c] or '')
        local gap = string.rep(' ', math.max(1, w[c] - vim.fn.strdisplaywidth(text) + (c < 3 and 1 or 0)))
        cols[#cols + 1] = text .. gap
      end
      out[#out + 1] = table.concat(cols, ''):gsub('%s+$', '')
    end
  end
  if footer then
    out[#out + 1] = ''
    out[#out + 1] = footer
    out[#out + 1] = 'actions: Open in UI, Copy translate prompt, Translate with agent (via the x18n UI or :X18nOpenUi)'
  end
  return out
end

return M
