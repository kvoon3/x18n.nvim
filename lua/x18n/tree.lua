local M = {}

local lsp = require 'x18n.lsp'

--- One namespace the user drilled into.
---@class x18n.TreeParent
---@field key string   -- full key exactly as x18n/tree returned it; never the label
---@field label string -- last segment, breadcrumb only

--- One drill-down session. Sessions never share state: two open trees cannot
--- corrupt each other.
---@class x18n.TreeSession
---@field client vim.lsp.Client
---@field project string?          -- nil selects the server's default project
---@field root string?             -- project root, used to disambiguate symbols
---@field trail x18n.TreeParent[]  -- ancestor stack; empty at the roots

--- One server child reduced to the fields this surface draws.
---@class x18n.TreeChild
---@field key string
---@field label string
---@field leaf boolean
---@field translated integer
---@field total integer
---@field value string?

local up = { label = '.. (up)', up = true }

--- Reduce a TreeNode at the protocol boundary. A node without a string key is
--- dropped: every later request and jump needs that key.
---@param raw table
---@return x18n.TreeChild?
local function parse_child(raw)
  if type(raw) ~= 'table' or type(raw.key) ~= 'string' then
    return nil
  end
  return {
    key = raw.key,
    label = type(raw.label) == 'string' and raw.label or raw.key,
    leaf = raw.leaf == true,
    translated = tonumber(raw.translated) or 0,
    total = tonumber(raw.total) or 0,
    value = type(raw.value) == 'string' and raw.value or nil,
  }
end

--- Collapse a display value to one line; nil or empty becomes an em dash.
---@param value string?
---@return string
local function value_text(value)
  if value == nil or value == '' then
    return '—'
  end
  return (value:gsub('[\r\n]+', ' '))
end

--- One row. The label is the server's last segment, so keySeparator:false
--- projects keep their own spelling; the client never splits a key.
---@param child x18n.TreeChild
---@return string
local function child_text(child)
  local progress = ('(%d/%d)'):format(child.translated, child.total)
  if child.leaf then
    return ('%s = %s  %s'):format(child.label, value_text(child.value), progress)
  end
  return ('▸ %s  %s'):format(child.label, progress)
end

---@param row table
---@return string
local function row_text(row)
  if row.up then
    return row.label
  end
  return child_text(row)
end

--- "x18n tree" at the roots, "x18n tree: app / settings" below.
---@param session x18n.TreeSession
---@return string
local function breadcrumb(session)
  if #session.trail == 0 then
    return 'x18n tree'
  end
  local labels = {}
  for _, parent in ipairs(session.trail) do
    labels[#labels + 1] = parent.label
  end
  return 'x18n tree: ' .. table.concat(labels, ' / ')
end

---@param uri string
---@param root string
---@return boolean
local function under_root(uri, root)
  local path = vim.uri_to_fname(uri)
  root = root:gsub('/+$', '')
  return path == root or path:sub(1, #root + 1) == root .. '/'
end

--- Resolve a leaf without a source position. workspace/symbol is the only
--- project-level key -> location mapping; take the exact name match and let
--- util.jump convert the UTF-16 range.
---@param session x18n.TreeSession
---@param key string
local function open_leaf(session, key)
  session.client:request('workspace/symbol', { query = key }, function(err, result)
    if err then
      return require('x18n').notify(err.message, vim.log.levels.WARN)
    end
    local chosen
    for _, symbol in ipairs(result or {}) do
      if symbol.name == key and symbol.location then
        if not chosen then
          chosen = symbol
        end
        if session.root and under_root(symbol.location.uri, session.root) then
          chosen = symbol
          break
        end
      end
    end
    if not chosen then
      return require('x18n').notify('no definition for ' .. key, vim.log.levels.WARN)
    end
    local locales = require 'x18n.locales'
    locales.key_locations(session.client, chosen.location.uri, chosen.location.range.start, function(pairs)
      local target = locales.location_for(pairs)
      if not target then
        return require('x18n').notify('no definition for ' .. key, vim.log.levels.WARN)
      end
      vim.schedule(function()
        require('x18n.util').jump(target)
      end)
    end)
  end)
end

--- Fetch one level and offer it with vim.ui.select. `trail` is prospective:
--- it is committed only after children arrive, so an error or an empty level
--- ends the drill without leaving a phantom ancestor.
---@param session x18n.TreeSession
---@param trail x18n.TreeParent[]
local function open_level(session, trail)
  local parent = trail[#trail] and trail[#trail].key or nil
  lsp.custom_request(session.client, 'x18n/tree', {
    project = session.project,
    parent = parent,
  }, function(err, result)
    if err then
      return require('x18n').notify(err.message, vim.log.levels.WARN)
    end
    local children = {}
    for _, raw in ipairs(result or {}) do
      local child = parse_child(raw)
      if child then
        children[#children + 1] = child
      end
    end
    vim.schedule(function()
      if #children == 0 then
        if parent then
          return require('x18n').notify('no keys under ' .. parent, vim.log.levels.WARN)
        end
        return require('x18n').notify('no keys indexed', vim.log.levels.WARN)
      end
      session.trail = trail
      local rows = {}
      if #trail > 0 then
        rows[1] = up
      end
      for _, child in ipairs(children) do
        rows[#rows + 1] = child
      end
      vim.ui.select(rows, {
        prompt = breadcrumb(session),
        format_item = row_text,
      }, function(choice)
        if not choice then
          return
        end
        if choice.up then
          local parent_trail = {}
          for i = 1, #trail - 1 do
            parent_trail[i] = trail[i]
          end
          return open_level(session, parent_trail)
        end
        if choice.leaf then
          return open_leaf(session, choice.key)
        end
        local next_trail = {}
        for i, entry in ipairs(trail) do
          next_trail[i] = entry
        end
        next_trail[#next_trail + 1] = { key = choice.key, label = choice.label }
        open_level(session, next_trail)
      end)
    end)
  end)
end

--- Open the key tree at its roots and let the user drill in. Project-level:
--- works from a buffer the server never attached to.
---@param project string? server project name; nil uses the server default
---@return boolean started false when x18n is not running or the project is unknown
function M.open(project)
  local client = require('x18n').get_client()
  if not client then
    return false
  end
  local projects = require('x18n.locales').projects()
  local selected
  if project and project ~= '' then
    for _, candidate in ipairs(projects or {}) do
      if candidate.name == project then
        selected = candidate
        break
      end
    end
    if not selected then
      require('x18n').notify('unknown project ' .. project, vim.log.levels.WARN)
      return false
    end
  elseif projects and projects[1] then
    selected = projects[1]
  end
  local session = {
    client = client,
    project = selected and selected.name or nil,
    root = selected and selected.root or nil,
    trail = {},
  }
  open_level(session, {})
  return true
end

return M
