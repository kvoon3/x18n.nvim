local M = {}

local util = require 'x18n.util'

local ns = vim.api.nvim_create_namespace 'x18n_decoration'
local cfg = {}
local enabled = true
local pending = {} -- bufnr -> uv timer
local retries = {} -- bufnr -> warm-up poll count
local locale_files = {} -- bufnr -> true once fileKeys proved it is a locale file
local plain_files = {} -- bufnr -> true once a warm server proved it holds no keys
local bumped_conceal = {} -- winid -> the conceallevel we found before raising it to 2

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
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  end
end

--- Buffers the client is attached to. `vim.lsp.get_buffers_by_client_id` is
--- deprecated on 0.12; the attached-buffers lookup is its replacement.
---@param client vim.lsp.Client
---@return integer[]
local function buffers_of(client)
  local out = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.lsp.buf_is_attached(bufnr, client.id) then
      out[#out + 1] = bufnr
    end
  end
  return out
end

--- Conceal needs 'conceallevel' >= 2 in every window showing the buffer. Only
--- windows we raise ourselves are remembered, so the toggle can put them back.
local function ensure_conceallevel(bufnr)
  for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
    if vim.wo[win].conceallevel < 2 then
      if bumped_conceal[win] == nil then
        bumped_conceal[win] = vim.wo[win].conceallevel
      end
      vim.wo[win].conceallevel = 2
    end
  end
end

--- Put the conceallevel of every window we raised back to what it was.
local function restore_conceallevel()
  for win, level in pairs(bumped_conceal) do
    if vim.api.nvim_win_is_valid(win) then
      vim.wo[win].conceallevel = level
    end
  end
  bumped_conceal = {}
end

--- Widen the conceal range over the quote characters around the key literal,
--- so `t('app.title')` reads `t(Hello)` and not `t('Hello')`. The server range
--- is half-open [s_col, e_col); a quote just before it and just after it means
--- quotes are not part of the range.
---@return integer s_line, integer s_col, integer e_line, integer e_col
local function quoted_range(bufnr, range)
  local s_line, s_col = util.to_byte(bufnr, range.start)
  local e_line, e_col = util.to_byte(bufnr, range['end'])
  if s_line ~= e_line then
    return s_line, s_col, e_line, e_col
  end
  local line = vim.api.nvim_buf_get_lines(bufnr, s_line, s_line + 1, false)[1] or ''
  --[[ Byte columns are 0-based, Lua sub is 1-based: the char before the range
    start is 1-based s_col, the char at the exclusive end is 1-based e_col + 1. ]]
  local before = line:sub(s_col, s_col)
  local after = line:sub(e_col + 1, e_col + 1)
  if before:match "['\"`]" and after:match "['\"`]" then
    s_col = s_col - 1
    e_col = e_col + 1
  end
  return s_line, s_col, e_line, e_col
end

--- Toggle decorations for every attached buffer, clearing them when off.
---@return boolean the new state
function M.toggle()
  enabled = not enabled
  for _, client in ipairs(vim.lsp.get_clients({ name = 'x18n' })) do
    for _, bufnr in ipairs(buffers_of(client)) do
      if enabled then
        M.request(bufnr, client)
      else
        clear(bufnr)
      end
    end
  end
  if not enabled then
    restore_conceallevel()
  end
  return enabled
end

local function render(bufnr, result)
  if not enabled then
    return
  end
  if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end
  clear(bufnr)
  local conceal = cfg.mode == 'conceal'
  if conceal then
    ensure_conceallevel(bufnr)
  end
  for _, d in ipairs(result and result.decorations or {}) do
    --[[ Conceal replaces the key literal with its value, i18n.nvim's
      translation_conceal. Missing and dynamic keys keep the arrow form: hiding
      the key would leave nothing to work from. ]]
    if conceal and d.state == 'ok' and d.value and d.value ~= '' and d.range then
      local s_line, s_col, e_line, e_col = quoted_range(bufnr, d.range)
      vim.api.nvim_buf_set_extmark(bufnr, ns, s_line, s_col, {
        end_line = e_line,
        end_col = e_col,
        --[[ An empty cchar hides the range completely; any printable char
          (a space included) leaves a visible gap before the closing paren. ]]
        conceal = '',
        virt_text = { { d.value, hl_for 'ok' } },
        virt_text_pos = 'inline',
        hl_mode = 'combine',
      })
    else
      local line, col = util.to_byte(bufnr, d.expression['end'])
      local text = (d.value and d.value ~= '') and (' → ' .. d.value) or (' → ' .. (d.state or 'missing'))
      vim.api.nvim_buf_set_extmark(bufnr, ns, line, col, {
        virt_text = { { text, hl_for(d.state) } },
        virt_text_pos = cfg.mode == 'eol' and 'eol' or 'inline',
        hl_mode = 'combine',
      })
    end
  end
end

--- Locale files get no inline decorations from the server; x18n/fileKeys gives
--- their keys, so park the display-locale value at the end of each key's line.
local function render_locale_file(bufnr, result)
  if not enabled then
    return
  end
  if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end
  clear(bufnr)
  for _, k in ipairs(result and result.keys or {}) do
    local line = util.to_byte(bufnr, k.range.start)
    local text = k.value and (' = ' .. k.value) or ' = missing'
    vim.api.nvim_buf_set_extmark(bufnr, ns, line, 0, {
      virt_text = { { text, hl_for(k.value and 'ok' or 'missing') } },
      virt_text_pos = 'eol',
      hl_mode = 'combine',
    })
  end
end

--- Ask the server for the keys of a file. Calls back with the key list when the
--- file holds locale definitions, and with nil when it does not (a code file, or
--- the server still indexing). Without a callback it renders a known locale file.
---@param bufnr integer
---@param client vim.lsp.Client
---@param on_result fun(keys: table[]?)? nil for the plain render path
local function request_file_keys(bufnr, client, on_result)
  client:request('x18n/fileKeys', { uri = vim.uri_from_bufnr(bufnr) }, function(err, result)
    require('x18n').debug(
      ('fileKeys buf=%d err=%s keys=%s'):format(bufnr, tostring(err), tostring(result and result.keys and #result.keys))
    )
    if err then
      return
    end
    local keys = result and result.keys or {}
    if on_result then
      return on_result(#keys > 0 and keys or nil)
    end
    if #keys > 0 then
      vim.schedule(function()
        render_locale_file(bufnr, { keys = keys })
      end)
    end
  end)
end

--- Issue the decoration request for (bufnr, client) with debounce and warm-up retry.
--- The client is passed in: during LspAttach the buffer is not yet in the client's
--- attached list, so a get_clients({ bufnr }) lookup races and silently drops.
function M.request(bufnr, client)
  if not enabled then
    return
  end
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
    if locale_files[bufnr] then
      return request_file_keys(bufnr, client)
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
      if result and result.decorations and #result.decorations > 0 then
        retries[bufnr] = nil
        return vim.schedule(function()
          render(bufnr, result)
        end)
      end
      --[[ No decorations: either the server is still loading, the file simply has
        no translate calls, or it is a locale file, which the server only answers
        through x18n/fileKeys. A plain (key-less) file is remembered so later
        refreshes skip the probe; the warm-up signature is empty keys plus an
        empty locale. ]]
      if plain_files[bufnr] then
        return
      end
      request_file_keys(bufnr, client, function(keys)
        if keys then
          locale_files[bufnr] = true
          return vim.schedule(function()
            render_locale_file(bufnr, { keys = keys })
          end)
        end
        if (result and result.locale or '') ~= '' then
          plain_files[bufnr] = true
          return
        end
        if (retries[bufnr] or 0) < 5 then
          retries[bufnr] = (retries[bufnr] or 0) + 1
          vim.defer_fn(function()
            if pending[bufnr] == nil then
              M.request(bufnr, client)
            end
          end, 1000)
        end
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
    for _, bufnr in ipairs(buffers_of(client)) do
      M.refresh(bufnr)
    end
  end
end

--- Exposed for tests.
function M.namespace()
  return ns
end

---@param opts {mode: 'inline'|'eol'|'conceal'?, virt_text_pos: string?, debounce_ms: integer}
function M.setup(opts)
  cfg = opts
  --[[ `virt_text_pos` is the pre-conceal spelling of `mode`; keep both working. ]]
  if not cfg.mode and cfg.virt_text_pos then
    cfg.mode = cfg.virt_text_pos
  end
  cfg.mode = cfg.mode or 'inline'
  enabled = true
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
      local timer = pending[a.buf]
      if timer then
        timer:stop()
        timer:close()
        pending[a.buf] = nil
      end
      retries[a.buf] = nil
      locale_files[a.buf] = nil
      plain_files[a.buf] = nil
      clear(a.buf)
    end,
  })
  aug('BufWritePost', { group = group, callback = function(a) M.refresh(a.buf) end })
  aug('TextChanged', { group = group, callback = function(a) M.refresh(a.buf) end })
  aug('InsertLeave', { group = group, callback = function(a) M.refresh(a.buf) end })
  aug('ColorScheme', { group = group, callback = define_highlights })
  if cfg.mode == 'conceal' then
    --[[ A window opened on an already-decorated buffer needs the raised
      conceallevel too; windows nobody decorated keep their own setting. ]]
    aug('BufWinEnter', {
      group = group,
      callback = function(a)
        if #vim.lsp.get_clients({ bufnr = a.buf, name = 'x18n' }) > 0 then
          ensure_conceallevel(a.buf)
        end
      end,
    })
  end
end

return M
