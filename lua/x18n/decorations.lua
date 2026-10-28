local M = {}

local util = require 'x18n.util'

local ns = vim.api.nvim_create_namespace 'x18n_decoration'
local cfg = {}
local pending = {} -- bufnr -> uv timer
local retries = {} -- bufnr -> warm-up poll count

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

local function render(bufnr, result)
  if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end
  clear(bufnr)
  for _, d in ipairs(result and result.decorations or {}) do
    local line, col = util.to_byte(bufnr, d.expression['end'])
    local text = (d.value and d.value ~= '') and (' → ' .. d.value) or (' → ' .. (d.state or 'missing'))
    vim.api.nvim_buf_set_extmark(bufnr, ns, line, col, {
      virt_text = { { text, hl_for(d.state) } },
      virt_text_pos = cfg.virt_text_pos,
      hl_mode = 'combine',
    })
  end
end

--- Issue the decoration request for (bufnr, client) with debounce and warm-up retry.
--- The client is passed in: during LspAttach the buffer is not yet in the client's
--- attached list, so a get_clients({ bufnr }) lookup races and silently drops.
function M.request(bufnr, client)
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
      --[[ Right after LspAttach the server is still loading the project and answers
        with an empty locale; poll until the real (possibly also empty) payload lands. ]]
      if (result and result.locale or '') == '' and (retries[bufnr] or 0) < 5 then
        retries[bufnr] = (retries[bufnr] or 0) + 1
        vim.defer_fn(function()
          if pending[bufnr] == nil then
            M.request(bufnr, client)
          end
        end, 1000)
        return
      end
      retries[bufnr] = nil
      vim.schedule(function()
        render(bufnr, result)
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
    for _, bufnr in ipairs(vim.lsp.get_buffers_by_client_id(client.id)) do
      M.refresh(bufnr)
    end
  end
end

--- Exposed for tests.
function M.namespace()
  return ns
end

---@param opts {virt_text_pos: string, debounce_ms: integer}
function M.setup(opts)
  cfg = opts
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
      clear(a.buf)
    end,
  })
  aug('BufWritePost', { group = group, callback = function(a) M.refresh(a.buf) end })
  aug('TextChanged', { group = group, callback = function(a) M.refresh(a.buf) end })
  aug('InsertLeave', { group = group, callback = function(a) M.refresh(a.buf) end })
  aug('ColorScheme', { group = group, callback = define_highlights })
end

return M
