local M = {}

local util = require 'x18n.util'

local ns = vim.api.nvim_create_namespace 'x18n_hover'
local cfg = {}
local float = nil

local function define_highlights()
  vim.api.nvim_set_hl(0, 'X18nHoverSource', { default = true, link = 'Identifier' })
  vim.api.nvim_set_hl(0, 'X18nHoverLocale', { default = true, link = 'Comment' })
  vim.api.nvim_set_hl(0, 'X18nHoverValue', { default = true, link = 'Normal' })
  vim.api.nvim_set_hl(0, 'X18nHoverCurrent', { default = true, bold = true })
  vim.api.nvim_set_hl(0, 'X18nHoverMissing', { default = true, link = 'DiagnosticError' })
end

local function close()
  if float and vim.api.nvim_win_is_valid(float) then
    pcall(vim.api.nvim_win_close, float, true)
  end
  float = nil
end

local function fit(text, max_width)
  if vim.fn.strdisplaywidth(text) <= max_width then
    return text
  end
  local out = ''
  for _, char in ipairs(vim.fn.split(text, '\\zs')) do
    if vim.fn.strdisplaywidth(out .. char .. '…') > max_width then
      break
    end
    out = out .. char
  end
  return out .. '…'
end

--- Split one markdown table row into cells, keeping escaped pipes inside a cell.
---@param line string
---@return string[]
local function split_row(line)
  local body = line:gsub('^|', ''):gsub('|%s*$', '')
  local cells, part = {}, {}
  local i = 1
  while i <= #body do
    local char = body:sub(i, i)
    if char == '\\' and body:sub(i + 1, i + 1) == '|' then
      part[#part + 1] = '|'
      i = i + 2
    elseif char == '|' then
      cells[#cells + 1] = vim.trim(table.concat(part))
      part = {}
      i = i + 1
    else
      part[#part + 1] = char
      i = i + 1
    end
  end
  cells[#cells + 1] = vim.trim(table.concat(part))
  return cells
end

--- Turn the language server's markdown locale table into rows.
--- Rows are `| 🇺🇸 en | Task Board |` (the third cell, a change date, is ignored).
---@param markdown string
---@return {label: string, locale: string, value: string?}[]
local function parse_markdown(markdown)
  local rows = {}
  for line in vim.gsplit(markdown, '\n', { plain = true }) do
    local trimmed = vim.trim(line)
    if trimmed:sub(1, 1) == '|' and not trimmed:match '^|%s*%-' then
      local cells = split_row(trimmed)
      local label = cells[1] or ''
      local locale = label:match '([%w%-_]+)%s*$'
      local value = cells[2]
      if locale and value then
        if value == '_missing_' then
          value = nil
        elseif value == '_empty_' then
          value = ''
        end
        rows[#rows + 1] = { label = label, locale = locale, value = value }
      end
    end
  end
  return rows
end

---@param markdown string
---@return string[]
local function fallback_lines(markdown)
  local lines = {}
  for line in vim.gsplit(markdown, '\n', { plain = true }) do
    --[[ The server appends VS Code `command:` links; they are dead ends in a
      terminal float, and the `**x18n** key` header duplicates the source block. ]]
    if not line:find('command:x18n', 1, true) and not line:match '^%*%*x18n%*%*' then
      lines[#lines + 1] = line
    end
  end
  while #lines > 0 and vim.trim(lines[#lines]) == '' do
    lines[#lines] = nil
  end
  return lines
end

local function markdown_of(result)
  local contents = result and result.contents
  if type(contents) == 'string' then
    return contents
  end
  if type(contents) == 'table' then
    if type(contents.value) == 'string' then
      return contents.value
    end
    local parts = {}
    for _, item in ipairs(contents) do
      if type(item) == 'string' then
        parts[#parts + 1] = item
      elseif type(item) == 'table' and type(item.value) == 'string' then
        parts[#parts + 1] = item.value
      end
    end
    if #parts > 0 then
      return table.concat(parts, '\n\n')
    end
  end
end

local function pad(text, width)
  return text .. string.rep(' ', math.max(0, width - vim.fn.strdisplaywidth(text)))
end

--- Render the hover panel: the concealed source call on top, one row per locale.
---@param source string[]
---@param rows {label: string, locale: string, value: string?}[]
---@param markdown string?
---@param current string
local function show(source, rows, markdown, current)
  close()

  local max_width = math.max(24, math.min(72, vim.o.columns - 4))
  local lines = {}
  local marks = {} -- per line: list of { start, stop, group }

  local function add(text, highlights)
    local index = #lines + 1
    lines[index] = text
    marks[index] = highlights or {}
  end

  for _, line in ipairs(source) do
    add(line, { { 0, #line, 'X18nHoverSource' } })
  end
  add ''

  if #rows == 0 then
    if markdown then
      for _, line in ipairs(fallback_lines(markdown)) do
        add(line, { { 0, #line, 'X18nHoverLocale' } })
      end
    else
      add('no translations found', { { 0, 18, 'X18nHoverLocale' } })
    end
  else
    local label_width = 0
    for _, row in ipairs(rows) do
      label_width = math.max(label_width, vim.fn.strdisplaywidth(row.label))
    end
    for _, row in ipairs(rows) do
      local label = pad(row.label, label_width)
      local value = row.value
      local group = 'X18nHoverValue'
      if value == nil then
        value = '(missing)'
        group = 'X18nHoverMissing'
      elseif value == '' then
        value = '(empty)'
        group = 'X18nHoverMissing'
      elseif row.locale == current then
        group = 'X18nHoverCurrent'
      end
      local line = label .. '  ' .. value
      add(line, {
        { 0, #label, 'X18nHoverLocale' },
        { #label + 2, #line, group },
      })
    end
  end

  for i, line in ipairs(lines) do
    lines[i] = fit(line, max_width)
    for _, mark in ipairs(marks[i]) do
      mark[2] = math.min(mark[2], #lines[i])
    end
  end

  local width = 24
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  width = math.min(width + 2, max_width + 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = 'wipe'
  for row, line_marks in ipairs(marks) do
    for _, mark in ipairs(line_marks) do
      if mark[1] < mark[2] then
        vim.api.nvim_buf_set_extmark(buf, ns, row - 1, mark[1], { end_col = mark[2], hl_group = mark[3] })
      end
    end
  end

  local ok, win = pcall(vim.api.nvim_open_win, buf, false, {
    relative = 'cursor',
    row = 1,
    col = 0,
    width = width,
    height = #lines,
    style = 'minimal',
    border = 'rounded',
    title = ' x18n ',
  })
  if ok then
    float = win
  end
end

--- Hover in an x18n buffer: over a replaced call, show its source and every
--- locale; anywhere else, defer to the regular LSP hover.
function M.hover()
  local bufnr = vim.api.nvim_get_current_buf()
  local pos = vim.api.nvim_win_get_cursor(0)
  local item = require('x18n.decorations').item_at(bufnr, pos[1] - 1, pos[2])
  if not item then
    vim.lsp.buf.hover()
    return
  end

  local client = require('x18n').client(bufnr)
  if not client then
    return
  end

  close()
  local character = util.to_utf16(bufnr, item.krow, item.kcol)
  client:request('textDocument/hover', {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
    position = { line = item.krow, character = character },
  }, function(err, result)
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(bufnr) or vim.api.nvim_get_current_buf() ~= bufnr then
        return
      end
      local source = require('x18n.decorations').source(bufnr, item)
      local markdown = markdown_of(result)
      require('x18n').debug(('hover key=%s err=%s markdown=%s'):format(item.key, tostring(err), tostring(markdown ~= nil)))
      if err then
        markdown = nil
      end
      show(source, markdown and parse_markdown(markdown) or {}, markdown, item.locale)
    end)
  end, bufnr)
end

---@param opts {enabled: boolean, keymap: string|false}
function M.setup(opts)
  cfg = opts
  define_highlights()

  local group = vim.api.nvim_create_augroup('x18n_hover', { clear = true })
  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI', 'InsertEnter', 'BufLeave', 'WinLeave', 'WinScrolled' }, {
    group = group,
    callback = close,
  })

  local function attach(bufnr)
    if cfg.keymap then
      vim.keymap.set('n', cfg.keymap, M.hover, { buffer = bufnr, desc = 'x18n: show source and translations' })
    end
  end

  vim.api.nvim_create_autocmd('LspAttach', {
    group = group,
    callback = function(a)
      local client = vim.lsp.get_client_by_id(a.data.client_id)
      if client and client.name == 'x18n' then
        attach(a.buf)
      end
    end,
  })

  for _, client in ipairs(vim.lsp.get_clients({ name = 'x18n' })) do
    for bufnr in pairs(client.attached_buffers or {}) do
      attach(bufnr)
    end
  end
end

return M
