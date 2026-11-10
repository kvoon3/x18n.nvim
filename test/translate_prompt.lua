local ctx = ...
local prompt = require 'x18n.translate_prompt'
local actions = require 'x18n.actions'
local locales = require 'x18n.locales'

local notes = {}
vim.notify = function(msg, level)
  notes[#notes + 1] = { msg = msg, level = level }
end

local function clear()
  notes = {}
  vim.fn.setreg('"', '')
  vim.fn.setreg('+', '')
end

local function cursor_onto(buf, pattern)
  for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local col = line:find(pattern, 1, false)
    if col then
      vim.api.nvim_win_set_cursor(0, { i, col - 1 })
      return true
    end
  end
  return false
end

local function wait_register()
  return ctx.wait_for(function()
    return vim.fn.getreg '"' ~= ''
  end, 8000)
end

local function wait_note(pattern)
  return ctx.wait_for(function()
    local note = notes[#notes]
    return note ~= nil and note.msg:find(pattern, 1, true) ~= nil
  end, 8000)
end

local function missing_in_ja()
  local client = vim.lsp.get_clients({ name = 'x18n' })[1]
  if not client then
    return false
  end
  local done, missing = false, false
  require('x18n.lsp').custom_request(client, 'x18n/progress', {}, function(err, result)
    if not err then
      for _, project in ipairs(result and result.projects or {}) do
        for _, locale in ipairs(project.locales or {}) do
          if locale.locale == 'ja' then
            for _, key in ipairs(locale.missing or {}) do
              if key == 'app.title' then
                missing = true
              end
            end
          end
        end
      end
    end
    done = true
  end)
  vim.wait(2000, function()
    return done
  end, 25)
  return missing
end

actions.set_display_locale 'ja'
assert(
  ctx.wait_for(function()
    return locales.display_locale() == 'ja'
  end, 3000),
  'display locale did not switch to ja'
)
assert(cursor_onto(ctx.buf, 'app%.title'), 'fixture lost the app.title call')

clear()
assert(prompt.copy() == true, 'narrowed copy did not start')
assert(wait_register(), 'narrowed copy never filled the register')
local text = vim.fn.getreg '"'
assert(text:find('# Translate 1 messages from en to ja', 1, true), 'narrowed prompt header wrong: ' .. text:sub(1, 120))
assert(text:find('app.title', 1, true), 'narrowed prompt lost the key')
assert(text:find('Hello x18n', 1, true), 'narrowed prompt lost the source value')
assert(text:find('こんにちは x18n', 1, true), 'narrowed prompt lost the target value')
assert(vim.fn.getreg '+' == text, 'plus register differs from the unnamed register')
assert(wait_note 'copied ja translate prompt for app.title', 'narrowed copy notify wrong')

vim.cmd 'enew'
clear()
assert(prompt.copy() == true, 'whole-project copy did not start')
assert(wait_note 'nothing to translate to ja', 'nothing-to-do did not warn')
assert(notes[#notes].level == vim.log.levels.WARN, 'nothing-to-do did not warn at WARN')
assert(not notes[#notes].msg:find(' for app', 1, true), 'nothing-to-do named a key')
assert(vim.fn.getreg '"' == '' and vim.fn.getreg '+' == '', 'nothing-to-do touched the registers')

vim.cmd('edit ' .. ctx.playground .. '/src/main.js')
assert(cursor_onto(ctx.buf, 'app%.title'), 'fixture lost app.title after the buffer switch')
clear()
assert(prompt.copy 'fr' == true, 'explicit fr did not start')
assert(wait_register(), 'explicit fr never filled the register')
text = vim.fn.getreg '"'
assert(text:find('# Translate 1 messages from en to fr', 1, true), 'explicit fr header wrong')
assert(wait_note 'copied fr translate prompt for app.title', 'explicit fr notify wrong')

clear()
assert(prompt.copy 'en' == false, 'source locale was accepted')
assert(vim.fn.getreg '"' == '' and vim.fn.getreg '+' == '', 'source locale touched the registers')
assert(wait_note 'cannot translate to the source locale en', 'source locale did not warn')
assert(notes[#notes].level == vim.log.levels.WARN, 'source locale did not warn at WARN')

clear()
assert(prompt.copy 'xx' == false, 'unknown locale was accepted')
assert(vim.fn.getreg '"' == '' and vim.fn.getreg '+' == '', 'unknown locale touched the registers')
assert(wait_note 'unknown locale xx', 'unknown locale did not warn')
assert(notes[#notes].msg:find('fr, ja, zh-CN', 1, true), 'unknown locale did not list the target locales')

actions.set_display_locale 'en'
assert(
  ctx.wait_for(function()
    return locales.display_locale() == 'en'
  end, 3000),
  'display locale did not switch to en'
)
clear()
assert(cursor_onto(ctx.buf, 'app%.title'), 'fixture lost app.title for the fallback')
assert(prompt.copy() == true, 'display-source fallback did not start')
assert(wait_register(), 'display-source fallback never filled the register')
text = vim.fn.getreg '"'
assert(text:find('# Translate 1 messages from en to fr', 1, true), 'display-source fallback did not pick fr')
assert(wait_note 'copied fr translate prompt for app.title', 'display-source fallback notify wrong')

actions.set_display_locale 'ja'
assert(
  ctx.wait_for(function()
    return locales.display_locale() == 'ja'
  end, 3000),
  'display locale did not return to ja'
)
vim.cmd('edit ' .. ctx.playground .. '/locales/en.json')
vim.cmd 'filetype detect'
local enbuf = vim.api.nvim_get_current_buf()
assert(
  ctx.wait_for(function()
    return vim.lsp.get_clients({ bufnr = enbuf, name = 'x18n' })[1] ~= nil
  end, 8000),
  'server did not attach to en.json'
)
assert(cursor_onto(enbuf, 'title'), 'en.json lost the title key')
clear()
assert(prompt.copy() == true, 'locale-file copy did not start')
assert(wait_register(), 'locale-file copy never filled the register')
text = vim.fn.getreg '"'
assert(text:find('# Translate 1 messages from en to ja', 1, true), 'locale-file prompt header wrong')
assert(text:find('app.title', 1, true), 'locale-file prompt lost the narrowed key')
assert(wait_note 'copied ja translate prompt for app.title', 'locale-file notify wrong')

assert(cursor_onto(enbuf, 'app'), 'en.json lost the app parent')
clear()
assert(prompt.copy() == true, 'subtree copy did not start')
assert(wait_note 'nothing to translate to ja', 'subtree copy did not warn')
assert(not notes[#notes].msg:find(' for ', 1, true), 'subtree narrowed the prompt')
assert(vim.fn.getreg '"' == '' and vim.fn.getreg '+' == '', 'subtree copy touched the registers')

vim.cmd('edit ' .. ctx.playground .. '/locales/ja.json')
local jabuf = vim.api.nvim_get_current_buf()
assert(
  ctx.wait_for(function()
    return vim.lsp.get_clients({ bufnr = jabuf, name = 'x18n' })[1] ~= nil
  end, 8000),
  'server did not attach to ja.json'
)
local lines = vim.api.nvim_buf_get_lines(jabuf, 0, -1, false)
local kept = {}
for _, line in ipairs(lines) do
  if not line:find('"title"', 1, true) then
    kept[#kept + 1] = line
  end
end
assert(#kept == #lines - 1, 'ja.json lost its title line')
vim.api.nvim_buf_set_lines(jabuf, 0, -1, false, kept)
vim.cmd 'write'
assert(ctx.wait_for(missing_in_ja, 15000), 'server never reported app.title missing from ja')

vim.cmd 'enew'
clear()
assert(prompt.copy() == true, 'mutated whole-project copy did not start')
assert(wait_register(), 'mutated whole-project copy never filled the register')
text = vim.fn.getreg '"'
assert(text:find('# Translate 1 messages from en to ja', 1, true), 'whole-project prompt header wrong')
assert(text:find('app.title', 1, true), 'whole-project prompt lost the missing key')
assert(wait_note 'copied ja translate prompt', 'whole-project notify wrong')
assert(not notes[#notes].msg:find(' for ', 1, true), 'whole-project notify named a key')

clear()
require('x18n.lsp').stop()
assert(
  ctx.wait_for(function()
    return #vim.lsp.get_clients { name = 'x18n' } == 0
  end, 5000),
  'server did not stop'
)
assert(prompt.copy() == false, 'copy started without a client')
assert(vim.fn.getreg '"' == '' and vim.fn.getreg '+' == '', 'missing client touched the registers')
assert(wait_note 'x18n-lsp is not running', 'missing client did not warn')
assert(notes[#notes].level == vim.log.levels.WARN, 'missing client did not warn at WARN')
print 'translate prompt ok'
