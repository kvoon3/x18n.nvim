local M = {}

local util = require 'x18n.util'

local ns = vim.api.nvim_create_namespace 'x18n_decoration'
local cfg = {}
local enabled = false
local pending = {} -- bufnr -> uv timer
local retries = {} -- bufnr -> warm-up poll count
local locale_files = {} -- bufnr -> true once fileKeys proved it is a locale file
local plain_files = {} -- bufnr -> true once a warm server proved it holds no keys
local results = {} -- bufnr -> last decorations reply, for cursor-line redraws
local cursor_timer = nil -- CursorMoved debounce
local baseline = {} -- winid -> the conceallevel the user had before we raised it
local raised = {} -- winid -> true while we want conceallevel 2 in that window
local last_baseline = nil -- the level a new split should start from
local locale_eol_translation = true -- nil = auto: show the value when usage counts are absent
local locale_eol_value_shown = false -- effective state of the last locale render
local locale_eol_usage = true

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

--[[ One row per display mode. Each row answers four questions: hide the key
  literal away from the cursor, show the value away from the cursor, what the
  cursor's line shows, and where a visible value sits. `conceal` is the local
  default; `both`, `translation`, `translation_conceal` and `origin` are the
  i18n.nvim names, so a user can switch without relearning the model. ]]
local MODES = {
  both = { conceal = false, value = 'always', cursor = 'inline', pos = 'inline', cursor_dependent = false },
  translation = { conceal = true, value = 'always', cursor = 'inline', pos = 'inline', cursor_dependent = true },
  translation_conceal = { conceal = true, value = 'away', cursor = 'none', pos = 'inline', cursor_dependent = true },
  origin = { conceal = false, value = 'never', cursor = 'none', pos = 'inline', cursor_dependent = false },
  conceal = { conceal = true, value = 'away', cursor = 'arrow', pos = 'inline', cursor_dependent = true },
  eol = { conceal = false, value = 'always', cursor = 'inline', pos = 'eol', cursor_dependent = false },
}
MODES.inline = MODES.both

local last_non_origin = 'conceal'

---@param mode string
---@return string canonical
local function canonical(mode)
  if mode == 'inline' then
    return 'both'
  end
  return MODES[mode] and mode or 'both'
end

local function plan()
  return MODES[canonical(cfg.mode)]
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

--- Conceal needs 'conceallevel' >= 2 in every window showing the buffer. The
--- baseline is recorded once per window and survives restores, so a later
--- render that finds a level of 2 (our own earlier raise) does not mistake it
--- for the user's setting.
local function ensure_conceallevel(bufnr)
  for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
    if baseline[win] == nil then
      baseline[win] = vim.wo[win].conceallevel
      last_baseline = baseline[win]
    end
    raised[win] = true
    if vim.wo[win].conceallevel < 2 then
      vim.wo[win].conceallevel = 2
    end
  end
end

---@param win integer
local function restore_window(win)
  if not raised[win] then
    return
  end
  raised[win] = nil
  if baseline[win] ~= nil and vim.api.nvim_win_is_valid(win) then
    vim.wo[win].conceallevel = baseline[win]
  end
end

--- Put the conceallevel of every window we raised back to its baseline.
local function restore_conceallevel()
  local wins = {}
  for win in pairs(raised) do
    wins[#wins + 1] = win
  end
  for _, win in ipairs(wins) do
    restore_window(win)
  end
end

--- Restore only the windows currently showing this buffer. Locale files do not
--- conceal anything, so they must not inherit a code buffer's raised level when
--- the window switches to them.
local function restore_conceallevel_for(bufnr)
  local wins = {}
  for win in pairs(raised) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
      wins[#wins + 1] = win
    end
  end
  for _, win in ipairs(wins) do
    restore_window(win)
  end
end

--- True when this buffer renders with the key concealed right now.
---@param bufnr integer
---@return boolean
local function needs_conceal(bufnr)
  return enabled
    and cfg.debounce_ms ~= nil
    and plan().conceal
    and results[bufnr] ~= nil
    and not locale_files[bufnr]
    and not plain_files[bufnr]
end

--- Reconcile the current window with the buffer it shows. A window that still
--- shows a concealed buffer keeps its level; a raised plain window gets its
--- baseline back.
---@param bufnr integer
local function reconcile_window(bufnr)
  if needs_conceal(bufnr) then
    return
  end
  restore_window(vim.api.nvim_get_current_win())
end

--- A window created by a split inherits the source options after WinNew, so the
--- reset has to happen when the new buffer is first displayed.
---@param bufnr integer
local function reset_inherited_window(bufnr)
  if needs_conceal(bufnr) then
    return
  end
  local win = vim.api.nvim_get_current_win()
  if not raised[win] and baseline[win] ~= nil then
    vim.wo[win].conceallevel = baseline[win]
  end
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
  if before:match '[\'"`]' and after:match '[\'"`]' then
    s_col = s_col - 1
    e_col = e_col + 1
  end
  return s_line, s_col, e_line, e_col
end

--- The cursor's line in the current window, or -1 when the window shows
--- another buffer. Conceal mode renders that line differently.
local function cursor_line(bufnr)
  if vim.api.nvim_win_get_buf(0) ~= bufnr then
    return -1
  end
  return vim.api.nvim_win_get_cursor(0)[1] - 1
end

-- Line numbers (0-based) carrying an x18n missing-key diagnostic this render.
local missing_diag_lines = {}

--- True when the server already publishes this decoration's missing key as a
--- diagnostic on the same line, so the virtual-text arrow would be a repeat.
--- False while no x18n diagnostic has landed yet, so the arrow keeps signaling
--- the problem until the diagnostic replaces it.
---@param bufnr integer
---@param d table Decoration
local function has_missing_diagnostic(bufnr, d)
  local lines = missing_diag_lines[bufnr]
  if not lines then
    return false
  end
  local any_x18n = next(lines) ~= nil
  if not any_x18n then
    return false
  end
  local line = util.to_byte(bufnr, d.expression and d.expression.start or d.range.start)
  return lines[line] == true
end

--- Rebuild the per-buffer missing-diagnostic line index. Called before every
--- render pass; diagnostics arrive asynchronously with the server's changes.
---@return boolean true when the buffer carries any x18n diagnostic
local function index_missing_diagnostics(bufnr)
  local lines = {}
  for _, diag in ipairs(vim.diagnostic.get(bufnr)) do
    if
      diag.source == 'x18n'
      and (diag.code == 'missing-key' or diag.user_data and type(diag.user_data) == 'table' and diag.user_data.key)
    then
      lines[diag.lnum] = true
    end
  end
  missing_diag_lines[bufnr] = lines
  return next(lines) ~= nil
end
--- Toggle decorations for every attached buffer, clearing them when off.
---@return boolean the new state
function M.toggle()
  if not cfg.debounce_ms then
    return false
  end
  enabled = not enabled
  for _, client in ipairs(vim.lsp.get_clients { name = 'x18n' }) do
    for _, bufnr in ipairs(buffers_of(client)) do
      if enabled then
        M.request(bufnr, client)
      else
        clear(bufnr)
        require('x18n.mirror').clear(bufnr)
      end
    end
  end
  if not enabled then
    restore_conceallevel()
  end
  return enabled
end

--- Toggle the locale-file EOL translation segment. Usage badges are separate.
---@return boolean the new state
function M.toggle_locale_file_eol()
  if not cfg.debounce_ms then
    return false
  end
  locale_eol_translation = not M.locale_file_eol()
  locale_eol_value_shown = locale_eol_translation
  M.refresh_attached()
  return locale_eol_translation
end

--- The effective state: an explicit setting wins, auto follows the server's
--- ability to report usage counts (the last locale render answers it).
---@return boolean
function M.locale_file_eol()
  if cfg.debounce_ms == nil then
    return false
  end
  if locale_eol_translation ~= nil then
    return locale_eol_translation
  end
  return locale_eol_value_shown
end

--- Switch the display mode. Unknown modes leave the current one in place.
---@param mode string
---@return string current mode
function M.set_mode(mode)
  if not cfg.debounce_ms then
    return 'off'
  end
  if not MODES[mode] then
    return cfg.mode
  end
  local target = canonical(mode)
  if target ~= 'origin' then
    last_non_origin = target
  end
  cfg.mode = mode
  if not MODES[target].conceal then
    restore_conceallevel()
  end
  if enabled then
    M.refresh_attached()
  end
  return cfg.mode
end

---@return string
function M.get_mode()
  return cfg.mode or 'off'
end

--- Toggle the translation overlay: origin in, or the last mode back.
---@return string new mode
function M.toggle_translation()
  if not cfg.debounce_ms then
    return 'off'
  end
  local current = canonical(cfg.mode)
  if current == 'origin' then
    return M.set_mode(last_non_origin or 'conceal')
  end
  last_non_origin = current
  return M.set_mode 'origin'
end

--- Toggle whether the raw key is shown while translations stay active.
--- Mirrors i18n.nvim's transitions so muscle memory carries over.
---@return string new mode
function M.toggle_origin()
  if not cfg.debounce_ms then
    return 'off'
  end
  local current = canonical(cfg.mode)
  if current == 'origin' then
    local back = last_non_origin or 'conceal'
    if back == 'both' then
      back = 'translation_conceal'
    end
    return M.set_mode(back)
  end
  local target = 'translation_conceal'
  if current == 'translation' or current == 'translation_conceal' or current == 'conceal' then
    target = 'both'
  end
  return M.set_mode(target)
end

local function render(bufnr, result)
  if not enabled then
    return
  end
  if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end
  clear(bufnr)
  results[bufnr] = result
  require('x18n.mirror').render(bufnr, result)
  index_missing_diagnostics(bufnr)
  local p = plan()
  if p.value == 'never' then
    restore_conceallevel()
    return
  end
  local cur = p.cursor_dependent and cursor_line(bufnr) or -1
  if p.conceal then
    ensure_conceallevel(bufnr)
  end
  for _, d in ipairs(result and result.decorations or {}) do
    --[[ The server publishes a missing-key finding as a diagnostic on the same
      line; printing it a second time as virtual text only adds noise. ]]
    local skip = d.state == 'missing' and has_missing_diagnostic(bufnr, d)
    if not skip and p.conceal and d.state == 'ok' and d.value and d.value ~= '' and d.range then
      --[[ Two shapes per key, swapped by a cursor-line redraw: away from the
        cursor the concealed literal is replaced by its value inline; on the
        cursor's line the raw key shows (conceal always reveals there) and the
        value follows the mode's cursor rule. Static extmarks cannot switch by
        themselves, so CursorMoved re-renders from the cached result. ]]
      local s_line, s_col, e_line, e_col = quoted_range(bufnr, d.range)
      vim.api.nvim_buf_set_extmark(bufnr, ns, s_line, s_col, {
        end_line = e_line,
        end_col = e_col,
        --[[ An empty cchar hides the range completely; any printable char
          (a space included) leaves a visible gap. ]]
        conceal = '',
        hl_mode = 'combine',
      })
      local text, pos
      if s_line ~= cur then
        text, pos = d.value, 'inline'
      elseif p.cursor == 'arrow' then
        text, pos = '→ ' .. d.value, 'eol'
      elseif p.cursor == 'inline' then
        text, pos = ' → ' .. d.value, 'inline'
      end
      if text then
        local line, col = e_line, e_col
        if pos == 'eol' then
          line, col = s_line, 0
        end
        vim.api.nvim_buf_set_extmark(bufnr, ns, line, col, {
          virt_text = { { text, hl_for 'ok' } },
          virt_text_pos = pos,
          hl_mode = 'combine',
        })
      end
    elseif not skip then
      --[[ Some usages (directives, template pipes) have no enclosing call, so
        the server sends only the key range. Put the marker after that. ]]
      local expression = d.expression or d.range
      local line, col = util.to_byte(bufnr, expression['end'])
      --[[ translation_conceal leaves the cursor line raw only. ]]
      local on_cursor = p.cursor_dependent and line == cur
      if not (on_cursor and p.cursor == 'none') then
        local text = (d.value and d.value ~= '') and (' → ' .. d.value) or (' → ' .. (d.state or 'missing'))
        vim.api.nvim_buf_set_extmark(bufnr, ns, line, col, {
          virt_text = { { text, hl_for(d.state) } },
          virt_text_pos = p.pos,
          hl_mode = 'combine',
        })
      end
    end
  end
end

--- Locale files get no inline decorations from the server; x18n/fileKeys gives
--- their keys, so park the display-locale value and the usage count at the end
--- of each key's line. Either segment can be switched off independently.
local function usage_label(n)
  if n == 0 then
    return 'no usages'
  end
  if n == 1 then
    return '1 usage'
  end
  return n .. ' usages'
end

local function render_locale_file(bufnr, result)
  if not enabled then
    return
  end
  if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end
  clear(bufnr)
  restore_conceallevel_for(bufnr)
  local keys = result and result.keys or {}
  --[[ The published server has no usages in x18n/fileKeys, so the default
    usage badge would leave locale files with no annotation at all. Auto mode
    falls back to the display-locale value, which proves the file is detected. ]]
  local has_usages = false
  for _, k in ipairs(keys) do
    if k.usages ~= nil then
      has_usages = true
      break
    end
  end
  local show_value = locale_eol_translation == true or (locale_eol_translation == nil and not has_usages)
  if #keys > 0 then
    locale_eol_value_shown = show_value
  end
  for _, k in ipairs(keys) do
    local segments = {}
    if show_value then
      segments[#segments + 1] = k.value or 'missing'
    end
    if locale_eol_usage and k.usages ~= nil then
      segments[#segments + 1] = usage_label(k.usages)
    end
    if #segments > 0 then
      local line = util.to_byte(bufnr, k.range.start)
      local state = (show_value and k.value == nil) and 'missing' or 'ok'
      vim.api.nvim_buf_set_extmark(bufnr, ns, line, 0, {
        virt_text = { { ' ' .. table.concat(segments, ' · '), hl_for(state) } },
        virt_text_pos = 'eol',
        hl_mode = 'combine',
      })
    end
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

--[[ An empty x18n/fileKeys reply is also what a probe that races the server's
  first index looks like. Poll with backoff before caching the file as plain,
  so a locale file opened during indexing still gets its badges. Returns false
  once the budget is spent. ]]
---@param bufnr integer
---@param client vim.lsp.Client
---@return boolean retried
local function retry_warm_up(bufnr, client)
  local attempt = retries[bufnr] or 0
  if attempt >= 5 then
    return false
  end
  retries[bufnr] = attempt + 1
  vim.defer_fn(function()
    if pending[bufnr] == nil and not locale_files[bufnr] then
      M.request(bufnr, client)
    end
  end, 500 * 2 ^ attempt)
  return true
end

--- Issue the decoration request for (bufnr, client) with debounce and warm-up retry.
--- The client is passed in: during LspAttach the buffer is not yet in the client's
--- attached list, so a get_clients({ bufnr }) lookup races and silently drops.
function M.request(bufnr, client)
  if not enabled or not cfg.debounce_ms then
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
          plain_files[bufnr] = nil
          retries[bufnr] = nil
          return vim.schedule(function()
            render_locale_file(bufnr, { keys = keys })
          end)
        end
        --[[ The server looks warm (a locale came back) but the file has no
          keys: either it is genuinely plain or the index that answers
          x18n/fileKeys is still landing. Retry before deciding. ]]
        if retry_warm_up(bufnr, client) then
          return
        end
        retries[bufnr] = nil
        if (result and result.locale or '') ~= '' then
          plain_files[bufnr] = true
        end
      end)
    end)
  end, cfg.debounce_ms)
end

function M.refresh(bufnr)
  if not cfg.debounce_ms then
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
  return {
    baseline = vim.deepcopy(baseline),
    raised = vim.deepcopy(raised),
    last = last_baseline,
    results = vim.tbl_keys(results),
  }
end

--- Clear every decoration and stop pending refreshes. Used when the client is
--- stopped; the caches are dropped so a fresh attach rebuilds them.
function M.clear_all()
  for _, timer in pairs(pending) do
    if not timer:is_closing() then
      timer:stop()
      timer:close()
    end
  end
  pending = {}
  results = {}
  retries = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      clear(bufnr)
    end
  end
  restore_conceallevel()
  require('x18n.mirror').clear_all()
  baseline = {}
  raised = {}
end

--- Redraw one buffer from its cached result, for the cursor-line swap.
local function redraw(bufnr)
  local result = results[bufnr]
  if result and vim.api.nvim_buf_is_loaded(bufnr) then
    render(bufnr, result)
  end
end

---@param opts {mode: string?, virt_text_pos: string?, debounce_ms: integer, cursor_redraw_ms?: integer}
function M.setup(opts)
  cfg = opts
  --[[ `virt_text_pos` is the pre-conceal spelling of `mode`; keep both working. ]]
  if not cfg.mode and cfg.virt_text_pos then
    cfg.mode = cfg.virt_text_pos
  end
  cfg.mode = cfg.mode or 'conceal'
  if not MODES[cfg.mode] then
    cfg.mode = 'both'
  end
  last_non_origin = canonical(cfg.mode)
  locale_eol_translation = cfg.show_locale_file_eol_translation
  locale_eol_value_shown = locale_eol_translation == true
  locale_eol_usage = cfg.show_locale_file_eol_usage ~= false
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
      results[a.buf] = nil
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
      reconcile_window(a.buf)
      M.refresh(a.buf)
    end,
  })
  --[[ A split inherits the source window's options, including a conceallevel
    this module raised. Start every new plain window at the level we found. ]]
  aug('WinNew', {
    group = group,
    callback = function()
      local win = vim.api.nvim_get_current_win()
      if vim.api.nvim_win_get_config(win).relative ~= '' then
        return
      end
      --[[ The split inherits the source window's current options. Prefer the
        source window's recorded baseline over the global last-seen one. ]]
      local previous = vim.fn.win_getid(vim.fn.winnr '#')
      local level = baseline[previous] or last_baseline
      if level ~= nil then
        baseline[win] = level
        vim.wo[win].conceallevel = level
      end
    end,
  })
  aug('WinClosed', {
    group = group,
    callback = function(a)
      local win = tonumber(a.match)
      if win then
        baseline[win] = nil
        raised[win] = nil
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
  --[[ Modes can switch at runtime, so the cursor-line machinery is always
    registered and decides per redraw whether the current mode needs it. ]]
  local on_move = function(bufnr)
    if not plan().cursor_dependent then
      return
    end
    if cursor_timer then
      cursor_timer:stop()
      cursor_timer:close()
    end
    cursor_timer = vim.defer_fn(function()
      cursor_timer = nil
      redraw(bufnr)
    end, cfg.cursor_redraw_ms or 100)
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
      reconcile_window(a.buf)
      if results[a.buf] then
        redraw(a.buf)
      end
    end,
  })
  aug('BufWinEnter', {
    group = group,
    callback = function(a)
      reset_inherited_window(a.buf)
      if results[a.buf] then
        redraw(a.buf)
      end
    end,
  })
end

return M
