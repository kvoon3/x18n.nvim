-- Status: float lists project, locales with progress, display locale.
local ctx = ...
require('x18n.status').show()

local function status_win()
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(w).relative ~= '' then
      local text = table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w), 0, -1, false), '\n')
      if text:find 'display locale' then
        return w
      end
    end
  end
end
assert(
  ctx.wait_for(function()
    return status_win() ~= nil
  end, 5000),
  'status float never opened'
)
local text = table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(status_win()), 0, -1, false), '\n')
assert(text:find('playground', 1, true), 'project name missing: ' .. text)
local progress_lines = {}
for _, line in ipairs(vim.split(text, '\n')) do
  if line:find '%d+/%d+ translated' then
    progress_lines[#progress_lines + 1] = line
  end
end
for _, code in ipairs { 'en', 'zh-CN', 'ja', 'fr' } do
  local found
  for _, line in ipairs(progress_lines) do
    if line:find(code, 1, true) then
      found = line
    end
  end
  assert(found, 'locale ' .. code .. ' progress line missing: ' .. text)
  local done, total = found:match '(%d+)/(%d+) translated'
  assert(done and total and done == total and tonumber(total) > 0, code .. ' lost a translation: ' .. found)
  assert(not found:find('missing', 1, true), code .. ' reports missing keys: ' .. found)
end
assert(text:find('source', 1, true), 'source locale marker missing: ' .. text)
-- Every fixture key is translated in every locale; missing counts appear when >0.
assert(text:find('display locale', 1, true), 'display locale missing: ' .. text)
assert(text:find('show mode conceal', 1, true), 'show mode missing: ' .. text)
local eol = require('x18n.decorations').locale_file_eol()
assert(text:find('locale-file EOL ' .. (eol and 'on' or 'off'), 1, true), 'locale-file EOL state missing: ' .. text)
print 'status ok'
