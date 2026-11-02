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

--- Convert an API byte position to LSP UTF-16 code units (the protocol column).
--- Requests must send UTF-16; multibyte text before the cursor (CJK comments)
--- pulls byte and UTF-16 columns apart. The inverse of to_byte.
---@param bufnr integer
---@param row integer zero-based line
---@param col integer zero-based byte column
---@return integer character
function M.to_utf16(bufnr, row, col)
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''
  local units = 0
  local i = 1
  while i <= col and i <= #line do
    local byte = line:byte(i)
    if byte < 0x80 then
      i = i + 1
      units = units + 1
    elseif byte < 0xE0 then
      i = i + 2
      units = units + 1
    elseif byte < 0xF0 then
      i = i + 3
      units = units + 1
    else
      i = i + 4
      units = units + 2
    end
  end
  return units
end

--- Open an LSP Location in the current window. Done by hand because both
--- jump_to_location (deprecated) and show_document with focus build a tagstack
--- entry from <cword>, which throws E348 when no word is under the cursor.
---@param location table Location with uri and range
---@return boolean opened
function M.jump(location)
  if not location or not location.uri then
    return false
  end
  local bufnr = vim.uri_to_bufnr(location.uri)
  vim.bo[bufnr].buflisted = true
  vim.fn.bufload(bufnr)
  local win = vim.fn.win_findbuf(bufnr)[1] or vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, bufnr)
  vim.api.nvim_set_current_win(win)
  local row, col = M.to_byte(bufnr, location.range.start)
  vim.api.nvim_win_set_cursor(win, { row + 1, col })
  return true
end

return M
