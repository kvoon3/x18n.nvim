local targets = {}
for _, target in ipairs(arg) do
  if vim.fn.isdirectory(target) == 1 then
    vim.list_extend(targets, vim.fn.glob(target .. '/**/*.lua', false, true))
  else
    targets[#targets + 1] = target
  end
end
table.sort(targets)

local function allowed(text)
  return text:sub(1, 3) == '---' or text:match '^%-%-%[=*%[' ~= nil
end

local failures = 0
for _, path in ipairs(targets) do
  local source = table.concat(vim.fn.readfile(path), '\n')
  local parser = vim.treesitter.get_string_parser(source, 'lua')
  local tree = parser:parse()[1]
  local query = vim.treesitter.query.parse('lua', '(comment) @comment')
  for _, node in query:iter_captures(tree:root(), source, 0, -1) do
    local text = vim.treesitter.get_node_text(node, source)
    if not allowed(text) then
      local row, col = node:start()
      print(('%s:%d:%d: comment must be a LuaLS doc (---) or a long comment (--[[ ]])'):format(path, row + 1, col + 1))
      failures = failures + 1
    end
  end
end

if failures > 0 then
  print(('%d forbidden comment(s)'):format(failures))
  os.exit(1)
end
