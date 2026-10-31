-- Smoke: server attaches, decorations render for t('app.title') and the missing key.
local ctx = ...
local marks = vim.api.nvim_buf_get_extmarks(ctx.buf, require('x18n.decorations').namespace(), 0, -1, { details = true })
assert(#marks >= 2, ('expected >=2 decorations, got %d'):format(#marks))
local texts = {}
for _, m in ipairs(marks) do
  texts[#texts + 1] = m[4].virt_text[1][1]
end
local joined = table.concat(texts, '\n')
assert(joined:find('Hello x18n', 1, true), 'no decoration for app.title: ' .. joined)
assert(joined:find('missing', 1, true), 'no missing-key decoration: ' .. joined)
print('smoke ok: ' .. #marks .. ' decorations')
