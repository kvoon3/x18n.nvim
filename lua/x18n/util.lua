local M = {}

--- Convert an LSP (UTF-16 code unit) position to API byte positions.
--- Locale values are frequently CJK, where UTF-16 columns and byte columns diverge.
---@param bufnr integer
---@param pos {line: integer, character: integer}
---@return integer row, integer col
function M.to_byte(bufnr, pos)
  local line = vim.api.nvim_buf_get_lines(bufnr, pos.line, pos.line + 1, false)[1] or ''
  --[[ vim.str_byteindex turns a UTF-16 index into a byte index; strict_indexing=false
    clamps end-of-line positions instead of erroring. ]]
  local ok, byte_col = pcall(vim.str_byteindex, line, 'utf-16', pos.character, false)
  if ok and type(byte_col) == 'number' then
    return pos.line, byte_col
  end
  return pos.line, pos.character
end

--- Open lines in a closable scratch float. Shared by status and explain.
---@param title string
---@param lines string[]
---@return integer winid, integer bufnr
function M.preview(title, lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
  vim.api.nvim_buf_set_name(bufnr, title)

  local width = 1
  for _, line in ipairs(lines) do
    width = math.max(width, vim.api.nvim_strwidth(line))
  end
  width = math.min(width + 2, math.floor(vim.o.columns * 0.8))
  local height = math.min(#lines, math.floor(vim.o.lines * 0.8))
  local winid = vim.api.nvim_open_win(bufnr, true, {
    relative = 'editor',
    title = ' ' .. title .. ' ',
    title_pos = 'center',
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = height,
    style = 'minimal',
    border = 'rounded',
  })
  vim.keymap.set('n', 'q', function() vim.api.nvim_win_close(winid, true) end, { buffer = bufnr, silent = true })
  return winid, bufnr
end

return M
