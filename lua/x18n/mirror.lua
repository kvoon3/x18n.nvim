local util = require 'x18n.util'

local M = {}

--[[ The server reports a key missing from target locales once, at the source
  locale entry (`missing-translation`). Code buffers only see the key, so the
  warning is invisible while editing a usage. Mirror it onto every usage of the
  same key in the code buffers the decorations pass already enumerated. ]]
local ns = vim.api.nvim_create_namespace 'x18n_missing_translation'
local missing = {} -- client id -> locale-file uri -> key -> message
local cache = {} -- bufnr -> last decorations reply

local function reset(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.diagnostic.reset(ns, bufnr)
  end
end

---@param client_id integer
---@return table<string, string> key -> server message
local function messages_for(client_id)
  local out = {}
  for _, keys in pairs(missing[client_id] or {}) do
    for key, message in pairs(keys) do
      out[key] = message
    end
  end
  return out
end

---@param bufnr integer
---@param pos {line: integer, character: integer}
---@return integer row, integer col
local function position(bufnr, pos)
  local row, col = util.to_byte(bufnr, pos)
  --[[ Cached decoration ranges can trail a buffer right after an edit; clamping
    keeps a stale reply from pushing a diagnostic past the end of the buffer. ]]
  local last = vim.api.nvim_buf_line_count(bufnr) - 1
  if row > last then
    return last, 0
  end
  return row, col
end

---@param bufnr integer
local function apply(bufnr)
  local result = cache[bufnr]
  if not result or not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
    cache[bufnr] = nil
    reset(bufnr)
    return
  end
  local client = vim.lsp.get_clients({ bufnr = bufnr, name = 'x18n' })[1]
  if not client then
    reset(bufnr)
    return
  end
  local notes = messages_for(client.id)
  local items = {}
  for _, d in ipairs(result.decorations or {}) do
    local message = d.key and notes[d.key]
    if message and d.range then
      local srow, scol = position(bufnr, d.range.start)
      local erow, ecol = position(bufnr, d.range['end'])
      items[#items + 1] = {
        lnum = srow,
        col = scol,
        end_lnum = erow,
        end_col = ecol,
        severity = vim.diagnostic.severity.WARN,
        message = message,
        source = 'x18n',
        code = 'missing-translation',
      }
    end
  end
  vim.diagnostic.set(ns, bufnr, items)
  if vim.g.x18n_debug then
    require('x18n').debug(('mirror apply buf=%d notes=%d items=%d'):format(bufnr, vim.tbl_count(notes), #items))
  end
end

--- Remember a decorations reply and mirror the current warnings onto it.
---@param bufnr integer
---@param result table x18n/decorations reply
function M.render(bufnr, result)
  cache[bufnr] = result
  apply(bufnr)
end

--- Record one publishDiagnostics payload. A publish replaces the diagnostics of
--- its file, so the missing keys of that file are replaced too; the union over
--- the client's locale files drives the mirror.
---@param client_id integer
---@param uri string
---@param diagnostics table[] raw LSP diagnostics
function M.observe(client_id, uri, diagnostics)
  if not client_id or not uri then
    return
  end
  local keys = {}
  for _, d in ipairs(diagnostics or {}) do
    if d.code == 'missing-translation' then
      local key = d.data and d.data.key
      if not key and type(d.message) == 'string' then
        key = d.message:match('^"(.-)" is missing in ')
      end
      if key then
        keys[key] = d.message
      end
    end
  end
  missing[client_id] = missing[client_id] or {}
  missing[client_id][uri] = next(keys) and keys or nil
  if vim.g.x18n_debug then
    require('x18n').debug(('mirror observe client=%s uri=%s keys=%s cached=%s'):format(
      tostring(client_id), vim.fn.fnamemodify(vim.uri_to_fname(uri), ':t'), vim.tbl_count(keys), vim.tbl_count(cache)
    ))
  end
  for bufnr in pairs(cache) do
    apply(bufnr)
  end
end

--- Drop the mirror for one buffer (decorations off).
---@param bufnr integer
function M.clear(bufnr)
  cache[bufnr] = nil
  reset(bufnr)
end

function M.clear_all()
  for bufnr in pairs(cache) do
    reset(bufnr)
  end
  cache = {}
  missing = {}
end

--- Exposed for tests.
function M.namespace()
  return ns
end

return M
