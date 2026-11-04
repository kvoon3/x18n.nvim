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
assert(
  client.server_capabilities.completionProvider.resolveProvider == true,
  'server does not advertise resolveProvider'
)

local items = nil
client:request('textDocument/completion', {
  textDocument = { uri = vim.uri_from_bufnr(ctx.buf) },
  position = { line = row, character = col },
}, function(err, result)
  assert(not err, err and err.message)
  items = result or {}
end)
assert(
  ctx.wait_for(function()
    return items ~= nil
  end, 5000),
  'completion never answered'
)

local by_label = {}
for _, item in ipairs(items) do
  by_label[item.label] = item
end
assert(
  by_label['app.title'],
  'app.title not offered; labels: ' .. vim.tbl_keys(by_label)[1] and table.concat(vim.tbl_keys(by_label), ',')
)
assert(
  by_label['app.title'].detail == 'Hello x18n',
  'detail not the source value: ' .. tostring(by_label['app.title'].detail)
)
assert(by_label['app.description'], 'app.description not offered')
assert(by_label['app.title'].textEdit, 'no textEdit replacing the key slot')
local edit = by_label['app.title'].textEdit
assert(edit.range.start.line == row and edit.range['end'].line == row, 'textEdit not on the slot line')

-- The full key survives in data, so resolve can build the all-locale docs.
local title = by_label['app.title']
assert(title.data and title.data.key == 'app.title', 'item data lost the full key')
local function canon(path)
  return vim.fn.fnamemodify(path, ':p'):gsub('/+$', '')
end
assert(title.data.project == 'playground', 'item data lost the project name: ' .. tostring(title.data.project))
assert(
  canon(title.data.root) == canon(ctx.playground),
  'item data lost the project root: ' .. tostring(title.data.root) .. ' vs ' .. ctx.playground
)
local resolved, resolve_err
client:request('completionItem/resolve', title, function(err, result)
  resolve_err, resolved = err, result
end)
assert(
  ctx.wait_for(function()
    return resolved ~= nil or resolve_err ~= nil
  end, 5000),
  'resolve never answered'
)
assert(not resolve_err, resolve_err and resolve_err.message)
assert(resolved.documentation and resolved.documentation.kind == 'markdown', 'resolve returned no markdown docs')
local doc = resolved.documentation.value
for _, value in ipairs { 'Hello x18n', '你好 x18n', 'こんにちは x18n', 'Bonjour x18n' } do
  assert(doc:find(value, 1, true), 'docs lost ' .. value .. ': ' .. doc)
end
for _, code in ipairs { '**en**', '**zh-CN**', '**ja**', '**fr**' } do
  assert(doc:find(code, 1, true), 'docs lost locale ' .. code .. ': ' .. doc)
end

-- The description key documents its own translated values too.
local description = by_label['app.description']
assert(description and description.data.key == 'app.description', 'app.description lost its full key')
local description_resolved
client:request('completionItem/resolve', description, function(_, result)
  description_resolved = result
end)
assert(
  ctx.wait_for(function()
    return description_resolved ~= nil
  end, 5000),
  'description resolve never answered'
)
local description_doc = description_resolved.documentation.value
for _, value in ipairs {
  'A playground for x18n.nvim',
  'x18n.nvim の実験場',
  'x18n.nvim 的试验场',
  'Un terrain de jeu pour x18n.nvim',
} do
  assert(description_doc:find(value, 1, true), 'description docs lost ' .. value .. ': ' .. description_doc)
end

-- Resolve reads data.key, not the label a namespaced project strips.
local stripped = vim.deepcopy(title)
stripped.label = 'title'
stripped.documentation = nil
local stripped_resolved
client:request('completionItem/resolve', stripped, function(_, result)
  stripped_resolved = result
end)
assert(
  ctx.wait_for(function()
    return stripped_resolved ~= nil
  end, 5000),
  'stripped-label resolve never answered'
)
assert(
  stripped_resolved.documentation.value:find('Hello x18n', 1, true),
  'resolve used the stripped label: ' .. stripped_resolved.documentation.value
)

-- A stale item names the missing key instead of pretending every locale is untranslated.
local stale = vim.deepcopy(title)
stale.data.key = 'app.removed'
stale.documentation = nil
local stale_resolved
client:request('completionItem/resolve', stale, function(_, result)
  stale_resolved = result
end)
assert(
  ctx.wait_for(function()
    return stale_resolved ~= nil
  end, 5000),
  'stale resolve never answered'
)
assert(
  stale_resolved.documentation.value:find('key no longer exists', 1, true),
  'stale key docs: ' .. stale_resolved.documentation.value
)

-- A key present only in en resolves with _missing_ for the other locales.
local set_err, set_done = nil, false
client:request('workspace/executeCommand', {
  command = 'x18n.set',
  arguments = {
    {
      project = title.data.project,
      key = 'app.only_en',
      locale = 'en',
      value = 'Only EN',
    },
  },
}, function(err)
  set_err, set_done = err, true
end)
assert(
  ctx.wait_for(function()
    return set_done
  end, 5000),
  'x18n.set never answered'
)
assert(not set_err, set_err and set_err.message)
local only
assert(
  ctx.wait_for(function()
    local got, found = false, nil
    client:request('textDocument/completion', {
      textDocument = { uri = vim.uri_from_bufnr(ctx.buf) },
      position = { line = row, character = col },
    }, function(err, result)
      if not err then
        for _, item in ipairs(result or {}) do
          if item.label == 'app.only_en' then
            found = item
          end
        end
      end
      got = true
    end)
    vim.wait(1000, function()
      return got
    end, 25)
    only = found
    return found ~= nil
  end, 8000),
  'new en-only key never appeared in completion'
)
local only_resolved
client:request('completionItem/resolve', only, function(_, result)
  only_resolved = result
end)
assert(
  ctx.wait_for(function()
    return only_resolved ~= nil
  end, 5000),
  'en-only resolve never answered'
)
local only_doc = only_resolved.documentation.value
assert(only_doc:find('Only EN', 1, true), 'en value missing from en-only docs: ' .. only_doc)
assert(only_doc:find('_missing_', 1, true), 'missing marker absent from en-only docs: ' .. only_doc)
print('completion ok: ' .. #items .. ' items')
