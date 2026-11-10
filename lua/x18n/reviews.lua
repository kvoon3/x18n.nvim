local M = {}

local util = require 'x18n.util'
local lsp = require 'x18n.lsp'

--- The comment fields one queue row can show. Author and time are not useful
--- for recognition, so they stay at the protocol boundary.
---@class x18n.ReviewComment
---@field type string
---@field text string?
---@field suggestion string?
---@field value string?
---@field resolved boolean?

--- A review thread reduced to one queue entry.
---@class x18n.ReviewEntry
---@field project string
---@field key string
---@field locale string
---@field state string? nil when every comment is resolved
---@field comments x18n.ReviewComment[] oldest first, as the server returned them
---@field location { uri: string, range: table }? nil while the locale lacks the message

---@class x18n.ReviewOptions
---@field open boolean? true keeps only unresolved comments, and threads that have some

--- Parse one ReviewThreadInfo. The server already filtered and sorted; comments
--- arrive oldest first, so the newest is comments[#comments].
---@param raw table
---@return x18n.ReviewEntry
local function parse_thread(raw)
  local comments = {}
  for _, comment in ipairs(raw.comments or {}) do
    comments[#comments + 1] = {
      type = comment.type,
      text = comment.text,
      suggestion = comment.suggestion,
      value = comment.value,
      resolved = comment.resolved,
    }
  end
  return {
    project = raw.project,
    key = raw.key,
    locale = raw.locale,
    state = raw.state,
    comments = comments,
    location = raw.location,
  }
end

--- Protocol states with hyphens as spaces; nil means every comment is resolved.
---@param state string?
---@return string
local function state_label(state)
  if not state then
    return 'resolved'
  end
  return (state:gsub('%-', ' '))
end

local type_words = {
  comment = 'comment',
  approve = 'approved',
  suggestion = 'suggestion',
  ['request-change'] = 'change requested',
}

--- The newest comment in one line: its text when it has one, else the payload
--- of its type (suggestion value, approved value, "change requested", "comment").
---@param comment x18n.ReviewComment?
---@return string
local function comment_line(comment)
  if not comment then
    return ''
  end
  if comment.text and comment.text ~= '' then
    return (comment.text:gsub('[\r\n]+', ' '))
  end
  if comment.suggestion and comment.suggestion ~= '' then
    return 'suggestion: ' .. comment.suggestion
  end
  if comment.value and comment.value ~= '' then
    return 'approved ' .. comment.value
  end
  return type_words[comment.type] or comment.type or ''
end

--- "[state] key [locale] · newest comment[ (no location)]"
---@param entry x18n.ReviewEntry
---@return string
local function entry_text(entry)
  local text = ('[%s] %s [%s]'):format(state_label(entry.state), entry.key, entry.locale)
  local newest = entry.comments[#entry.comments]
  if newest then
    text = text .. ' · ' .. comment_line(newest)
  end
  if not entry.location then
    text = text .. ' (no location)'
  end
  return text
end

--- Located threads point at the locale key; locationless threads carry no
--- filename, so no item ever opens a broken position.
---@param entry x18n.ReviewEntry
---@return table quickfix item
local function quickfix_item(entry)
  local item = { text = entry_text(entry) }
  local location = entry.location
  if location then
    local path = vim.uri_to_fname(location.uri)
    local bufnr = vim.fn.bufadd(path)
    if vim.fn.bufloaded(bufnr) == 0 then
      vim.fn.bufload(bufnr)
    end
    local row, col = util.to_byte(bufnr, location.range.start)
    item.filename = path
    item.lnum = row + 1
    item.col = col + 1
  end
  return item
end

--- Replace the quickfix with these entries, in the order given. Empty input
--- notifies at WARN and leaves the existing list untouched.
---@param entries x18n.ReviewEntry[]
---@param opts x18n.ReviewOptions?
function M.show(entries, opts)
  opts = opts or {}
  if #entries == 0 then
    return require('x18n').notify(opts.open and 'no open review threads' or 'no review threads', vim.log.levels.WARN)
  end
  local items = {}
  for _, entry in ipairs(entries) do
    items[#items + 1] = quickfix_item(entry)
  end
  vim.fn.setqflist({}, ' ', {
    title = opts.open and 'x18n reviews (open)' or 'x18n reviews',
    items = items,
  })
  vim.cmd 'copen'
end

--- Fetch and list review threads. Project-level and read-only: no review
--- writes, no executeCommand.
---@param opts x18n.ReviewOptions?
---@return boolean started false when x18n is not running
function M.run(opts)
  opts = opts or {}
  local client = require('x18n').get_client()
  if not client then
    return false
  end
  lsp.custom_request(client, 'x18n/reviews', { open = opts.open or nil }, function(err, result)
    if err then
      return require('x18n').notify(err.message, vim.log.levels.WARN)
    end
    local entries = {}
    for _, raw in ipairs(result and result.threads or {}) do
      entries[#entries + 1] = parse_thread(raw)
    end
    vim.schedule(function()
      M.show(entries, opts)
    end)
  end)
  return true
end

return M
