local M = {}

local util = require 'x18n.util'
local locales = require 'x18n.locales'

local function list(client, on_result)
  client:request('workspace/symbol', { query = '' }, function(err, result)
    if err then
      return require('x18n').notify(err.message, vim.log.levels.WARN)
    end
    local entries = {}
    for _, sym in ipairs(result or {}) do
      entries[#entries + 1] = {
        key = sym.name,
        value = sym.containerName or '',
        location = sym.location,
      }
      if #entries == 500 then
        require('x18n').notify 'showing the first 500 keys'
        break
      end
    end
    vim.schedule(function()
      on_result(entries)
    end)
  end)
end

local function key_info(client, entry, on_result)
  if not entry.location then
    return on_result(nil)
  end
  locales.key_info(client, entry.location.uri, entry.location.range.start, on_result)
end

local function locale_locations(client, entry, on_result)
  if not entry.location then
    return on_result({}, nil)
  end
  locales.key_locations(client, entry.location.uri, entry.location.range.start, on_result)
end

local function notify(msg, level)
  require('x18n').notify(msg, level)
end

local function jump(entry, client, open_cmd)
  locale_locations(client, entry, function(pairs)
    local target = locales.location_for(pairs) or entry.location
    if target then
      util.jump(target, open_cmd)
    else
      notify('no definition for ' .. entry.key, vim.log.levels.WARN)
    end
  end)
end

local function copy(text, what)
  vim.fn.setreg('"', text)
  vim.fn.setreg('+', text)
  notify(('copied %s %s'):format(what, text))
end

local actions = {
  --- Jump to the display-locale definition, falling back to the source.
  jump = function(entry, client)
    jump(entry, client)
  end,
  split = function(entry, client)
    jump(entry, client, 'split')
  end,
  vsplit = function(entry, client)
    jump(entry, client, 'vsplit')
  end,
  tab = function(entry, client)
    jump(entry, client, 'tabedit')
  end,
  --- Copy the key, e.g. to paste into a t('...') call.
  copy_key = function(entry)
    copy(entry.key, 'key')
  end,
  --- Copy the display-locale translation.
  copy_translation = function(entry, client)
    key_info(client, entry, function(info)
      if not info then
        return notify('copy_translation needs x18n/keyInfo (kvoon3/x18n fork)', vim.log.levels.WARN)
      end
      local display = locales.display_locale()
      if not display then
        for _, locale in ipairs(info.locales or {}) do
          if locale.source then
            display = locale.code
            break
          end
        end
      end
      local chosen
      for _, locale in ipairs(info.locales or {}) do
        if locale.code == display then
          chosen = locale
          break
        end
      end
      local text = chosen and chosen.value
      if text == nil or text == '' then
        return notify(('no %s translation for %s'):format(display or 'source', entry.key), vim.log.levels.WARN)
      end
      copy(text, (display or 'source') .. ' value')
    end)
  end,
  --- Pick a locale, then jump to the key in that locale's file.
  choose_locale = function(entry, client)
    locale_locations(client, entry, function(pairs)
      if #pairs == 0 then
        return notify('no locale definitions for ' .. entry.key, vim.log.levels.WARN)
      end
      local by_code = {}
      local has_codes = false
      for _, pair in ipairs(pairs) do
        if pair.code then
          has_codes = true
          by_code[pair.code] = pair.location
        end
      end
      local items = {}
      if has_codes then
        local codes = locales.cached()
        if #codes == 0 then
          locales.warm()
          for _, pair in ipairs(pairs) do
            if pair.code then
              codes[#codes + 1] = pair.code
            end
          end
        end
        for _, code in ipairs(codes) do
          items[#items + 1] = { code = code, location = by_code[code] }
        end
      else
        for _, pair in ipairs(pairs) do
          items[#items + 1] = {
            code = vim.fn.fnamemodify(vim.uri_to_fname(pair.location.uri), ':t'),
            location = pair.location,
          }
        end
      end
      vim.ui.select(items, {
        prompt = 'x18n key locale',
        format_item = function(item)
          return item.code .. (item.location and ' ✔' or ' ✖')
        end,
      }, function(choice)
        if not choice then
          return
        end
        if not choice.location then
          return notify(('no %s definition for %s'):format(choice.code, entry.key), vim.log.levels.WARN)
        end
        util.jump(choice.location)
      end)
    end)
  end,
}

M.actions = { 'jump', 'split', 'vsplit', 'tab', 'copy_key', 'copy_translation', 'choose_locale' }

--- Pick from all keys; the chosen action runs against the selection.
---@param action string? jump, split, vsplit, tab, copy_key, copy_translation or choose_locale
function M.pick(action)
  action = action or 'jump'
  if action == 'copy' then
    action = 'copy_key'
  end
  if not actions[action] then
    return notify('unknown key action: ' .. action, vim.log.levels.WARN)
  end
  local client = require('x18n').get_client()
  if not client then
    return
  end
  list(client, function(entries)
    if #entries == 0 then
      return notify 'no keys indexed'
    end
    vim.ui.select(entries, {
      prompt = 'x18n keys',
      format_item = function(entry)
        return ('%s = %s'):format(entry.key, entry.value)
      end,
    }, function(choice)
      if choice then
        actions[action](choice, client)
      end
    end)
  end)
end

return M
