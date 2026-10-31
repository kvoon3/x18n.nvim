-- Completion: the server answers textDocument/completion inside a t() key
-- slot with the project's keys, each carrying the source value as detail and
-- a textEdit spanning the slot. This is what blink.cmp renders through its
-- lsp source.
local ctx = ...

local function cursor_onto(buf, pattern)
  for i, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local col = l:find(pattern, 1, false)
    if col then
      vim.api.nvim_win_set_cursor(0, { i, col + 1 })
      return i - 1, col
    end
  end
  error('no line matches ' .. pattern)
end

local row, col = cursor_onto(ctx.buf, 'app%.title')
local client = vim.lsp.get_clients({ name = 'x18n' })[1]
assert(client, 'no x18n client')

local items = nil
client:request('textDocument/completion', {
  textDocument = { uri = vim.uri_from_bufnr(ctx.buf) },
  position = { line = row, character = col },
}, function(err, result)
  assert(not err, err and err.message)
  items = result or {}
end)
assert(ctx.wait_for(function() return items ~= nil end, 5000), 'completion never answered')

local by_label = {}
for _, item in ipairs(items) do
  by_label[item.label] = item
end
assert(by_label['app.title'], 'app.title not offered; labels: ' .. vim.tbl_keys(by_label)[1] and table.concat(vim.tbl_keys(by_label), ','))
assert(by_label['app.title'].detail == 'Hello x18n', 'detail not the source value: ' .. tostring(by_label['app.title'].detail))
assert(by_label['app.description'], 'app.description not offered')
assert(by_label['app.title'].textEdit, 'no textEdit replacing the key slot')
local edit = by_label['app.title'].textEdit
assert(edit.range.start.line == row and edit.range['end'].line == row, 'textEdit not on the slot line')
print('completion ok: ' .. #items .. ' items')
