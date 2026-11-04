-- Display modes: i18n.nvim's four names plus the local ones, the cursor-line
-- rule for each, and the two toggle transition tables.
local ctx = ...
local decorations = require 'x18n.decorations'
local ns = decorations.namespace()

decorations.setup { mode = 'conceal', debounce_ms = 100, cursor_redraw_ms = 20 }
decorations.refresh_attached()

local function row_of(pattern)
  for i, l in ipairs(vim.api.nvim_buf_get_lines(ctx.buf, 0, -1, false)) do
    if l:find(pattern) then
      return i - 1
    end
  end
  error('no row matches ' .. pattern)
end

local greeting = row_of 'app%.title'

local function shape(row)
  local out = { conceal = 0, inline_value = nil, eol_value = nil }
  for _, m in ipairs(vim.api.nvim_buf_get_extmarks(ctx.buf, ns, 0, -1, { details = true })) do
    if m[2] == row then
      local d = m[4]
      if d.conceal ~= nil then
        out.conceal = out.conceal + 1
      end
      if d.virt_text and d.virt_text_pos == 'inline' then
        out.inline_value = d.virt_text[1][1]
      end
      if d.virt_text and d.virt_text_pos == 'eol' then
        out.eol_value = d.virt_text[1][1]
      end
    end
  end
  return out
end

local function total_marks()
  return #vim.api.nvim_buf_get_extmarks(ctx.buf, ns, 0, -1, {})
end

local function wait_shape(mode, want)
  assert(
    ctx.wait_for(function()
      local s = shape(greeting)
      for k, v in pairs(want) do
        if s[k] ~= v then
          return false
        end
      end
      return true
    end, 8000),
    mode .. ' never rendered: ' .. vim.inspect(shape(greeting))
  )
end

-- Cursor away from every key: line 1.
vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.api.nvim_exec_autocmds('CursorMoved', { buffer = ctx.buf })
assert(
  ctx.wait_for(function()
    return total_marks() > 0 and shape(greeting).conceal == 1
  end, 10000),
  'baseline conceal never rendered'
)

decorations.set_mode 'both'
wait_shape('both', { conceal = 0, inline_value = ' → Hello x18n' })
assert(vim.wo.conceallevel == 0, 'both left conceallevel raised')

decorations.set_mode 'translation'
wait_shape('translation', { conceal = 1, inline_value = 'Hello x18n' })
assert(vim.wo.conceallevel == 2, 'translation did not raise conceallevel')

decorations.set_mode 'translation_conceal'
wait_shape('translation_conceal', { conceal = 1, inline_value = 'Hello x18n' })
assert(vim.wo.conceallevel == 2, 'translation_conceal did not raise conceallevel')

decorations.set_mode 'origin'
assert(
  ctx.wait_for(function()
    return total_marks() == 0
  end, 8000),
  'origin kept decorations: ' .. total_marks()
)
assert(vim.wo.conceallevel == 0, 'origin left conceallevel raised')

decorations.set_mode 'eol'
wait_shape('eol', { conceal = 0, eol_value = ' → Hello x18n' })
assert(vim.wo.conceallevel == 0, 'eol left conceallevel raised')

-- Cursor line rules.
vim.api.nvim_win_set_cursor(0, { greeting + 1, 10 })
vim.api.nvim_exec_autocmds('CursorMoved', { buffer = ctx.buf })

decorations.set_mode 'translation'
wait_shape('translation cursor', { conceal = 1, inline_value = ' → Hello x18n' })

decorations.set_mode 'translation_conceal'
assert(
  ctx.wait_for(function()
    local s = shape(greeting)
    return s.conceal == 1 and s.inline_value == nil and s.eol_value == nil
  end, 8000),
  'translation_conceal cursor line is not raw: ' .. vim.inspect(shape(greeting))
)

decorations.set_mode 'conceal'
wait_shape('conceal cursor', { conceal = 1, eol_value = '→ Hello x18n' })

decorations.set_mode 'both'
wait_shape('both cursor', { conceal = 0, inline_value = ' → Hello x18n' })

-- Toggle transitions, mirroring i18n.nvim.
decorations.set_mode 'both'
assert(decorations.toggle_origin() == 'translation_conceal', 'both did not toggle origin off')
assert(decorations.toggle_origin() == 'both', 'translation_conceal did not toggle origin on')

decorations.set_mode 'translation'
assert(decorations.toggle_origin() == 'both', 'translation did not toggle origin on')
decorations.set_mode 'translation'
assert(decorations.toggle_translation() == 'origin', 'translation did not toggle to origin')
assert(decorations.toggle_translation() == 'translation', 'origin did not restore translation')

decorations.set_mode 'both'
assert(decorations.toggle_translation() == 'origin', 'both did not toggle to origin')
assert(
  decorations.toggle_origin() == 'translation_conceal',
  'origin with last both did not land on translation_conceal'
)

local before = decorations.get_mode()
assert(decorations.set_mode 'nope' == before, 'invalid mode changed the mode')
assert(decorations.get_mode() == before, 'invalid mode mutated get_mode')

decorations.set_mode 'conceal'
print 'modes ok'
