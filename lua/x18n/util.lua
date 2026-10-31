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

--- Convert a byte column to an LSP (UTF-16 code unit) character offset.
---@param bufnr integer
---@param row integer
---@param col integer
---@return integer
function M.to_utf16(bufnr, row, col)
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''
  local ok, _, utf16 = pcall(vim.str_utfindex, line, 'utf-16', col)
  if ok and type(utf16) == 'number' then
    return utf16
  end
  return col
end

return M
