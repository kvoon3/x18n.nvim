local M = {}

local last_buf = nil -- preview scratch buffer of the previous float

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

--- Open lines in a closable scratch float. Shared by status and explain.
--- `opts.hover` styles it like an LSP hover instead: markdown filetype for
--- treesitter rendering, and the float closes when the cursor moves in the
--- window that spawned it (focusing the float or `q` still works). The
--- stock open_floating_preview dies on BufLeave bookkeeping under `nvim -l`,
--- so the close logic is small and ours.
---@param title string
---@param lines string[]
---@param opts { hover: boolean? }?
---@return integer winid, integer bufnr
function M.preview(title, lines, opts)
  opts = opts or {}
  --[[ Wipe the previous float's buffer: it survives `q` (only the window closes),
    and naming a fresh buffer the same would throw E95. ]]
  if last_buf ~= nil and vim.api.nvim_buf_is_valid(last_buf) and #vim.fn.win_findbuf(last_buf) == 0 then
    vim.api.nvim_buf_delete(last_buf, { force = true })
  end
  local parent_win = vim.api.nvim_get_current_win()
  local parent_buf = vim.api.nvim_get_current_buf()
  local bufnr = vim.api.nvim_create_buf(false, true)
  last_buf = bufnr
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
  pcall(vim.api.nvim_buf_set_name, bufnr, title)

  local width = 1
  for _, line in ipairs(lines) do
    width = math.max(width, vim.api.nvim_strwidth(line))
  end
  width = math.min(width + 2, math.floor(vim.o.columns * 0.8))
  local height = math.min(#lines, math.floor(vim.o.lines * 0.8))
  --[[ A hover float must not take the cursor: movement anywhere closes it.
    Status and explain keep the cursor (enter = true) since they are read at
    length and `q` dismisses them. ]]
  local winid = vim.api.nvim_open_win(bufnr, not opts.hover, {
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
  --[[ Hover mode only changes closing: the float dismisses on cursor movement
    in the window that spawned it, like a native hover. No markdown styling:
    the bundled markdown query conceals nothing, so markup would render raw. ]]
  if opts.hover then
    local group = vim.api.nvim_create_augroup('x18n_hover_close', { clear = true })
    vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
      group = group,
      buffer = parent_buf,
      callback = function()
        if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_get_current_win() ~= winid then
          vim.api.nvim_win_close(winid, true)
        end
      end,
    })
    vim.api.nvim_create_autocmd('WinClosed', {
      group = group,
      pattern = tostring(winid),
      callback = function()
        vim.api.nvim_del_augroup_by_name('x18n_hover_close')
      end,
    })
  end
  return winid, bufnr
end

return M
