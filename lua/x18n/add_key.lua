local M = {}

local util = require 'x18n.util'
local lsp = require 'x18n.lsp'

local function cursor_params(bufnr)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  return {
    uri = vim.uri_from_bufnr(bufnr),
    position = { line = row - 1, character = util.to_utf16(bufnr, row - 1, col) },
  }
end

---@alias x18n.Write {locale: string, value: string}

---@class x18n.WriteQueue
---@field client vim.lsp.Client
---@field key string
---@field project string?
---@field writes x18n.Write[]
---@field next integer

---@param queue x18n.WriteQueue
local function pump(queue)
  local write = queue.writes[queue.next]
  if not write then
    return require('x18n').notify(
      ('added %s to %d locale(s) — unsaved buffers, review and save'):format(queue.key, #queue.writes)
    )
  end
  queue.client:request('workspace/executeCommand', {
    command = 'x18n.set',
    arguments = {
      {
        project = queue.project,
        key = queue.key,
        locale = write.locale,
        value = write.value,
      },
    },
  }, function(err)
    if err then
      return require('x18n').notify(err.message, vim.log.levels.WARN)
    end
    queue.next = queue.next + 1
    pump(queue)
  end)
end

---@param writes x18n.Write[]
---@param key string
---@param project string?
local function write(writes, key, project)
  if #writes == 0 then
    return require('x18n').notify 'nothing to write'
  end
  local client = require('x18n').get_client()
  if not client then
    return
  end
  pump { client = client, key = key, project = project, writes = writes, next = 1 }
end

local function resolve_key(key_arg)
  if key_arg and key_arg ~= '' then
    return key_arg, nil
  end
  local client = require('x18n').get_client()
  if not client then
    return nil
  end
  local key, project
  local done = false
  lsp.custom_request(client, 'x18n/keyAt', cursor_params(vim.api.nvim_get_current_buf()), function(err, result)
    if not err and result then
      key, project = result.key, result.project
    end
    done = true
  end)
  vim.wait(2000, function()
    return done
  end, 50)
  return key, project
end

local function is_undefined(key, project)
  local client = require('x18n').client()
  if not client then
    return false
  end
  local found = false
  local done = false
  lsp.custom_request(client, 'x18n/usageReport', {}, function(err, result)
    if not err then
      for _, entry in ipairs(result and result.missing or {}) do
        if entry.key == key and (project == nil or entry.project == project) then
          found = true
          break
        end
      end
    end
    done = true
  end)
  vim.wait(2000, function()
    return done
  end, 50)
  return found
end

local function key_exists(key, project)
  local client = require('x18n').client()
  if not client then
    return false
  end
  local parent = key:match '^(.*)%.'
  local found, done = false, false
  lsp.custom_request(client, 'x18n/tree', { project = project, parent = parent }, function(err, result)
    if not err then
      for _, node in ipairs(result or {}) do
        if node.key == key then
          found = true
          break
        end
      end
    end
    done = true
  end)
  vim.wait(2000, function()
    return done
  end, 50)
  return found
end

local function key_is_taken(key, project, explicit)
  if explicit then
    return key_exists(key, project)
  end
  return not is_undefined(key, project)
end

--- Ask for one value and write it to a single locale. Used by the code action,
--- which is why the prompt is client-side rather than part of the edit.
---@param key string
---@param locale string
function M.add_one(key, locale)
  if not key or not locale then
    return
  end
  local project
  local client = require('x18n').client()
  if client then
    local done, result = false, nil
    lsp.custom_request(client, 'x18n/keyAt', cursor_params(vim.api.nvim_get_current_buf()), function(err, res)
      result = not err and res or nil
      done = true
    end)
    vim.wait(2000, function()
      return done
    end, 25)
    if result and result.key == key then
      project = result.project
    end
  end
  vim.ui.input({ prompt = ('%s [%s] '):format(key, locale), default = '' }, function(value)
    if value and value ~= '' then
      write({ { locale = locale, value = value } }, key, project)
    end
  end)
end

--- Ask for one value per locale, source first, and write each with x18n.set.
--- Empty input skips the locale; every locale empty aborts without writing.
---@param key_arg string?
function M.run(key_arg)
  local init = require 'x18n'
  local client = init.get_client()
  if not client then
    return
  end
  local key, project = resolve_key(key_arg)
  if not key then
    return init.notify 'no i18n key under the cursor'
  end
  if key_is_taken(key, project, key_arg and key_arg ~= '') then
    return init.notify(("'%s' is already defined — edit it in the locale files"):format(key), vim.log.levels.WARN)
  end

  local locales = require('x18n.locales').locales()
  if #locales == 0 then
    return init.notify 'no locales known'
  end

  local writes = {}
  local function ask(i)
    if i > #locales then
      return write(writes, key, project)
    end
    vim.ui.input({
      prompt = ('%s [%s] '):format(key, locales[i]),
      default = '',
    }, function(value)
      if value and value ~= '' then
        writes[#writes + 1] = { locale = locales[i], value = value }
      end
      ask(i + 1)
    end)
  end
  ask(1)
end

return M
