local M = {}

local util = require 'x18n.util'

local ns = vim.api.nvim_create_namespace 'x18n_decoration'
local cfg = {}
local pending = {} -- bufnr -> uv timer
local retries = {} -- bufnr -> warm-up poll count
local rendered = {} -- bufnr -> { locale, items }
local original = {} -- win -> options we changed, by original value
local editing = {} -- bufnr -> true between InsertEnter and InsertLeave

local function define_highlights()
  vim.api.nvim_set_hl(0, 'X18nValue', { default = true, link = 'Comment' })
  vim.api.nvim_set_hl(0, 'X18nValueMissing', { default = true, link = 'DiagnosticError' })
end

local function hl_for(state)
  if state == 'ok' then
    return 'X18nValue'
  end
  if state == 'missing' then
    return 'X18nValueMissing'
  end
  return 'WarningMsg'
end

local function clear(bufnr)
  rendered[bufnr] = nil
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  end
end

--[[ Replace mode hides the source range, so extmark conceal must be active.
  conceallevel is window-local: two windows can show the same buffer, and a
  later window opened on it needs the same treatment.

  'wrap' is disabled as well: Neovim computes the wrap points of a line with
  inline virtual text from the *unconcealed* columns, so a long decorated line
  would push its tail (the trailing comma) onto a continuation row. nowrap
  keeps the replacement on one line; insert mode restores wrapping for editing. ]]
local function apply_window(win)
  if not cfg.conceal then
    return
  end
  local saved = original[win]
  if not saved then
    saved = {}
    original[win] = saved
  end
  if vim.wo[win].conceallevel < 2 then
    if saved.conceallevel == nil then
      saved.conceallevel = vim.wo[win].conceallevel
    end
    vim.wo[win].conceallevel = 2
  end
  if vim.wo[win].concealcursor == '' then
    if saved.concealcursor == nil then
      saved.concealcursor = ''
    end
    vim.wo[win].concealcursor = 'nvc'
  end
  if cfg.wrap == false and vim.wo[win].wrap then
    saved.wrap = saved.wrap or true
    vim.wo[win].wrap = false
  end
end

local function restore_window(win)
  local saved = original[win]
  if not saved then
    return
  end
  original[win] = nil
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  if saved.conceallevel ~= nil and vim.wo[win].conceallevel == 2 then
    vim.wo[win].conceallevel = saved.conceallevel
  end
  if saved.concealcursor ~= nil and vim.wo[win].concealcursor == 'nvc' then
    vim.wo[win].concealcursor = saved.concealcursor
  end
  if saved.wrap and not vim.wo[win].wrap then
    vim.wo[win].wrap = true
  end
end

local function restore_buffer(bufnr)
  for win in pairs(original) do
    if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_buf(win) == bufnr then
      restore_window(win)
    end
  end
end

local function ensure_conceal(bufnr)
  local state = rendered[bufnr]
  if cfg.mode ~= 'replace' or not cfg.conceal or editing[bufnr] or not state or #state.items == 0 then
    return
  end
  for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
    apply_window(win)
  end
end

---@param bufnr integer
---@param d {key: string, value: string?, state: string, range: table, expression: table?}
---@param locale string
---@param items table[]
local function place(bufnr, d, locale, items)
  local range = d.range or d.expression
  if not range then
    return
  end
  local expr = d.expression or range
  local srow, scol = util.to_byte(bufnr, expr.start)
  local erow, ecol = util.to_byte(bufnr, expr['end'])
  local krow, kcol = util.to_byte(bufnr, range.start)
  local item = {
    key = d.key,
    value = d.value,
    state = d.state,
    locale = locale,
    srow = srow,
    scol = scol,
    erow = erow,
    ecol = ecol,
    krow = krow,
    kcol = kcol,
    replaced = false,
  }
  items[#items + 1] = item

  local hl = hl_for(d.state)
  --[[ A translated call is replaced wholesale: conceal the expression and
    insert the translation as virtual text. 'inline' shifts the rest of the
    line right; 'overlay' would draw the following source on top of the
    translation. Multi-line expressions are left readable and annotated. ]]
  if cfg.mode == 'replace' and d.expression and d.state == 'ok' and d.value and d.value ~= '' and srow == erow then
    item.replaced = true
    vim.api.nvim_buf_set_extmark(bufnr, ns, srow, scol, {
      end_row = erow,
      end_col = ecol,
      conceal = '',
      virt_text = { { d.value, hl } },
      virt_text_pos = 'inline',
      hl_mode = 'combine',
      priority = 120,
    })
    return
  end

  local text
  if d.state == 'ok' and d.value and d.value ~= '' then
    text = ' → ' .. d.value
  elseif d.state == 'missing' then
    text = ' → missing'
  else
    text = ' → ' .. (d.state or '?')
  end
  vim.api.nvim_buf_set_extmark(bufnr, ns, erow, ecol, {
    virt_text = { { text, hl } },
    virt_text_pos = cfg.mode == 'eol' and 'eol' or 'inline',
    hl_mode = 'combine',
  })
end

local function render(bufnr, result)
  if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end
  --[[ A request that lands while the user edits must not draw translations
    over the source: InsertLeave triggers a fresh refresh. ]]
  if editing[bufnr] then
    return
  end
  clear(bufnr)
  local locale = (result and result.locale) or ''
  local items = {}
  for _, d in ipairs(result and result.decorations or {}) do
    place(bufnr, d, locale, items)
  end
  rendered[bufnr] = { locale = locale, items = items }
  if #items == 0 then
    restore_buffer(bufnr)
  else
    ensure_conceal(bufnr)
  end
end

--- Issue the decoration request for (bufnr, client) with debounce and warm-up retry.
--- The client is passed in: during LspAttach the buffer is not yet in the client's
--- attached list, so a get_clients({ bufnr }) lookup races and silently drops.
function M.request(bufnr, client)
  local timer = pending[bufnr]
  if timer then
    timer:stop()
    timer:close()
  end
  pending[bufnr] = vim.defer_fn(function()
    pending[bufnr] = nil
    if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) or client:is_stopped() then
      return
    end
    client:request('x18n/decorations', { uri = vim.uri_from_bufnr(bufnr) }, function(err, result)
      require('x18n').debug(
        ('decorations buf=%d err=%s locale=%s n=%s'):format(
          bufnr,
          tostring(err),
          tostring(result and result.locale),
          tostring(result and result.decorations and #result.decorations)
        )
      )
      if err then
        return
      end
      --[[ Right after LspAttach the server is still loading the project and answers
        with an empty locale; poll until the real (possibly also empty) payload lands. ]]
      if (result and result.locale or '') == '' and (retries[bufnr] or 0) < 5 then
        retries[bufnr] = (retries[bufnr] or 0) + 1
        vim.defer_fn(function()
          if pending[bufnr] == nil then
            M.request(bufnr, client)
          end
        end, 1000)
        return
      end
      retries[bufnr] = nil
      vim.schedule(function()
        render(bufnr, result)
      end)
    end)
  end, cfg.debounce_ms)
end

function M.refresh(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  local client = vim.lsp.get_clients({ bufnr = bufnr, name = 'x18n' })[1]
  if not client then
    return
  end
  M.request(bufnr, client)
end

function M.refresh_attached()
  for _, client in ipairs(vim.lsp.get_clients({ name = 'x18n' })) do
    for bufnr in pairs(client.attached_buffers or {}) do
      M.refresh(bufnr)
    end
  end
end

--- The translated usage under a buffer position, if its source is concealed.
---@param bufnr integer
---@param row integer 0-indexed
---@param col integer 0-indexed byte column
---@return table?
function M.item_at(bufnr, row, col)
  local state = rendered[bufnr]
  if not state then
    return nil
  end
  for _, item in ipairs(state.items) do
    if item.replaced and row == item.srow and row == item.erow and col >= item.scol and col < item.ecol then
      return item
    end
  end
  return nil
end

--- The hidden source lines of an item, for the hover panel.
---@param bufnr integer
---@param item table
---@return string[]
function M.source(bufnr, item)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return {}
  end
  local ok, lines = pcall(vim.api.nvim_buf_get_text, bufnr, item.srow, item.scol, item.erow, item.ecol, {})
  return ok and lines or {}
end

--- Exposed for tests.
function M.namespace()
  return ns
end

---@param opts {mode: string, conceal: boolean, wrap: boolean, debounce_ms: integer}
function M.setup(opts)
  cfg = opts
  define_highlights()

  local group = vim.api.nvim_create_augroup('x18n_decoration', { clear = true })
  local aug = vim.api.nvim_create_autocmd
  aug('LspAttach', {
    group = group,
    callback = function(a)
      local client = vim.lsp.get_client_by_id(a.data.client_id)
      if client and client.name == 'x18n' then
        M.request(a.buf, client)
      end
    end,
  })
  aug('LspDetach', {
    group = group,
    callback = function(a)
      editing[a.buf] = nil
      local timer = pending[a.buf]
      if timer then
        timer:stop()
        timer:close()
        pending[a.buf] = nil
      end
      retries[a.buf] = nil
      clear(a.buf)
      restore_buffer(a.buf)
    end,
  })
  aug('BufWinEnter', { group = group, callback = function(a) ensure_conceal(a.buf) end })
  --[[ Editing a replaced call needs the real source, not the translation drawn
    over it: drop the decorations on InsertEnter and let InsertLeave refresh. ]]
  aug('InsertEnter', {
    group = group,
    callback = function(a)
      editing[a.buf] = true
      clear(a.buf)
      restore_buffer(a.buf)
    end,
  })
  aug('BufWinLeave', {
    group = group,
    callback = function()
      --[[ The window is about to show another buffer; if that one is decorated
        too, BufWinEnter re-applies the options. ]]
      local win = vim.api.nvim_get_current_win()
      if vim.api.nvim_win_is_valid(win) then
        restore_window(win)
      end
    end,
  })
  aug('WinClosed', {
    group = group,
    callback = function(a)
      original[tonumber(a.match)] = nil
    end,
  })
  aug('BufWritePost', { group = group, callback = function(a) M.refresh(a.buf) end })
  aug('TextChanged', { group = group, callback = function(a) M.refresh(a.buf) end })
  aug('InsertLeave', {
    group = group,
    callback = function(a)
      editing[a.buf] = nil
      M.refresh(a.buf)
    end,
  })
  aug('ColorScheme', { group = group, callback = define_highlights })
end

return M
