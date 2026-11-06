local M = {}

local util = require 'x18n.util'
local lsp = require 'x18n.lsp'

---@alias x18n.ShowMode 'both'|'translation'|'translation_conceal'|'origin'|'conceal'|'eol'
---@alias x18n.ModeInput x18n.ShowMode|'inline'
---@alias x18n.CursorRule 'same'|'inline_arrow'|'eol_arrow'|'hidden'
---@alias x18n.VirtPos 'inline'|'eol'

---@class x18n.ModeRule
---@field conceal boolean
---@field shows boolean
---@field cursor x18n.CursorRule
---@field pos x18n.VirtPos

---@class x18n.Decoration
---@field key string?
---@field state string?
---@field value string?
---@field range table?
---@field expression table?

---@class x18n.DecorationsResult
---@field locale string?
---@field decorations x18n.Decoration[]?

---@alias x18n.FileClass 'unknown'|'warming'|'code'|'locale'|'plain'

---@class x18n.BufferView
---@field timer uv.uv_timer_t?
---@field retry uv.uv_timer_t?
---@field attempt integer
---@field class x18n.FileClass
---@field result x18n.DecorationsResult?
---@field missing_lines table<integer, true>?

---@class x18n.WindowBook
---@field baseline table<integer, integer>
---@field raised table<integer, true>
---@field last_baseline integer?

---@class x18n.LocaleEol
---@field explicit boolean?
---@field usage boolean

---@class x18n.DecorationsConfig
---@field enabled boolean?
---@field mode x18n.ModeInput?
---@field virt_text_pos string?
---@field debounce_ms integer?
---@field cursor_redraw_ms integer?
---@field show_locale_file_eol_translation boolean?
---@field show_locale_file_eol_usage boolean?

---@class x18n.DecorationsState
---@field cfg x18n.DecorationsConfig
---@field enabled boolean
---@field last_non_origin x18n.ShowMode
---@field buffers table<integer, x18n.BufferView>
---@field windows x18n.WindowBook
---@field cursor_timer uv.uv_timer_t?
---@field eol x18n.LocaleEol

---@class x18n.Concealed
---@field kind 'concealed'
---@field start integer[]
---@field finish integer[]
---@field text string?
---@field pos x18n.VirtPos
---@field hl string

---@class x18n.Annotation
---@field kind 'annotation'
---@field at integer[]
---@field text string
---@field pos x18n.VirtPos
---@field hl string

---@alias x18n.Shape x18n.Concealed|x18n.Annotation

local ns = vim.api.nvim_create_namespace 'x18n_decoration'

---@type x18n.DecorationsState
local state = {
  cfg = {},
  enabled = false,
  last_non_origin = 'conceal',
  buffers = {},
  windows = { baseline = {}, raised = {}, last_baseline = nil },
  cursor_timer = nil,
  eol = { explicit = nil, usage = true },
}

local windows = {}

---@type table<x18n.ShowMode, x18n.ModeRule>
local RULES = {
  both = { conceal = false, shows = true, cursor = 'same', pos = 'inline' },
  translation = { conceal = true, shows = true, cursor = 'inline_arrow', pos = 'inline' },
  translation_conceal = { conceal = true, shows = true, cursor = 'hidden', pos = 'inline' },
  origin = { conceal = false, shows = false, cursor = 'same', pos = 'inline' },
  conceal = { conceal = true, shows = true, cursor = 'eol_arrow', pos = 'inline' },
  eol = { conceal = false, shows = true, cursor = 'same', pos = 'eol' },
}

---@type table<string, x18n.ShowMode>
local ALIAS = { inline = 'both' }

---@type table<x18n.ShowMode, x18n.ShowMode>
local ORIGIN_ENTER = { translation = 'both', translation_conceal = 'both', conceal = 'both' }

---@type table<x18n.ShowMode, x18n.ShowMode>
local ORIGIN_BACK = { both = 'translation_conceal' }

local function define_highlights()
  vim.api.nvim_set_hl(0, 'X18nValue', { default = true, link = 'Comment' })
  vim.api.nvim_set_hl(0, 'X18nValueMissing', { default = true, link = 'DiagnosticError' })
end

local function hl_for(status)
  if status == 'ok' then
    return 'X18nValue'
  end
  if status == 'missing' then
    return 'X18nValueMissing'
  end
  return 'WarningMsg'
end

---@param mode string?
---@return x18n.ShowMode?
local function mode_key(mode)
  local key = mode and (ALIAS[mode] or mode) or nil
  return key and RULES[key] and key or nil
end

---@return x18n.ModeRule
local function current_rule()
  return RULES[mode_key(state.cfg.mode) or 'both']
end

local function clear(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  end
end

---@param timer uv.uv_timer_t?
local function stop_timer(timer)
  if timer and not timer:is_closing() then
    timer:stop()
    timer:close()
  end
end

---@param bufnr integer
---@return x18n.BufferView
local function view_for(bufnr)
  local view = state.buffers[bufnr]
  if not view then
    view = { attempt = 0, class = 'unknown' }
    state.buffers[bufnr] = view
  end
  return view
end

---@param bufnr integer
---@return boolean
local function conceals(bufnr)
  local view = state.buffers[bufnr]
  return state.enabled
    and state.cfg.debounce_ms ~= nil
    and current_rule().conceal
    and view ~= nil
    and view.result ~= nil
    and view.class ~= 'locale'
    and view.class ~= 'plain'
end

---@param book x18n.WindowBook
---@param win integer
---@return integer?
local function capture_level(book, win)
  if book.baseline[win] == nil then
    local level = vim.wo[win].conceallevel
    book.baseline[win] = level
    book.last_baseline = level
  end
  return book.baseline[win]
end

function windows.raise(book, win)
  capture_level(book, win)
  book.raised[win] = true
  if vim.wo[win].conceallevel < 2 then
    vim.wo[win].conceallevel = 2
  end
end

function windows.restore(book, win)
  if not book.raised[win] then
    return
  end
  book.raised[win] = nil
  if book.baseline[win] ~= nil and vim.api.nvim_win_is_valid(win) then
    vim.wo[win].conceallevel = book.baseline[win]
  end
end

function windows.release(book, win)
  if not book.raised[win] and book.baseline[win] ~= nil then
    vim.wo[win].conceallevel = book.baseline[win]
  end
end

function windows.raise_buffer(book, bufnr)
  for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
    windows.raise(book, win)
  end
end

function windows.restore_all(book)
  for _, win in ipairs(vim.tbl_keys(book.raised)) do
    windows.restore(book, win)
  end
end

function windows.restore_buffer(book, bufnr)
  for _, win in ipairs(vim.tbl_keys(book.raised)) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
      windows.restore(book, win)
    end
  end
end

function windows.forget(book, win)
  book.baseline[win] = nil
  book.raised[win] = nil
end

function windows.reconcile(book, bufnr)
  if conceals(bufnr) then
    return
  end
  windows.restore(book, vim.api.nvim_get_current_win())
end

--- A window created by a split inherits the source options after WinNew, so the
--- reset has to happen when the new buffer is first displayed.
function windows.release_buffer(book, bufnr)
  if conceals(bufnr) then
    return
  end
  windows.release(book, vim.api.nvim_get_current_win())
end

function windows.adopt(book, win)
  if vim.api.nvim_win_get_config(win).relative ~= '' then
    return
  end
  local previous = vim.fn.win_getid(vim.fn.winnr '#')
  local level = book.baseline[previous] or book.last_baseline
  if level ~= nil then
    book.baseline[win] = level
    vim.wo[win].conceallevel = level
  end
end

local function buffers_of(client)
  local out = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.lsp.buf_is_attached(bufnr, client.id) then
      out[#out + 1] = bufnr
    end
  end
  return out
end

local function cursor_line(bufnr)
  if vim.api.nvim_win_get_buf(0) ~= bufnr then
    return -1
  end
  return vim.api.nvim_win_get_cursor(0)[1] - 1
end

---@param view x18n.BufferView
---@param bufnr integer
local function index_missing_diagnostics(view, bufnr)
  local lines = {}
  for _, diag in ipairs(vim.diagnostic.get(bufnr)) do
    if
      diag.source == 'x18n'
      and (diag.code == 'missing-key' or diag.user_data and type(diag.user_data) == 'table' and diag.user_data.key)
    then
      lines[diag.lnum] = true
    end
  end
  view.missing_lines = lines
end

---@param view x18n.BufferView
---@param bufnr integer
---@param d x18n.Decoration
---@return boolean
local function has_missing_diagnostic(view, bufnr, d)
  local lines = view.missing_lines
  if not lines or next(lines) == nil then
    return false
  end
  local line = util.to_byte(bufnr, d.expression and d.expression.start or d.range.start)
  return lines[line] == true
end

local function widen_over_quotes(bufnr, range)
  local s_line, s_col = util.to_byte(bufnr, range.start)
  local e_line, e_col = util.to_byte(bufnr, range['end'])
  if s_line ~= e_line then
    return s_line, s_col, e_line, e_col
  end
  local line = vim.api.nvim_buf_get_lines(bufnr, s_line, s_line + 1, false)[1] or ''
  local quote_before = line:sub(s_col, s_col)
  local quote_after = line:sub(e_col + 1, e_col + 1)
  if quote_before:match '[\'"`]' and quote_after:match '[\'"`]' then
    return s_line, s_col - 1, e_line, e_col + 1
  end
  return s_line, s_col, e_line, e_col
end

---@param bufnr integer
---@param rule x18n.ModeRule
---@param d x18n.Decoration
---@param cursor_row integer
---@param skip boolean
---@return x18n.Shape?
local function shape_for(bufnr, rule, d, cursor_row, skip)
  if skip then
    return nil
  end
  if rule.conceal and d.state == 'ok' and d.value and d.value ~= '' and d.range then
    local s_line, s_col, e_line, e_col = widen_over_quotes(bufnr, d.range)
    local text, pos = d.value, 'inline'
    if cursor_row == s_line then
      if rule.cursor == 'inline_arrow' then
        text, pos = ' → ' .. d.value, 'inline'
      elseif rule.cursor == 'eol_arrow' then
        text, pos = '→ ' .. d.value, 'eol'
      elseif rule.cursor == 'hidden' then
        text = nil
      end
    end
    return {
      kind = 'concealed',
      start = { s_line, s_col },
      finish = { e_line, e_col },
      text = text,
      pos = pos,
      hl = hl_for 'ok',
    }
  end
  local expression = d.expression or d.range
  if not expression then
    return nil
  end
  local line, col = util.to_byte(bufnr, expression['end'])
  if cursor_row == line and rule.cursor == 'hidden' then
    return nil
  end
  local text = (d.value and d.value ~= '') and (' → ' .. d.value) or (' → ' .. (d.state or 'missing'))
  return {
    kind = 'annotation',
    at = { line, col },
    text = text,
    pos = rule.pos,
    hl = hl_for(d.state),
  }
end

---@param bufnr integer
---@param shape x18n.Shape
local function draw(bufnr, shape)
  if shape.kind == 'annotation' then
    vim.api.nvim_buf_set_extmark(bufnr, ns, shape.at[1], shape.at[2], {
      virt_text = { { shape.text, shape.hl } },
      virt_text_pos = shape.pos,
      hl_mode = 'combine',
    })
    return
  end
  --[[ An empty cchar hides the range completely; any printable char
    (a space included) leaves a visible gap. ]]
  vim.api.nvim_buf_set_extmark(bufnr, ns, shape.start[1], shape.start[2], {
    end_line = shape.finish[1],
    end_col = shape.finish[2],
    conceal = '',
    hl_mode = 'combine',
  })
  if not shape.text then
    return
  end
  local line, col = shape.finish[1], shape.finish[2]
  if shape.pos == 'eol' then
    line, col = shape.start[1], 0
  end
  vim.api.nvim_buf_set_extmark(bufnr, ns, line, col, {
    virt_text = { { shape.text, shape.hl } },
    virt_text_pos = shape.pos,
    hl_mode = 'combine',
  })
end

---@param bufnr integer
---@param result x18n.DecorationsResult
local function render(bufnr, result)
  if not state.enabled then
    return
  end
  if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end
  clear(bufnr)
  local view = view_for(bufnr)
  view.result, view.class = result, 'code'
  require('x18n.mirror').render(bufnr, result)
  index_missing_diagnostics(view, bufnr)
  local rule = current_rule()
  if not rule.shows then
    windows.restore_all(state.windows)
    return
  end
  local cur = rule.cursor ~= 'same' and cursor_line(bufnr) or -1
  if rule.conceal then
    windows.raise_buffer(state.windows, bufnr)
  end
  for _, d in ipairs(result and result.decorations or {}) do
    local skip = d.state == 'missing' and has_missing_diagnostic(view, bufnr, d)
    local shape = shape_for(bufnr, rule, d, cur, skip)
    if shape then
      draw(bufnr, shape)
    end
  end
end

local function usage_label(n)
  if n == 0 then
    return 'no usages'
  end
  if n == 1 then
    return '1 usage'
  end
  return n .. ' usages'
end

---@param bufnr integer
---@param result table?
local function render_locale_file(bufnr, result)
  if not state.enabled then
    return
  end
  if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end
  clear(bufnr)
  windows.restore_buffer(state.windows, bufnr)
  local view = view_for(bufnr)
  view.class = 'locale'
  local keys = result and result.keys or {}
  local show_value = state.eol.explicit == true
  for _, k in ipairs(keys) do
    local segments = {}
    if show_value then
      segments[#segments + 1] = k.value or 'missing'
    end
    if state.eol.usage and k.usages ~= nil then
      segments[#segments + 1] = usage_label(k.usages)
    end
    if #segments > 0 then
      local line = util.to_byte(bufnr, k.range.start)
      local hl_state = (show_value and k.value == nil) and 'missing' or 'ok'
      vim.api.nvim_buf_set_extmark(bufnr, ns, line, 0, {
        virt_text = { { ' ' .. table.concat(segments, ' · '), hl_for(hl_state) } },
        virt_text_pos = 'eol',
        hl_mode = 'combine',
      })
    end
  end
end

---@param bufnr integer
---@param client vim.lsp.Client
---@param on_result fun(keys: table[]?)?
local function request_file_keys(bufnr, client, on_result)
  lsp.custom_request(client, 'x18n/fileKeys', { uri = vim.uri_from_bufnr(bufnr) }, function(err, result)
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

---@param bufnr integer
---@param client vim.lsp.Client
---@param view x18n.BufferView
---@return boolean retried
local function retry_warm_up(bufnr, client, view)
  if view.attempt >= 5 then
    return false
  end
  local delay = 500 * 2 ^ view.attempt
  view.attempt = view.attempt + 1
  view.class = 'warming'
  stop_timer(view.retry)
  view.retry = vim.defer_fn(function()
    view.retry = nil
    if view.timer == nil and view.class ~= 'locale' then
      M.request(bufnr, client)
    end
  end, delay)
  return true
end

--- x18n's own config is metadata, not a translation source.
---@param bufnr integer
---@return boolean
local function is_config_buffer(bufnr)
  return vim.fs.basename(vim.api.nvim_buf_get_name(bufnr)):match '^x18n%.config%.' ~= nil
end

--- Issue the decoration request for (bufnr, client) with debounce and warm-up retry.
--- The client is passed in: during LspAttach the buffer is not yet in the client's
--- attached list, so a get_clients({ bufnr }) lookup races and silently drops.
function M.request(bufnr, client)
  if not state.enabled or not state.cfg.debounce_ms then
    return
  end
  if is_config_buffer(bufnr) then
    clear(bufnr)
    return
  end
  local view = view_for(bufnr)
  stop_timer(view.timer)
  view.timer = vim.defer_fn(function()
    view.timer = nil
    if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) or client:is_stopped() then
      return
    end
    if view.class == 'locale' then
      return request_file_keys(bufnr, client)
    end
    lsp.custom_request(client, 'x18n/decorations', { uri = vim.uri_from_bufnr(bufnr) }, function(err, result)
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
        view.attempt = 0
        return vim.schedule(function()
          render(bufnr, result)
        end)
      end
      if view.class == 'plain' then
        return
      end
      request_file_keys(bufnr, client, function(keys)
        if keys then
          view.attempt = 0
          view.class = 'locale'
          return vim.schedule(function()
            render_locale_file(bufnr, { keys = keys })
          end)
        end
        if retry_warm_up(bufnr, client, view) then
          return
        end
        view.attempt = 0
        view.class = ((result and result.locale or '') ~= '') and 'plain' or 'unknown'
      end)
    end)
  end, state.cfg.debounce_ms)
end

--- Toggle decorations for every attached buffer, clearing them when off.
---@return boolean the new state
function M.toggle()
  if not state.cfg.debounce_ms then
    return false
  end
  state.enabled = not state.enabled
  for _, client in ipairs(vim.lsp.get_clients { name = 'x18n' }) do
    for _, bufnr in ipairs(buffers_of(client)) do
      if state.enabled then
        M.request(bufnr, client)
      else
        clear(bufnr)
        require('x18n.mirror').clear(bufnr)
      end
    end
  end
  if not state.enabled then
    windows.restore_all(state.windows)
  end
  return state.enabled
end

--- Toggle the locale-file EOL translation segment. Usage badges are separate.
---@return boolean the new state
function M.toggle_locale_file_eol()
  if not state.cfg.debounce_ms then
    return false
  end
  state.eol.explicit = not M.locale_file_eol()
  M.refresh_attached()
  return state.eol.explicit
end

--- The effective state.
---@return boolean
function M.locale_file_eol()
  if not state.cfg.debounce_ms then
    return false
  end
  return state.eol.explicit == true
end

--- Switch the display mode. Unknown modes leave the current one in place.
---@param mode string
---@return string current mode
function M.set_mode(mode)
  if not state.cfg.debounce_ms then
    return 'off'
  end
  local key = mode_key(mode)
  if not key then
    return state.cfg.mode
  end
  if key ~= 'origin' then
    state.last_non_origin = key
  end
  state.cfg.mode = mode
  if not RULES[key].conceal then
    windows.restore_all(state.windows)
  end
  if state.enabled then
    M.refresh_attached()
  end
  return state.cfg.mode
end

---@return string
function M.get_mode()
  return state.cfg.mode or 'off'
end

--- Toggle the translation overlay: origin in, or the last mode back.
---@return string new mode
function M.toggle_translation()
  if not state.cfg.debounce_ms then
    return 'off'
  end
  local current = mode_key(state.cfg.mode) or 'both'
  if current == 'origin' then
    return M.set_mode(state.last_non_origin or 'conceal')
  end
  state.last_non_origin = current
  return M.set_mode 'origin'
end

--- Toggle whether the raw key is shown while translations stay active.
--- Mirrors i18n.nvim's transitions so muscle memory carries over.
---@return string new mode
function M.toggle_origin()
  if not state.cfg.debounce_ms then
    return 'off'
  end
  local current = mode_key(state.cfg.mode) or 'both'
  if current == 'origin' then
    local previous = state.last_non_origin or 'conceal'
    return M.set_mode(ORIGIN_BACK[previous] or previous)
  end
  return M.set_mode(ORIGIN_ENTER[current] or 'translation_conceal')
end

function M.refresh(bufnr)
  if not state.cfg.debounce_ms then
    return
  end
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
  for _, client in ipairs(vim.lsp.get_clients { name = 'x18n' }) do
    for _, bufnr in ipairs(buffers_of(client)) do
      M.refresh(bufnr)
    end
  end
end

--- Exposed for tests.
function M.namespace()
  return ns
end

--- Exposed for tests.
function M.state()
  local results = {}
  for bufnr, view in pairs(state.buffers) do
    if view.result ~= nil then
      results[#results + 1] = bufnr
    end
  end
  return {
    baseline = vim.deepcopy(state.windows.baseline),
    raised = vim.deepcopy(state.windows.raised),
    last = state.windows.last_baseline,
    results = results,
  }
end

--- Clear every decoration and stop pending refreshes. Used when the client is
--- stopped; the caches are dropped so a fresh attach rebuilds them.
function M.clear_all()
  for _, view in pairs(state.buffers) do
    stop_timer(view.timer)
    stop_timer(view.retry)
  end
  stop_timer(state.cursor_timer)
  state.cursor_timer = nil
  state.buffers = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      clear(bufnr)
    end
  end
  windows.restore_all(state.windows)
  require('x18n.mirror').clear_all()
  state.windows.baseline = {}
  state.windows.raised = {}
end

local function redraw(bufnr)
  local view = state.buffers[bufnr]
  if view and view.class == 'code' and view.result and vim.api.nvim_buf_is_loaded(bufnr) then
    render(bufnr, view.result)
  end
end

---@param opts x18n.DecorationsConfig
function M.setup(opts)
  state.cfg = opts
  --[[ `virt_text_pos` is the pre-conceal spelling of `mode`; keep both working. ]]
  if not state.cfg.mode and state.cfg.virt_text_pos then
    state.cfg.mode = state.cfg.virt_text_pos
  end
  state.cfg.mode = state.cfg.mode or 'conceal'
  if not mode_key(state.cfg.mode) then
    state.cfg.mode = 'both'
  end
  state.last_non_origin = mode_key(state.cfg.mode) or 'both'
  state.eol.explicit = state.cfg.show_locale_file_eol_translation
  state.eol.usage = state.cfg.show_locale_file_eol_usage ~= false
  state.enabled = true
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
      local view = state.buffers[a.buf]
      if view then
        stop_timer(view.timer)
        stop_timer(view.retry)
        state.buffers[a.buf] = nil
      end
      clear(a.buf)
    end,
  })
  aug('BufWritePost', {
    group = group,
    callback = function(a)
      M.refresh(a.buf)
    end,
  })
  aug('BufEnter', {
    group = group,
    callback = function(a)
      windows.reconcile(state.windows, a.buf)
      M.refresh(a.buf)
    end,
  })
  aug('WinNew', {
    group = group,
    callback = function()
      windows.adopt(state.windows, vim.api.nvim_get_current_win())
    end,
  })
  aug('WinClosed', {
    group = group,
    callback = function(a)
      local win = tonumber(a.match)
      if win then
        windows.forget(state.windows, win)
      end
    end,
  })
  aug('TextChanged', {
    group = group,
    callback = function(a)
      M.refresh(a.buf)
    end,
  })
  aug('InsertLeave', {
    group = group,
    callback = function(a)
      M.refresh(a.buf)
    end,
  })
  aug('ColorScheme', { group = group, callback = define_highlights })
  local on_move = function(bufnr)
    if current_rule().cursor == 'same' then
      return
    end
    stop_timer(state.cursor_timer)
    state.cursor_timer = vim.defer_fn(function()
      state.cursor_timer = nil
      redraw(bufnr)
    end, state.cfg.cursor_redraw_ms or 100)
  end
  aug('CursorMoved', {
    group = group,
    callback = function(a)
      on_move(a.buf)
    end,
  })
  aug('CursorMovedI', {
    group = group,
    callback = function(a)
      on_move(a.buf)
    end,
  })
  aug('WinEnter', {
    group = group,
    callback = function(a)
      windows.reconcile(state.windows, a.buf)
      redraw(a.buf)
    end,
  })
  aug('BufWinEnter', {
    group = group,
    callback = function(a)
      windows.release_buffer(state.windows, a.buf)
      redraw(a.buf)
    end,
  })
end

return M
