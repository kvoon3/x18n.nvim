local repo = assert(vim.env.X18N_VERIFY_REPO, 'X18N_VERIFY_REPO is required')
local project_name = assert(vim.env.X18N_VERIFY_PROJECT, 'X18N_VERIFY_PROJECT is required')
local only_locale = vim.env.X18N_VERIFY_LOCALE
if only_locale == '' then
  only_locale = nil
end
local out_dir = assert(vim.env.X18N_VERIFY_OUT, 'X18N_VERIFY_OUT is required')
local tmp_root = assert(vim.env.X18N_VERIFY_TMP, 'X18N_VERIFY_TMP is required')

local script_dir = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h')
local manifest = dofile(script_dir .. '/playgrounds.lua')

local entry
for _, item in ipairs(manifest) do
  if item.name == project_name then
    entry = item
    break
  end
end
assert(entry, 'playground "' .. project_name .. '" is not in scripts/playgrounds.lua')

vim.opt.runtimepath:prepend(repo)
vim.notify = function() end
vim.diagnostic.config { virtual_text = false, signs = false, underline = false }
require('x18n').setup {
  lsp = {
    cmd = { 'node', repo .. '/node_modules/@x18n/lsp/bin.mjs', '--stdio' },
    root_markers = entry.markers,
  },
  decorations = { mode = 'conceal' },
}
vim.o.laststatus = 0
vim.o.cmdheight = 0
vim.o.showtabline = 0

local util = require 'x18n.util'

local md = {}
local checks = {}
local failures = 0
local done = false
local timer

local function add_check(check)
  checks[#checks + 1] = check
  if check.status == 'FAIL' then
    failures = failures + 1
  end
end

local function fail(feature, file, locale, message, extra)
  add_check {
    feature = feature,
    file = file,
    locale = locale,
    status = 'FAIL',
    message = message,
    extra = extra,
  }
end

local function wait_for(cond, ms)
  local expired = vim.uv.now() + (ms or 10000)
  while vim.uv.now() < expired do
    if cond() then
      return true
    end
    vim.wait(100, cond, 50)
    vim.cmd 'redraw'
  end
  return cond()
end

local function request(client, method, params, ms)
  local answered, result, err = false, nil, nil
  client:request(method, params, function(e, r)
    err = e
    result = r
    answered = true
  end)
  vim.wait(ms or 5000, function()
    return answered
  end, 25)
  if not answered then
    return nil, 'no answer to ' .. method
  end
  return result, err
end

local function screen_text(row)
  local chars = {}
  for col = 1, vim.o.columns do
    chars[#chars + 1] = vim.fn.screenstring(row, col)
  end
  return (table.concat(chars):gsub('%s+$', ''))
end

local function trim(text)
  return (text or ''):gsub('%s+$', '')
end

local function quoted_range(bufnr, range)
  local s_line, s_col = util.to_byte(bufnr, range.start)
  local e_line, e_col = util.to_byte(bufnr, range['end'])
  if s_line ~= e_line then
    return s_line, s_col, e_line, e_col
  end
  local line = vim.api.nvim_buf_get_lines(bufnr, s_line, s_line + 1, false)[1] or ''
  local before = line:sub(s_col, s_col)
  local after = line:sub(e_col + 1, e_col + 1)
  if before:match '[\'"`]' and after:match '[\'"`]' then
    s_col = s_col - 1
    e_col = e_col + 1
  end
  return s_line, s_col, e_line, e_col
end

local function missing_suppressed(bufnr, d)
  if d.state ~= 'missing' or not d.range then
    return false
  end
  for _, diag in ipairs(vim.diagnostic.get(bufnr)) do
    if
      diag.lnum == d.range.start.line
      and diag.source == 'x18n'
      and (diag.code == 'missing-key' or (diag.user_data and type(diag.user_data) == 'table' and diag.user_data.key))
    then
      return true
    end
  end
  return false
end

local function expected_lines(bufnr, decorations)
  local per_line = {}
  for _, d in ipairs(decorations or {}) do
    if d.range and not missing_suppressed(bufnr, d) then
      --[[ Buffer line numbers in the API and screenpos are 1-based; the LSP
        range is 0-based. ]]
      local line = d.range.start.line + 1
      local _, s_col, _, e_col = quoted_range(bufnr, d.range)
      local op
      if d.state == 'ok' and d.value and d.value ~= '' then
        op = {
          col = s_col,
          end_col = e_col,
          text = d.value,
          key = d.key,
          state = d.state,
          feature = 'inline-translations,display-locale',
        }
      else
        local expression = d.expression or d.range
        local _, x_col = util.to_byte(bufnr, expression['end'])
        local text = (d.value and d.value ~= '') and (' → ' .. d.value) or (' → ' .. (d.state or 'missing'))
        op = {
          col = x_col,
          end_col = x_col,
          text = text,
          key = d.key,
          state = d.state or 'missing',
          feature = 'inline-translations,display-locale,missing-and-dynamic',
        }
      end
      per_line[line] = per_line[line] or {}
      per_line[line][#per_line[line] + 1] = op
    end
  end

  local expected, ops_by_line = {}, {}
  for line, ops in pairs(per_line) do
    table.sort(ops, function(a, b)
      if a.col == b.col then
        return a.end_col < b.end_col
      end
      return a.col < b.col
    end)
    local raw = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1] or ''
    local out, pos = {}, 1
    local overlap = false
    for _, op in ipairs(ops) do
      if op.col < pos - 1 then
        overlap = true
        break
      end
      out[#out + 1] = raw:sub(pos, op.col)
      out[#out + 1] = op.text
      pos = op.end_col + 1
    end
    if not overlap then
      out[#out + 1] = raw:sub(pos)
      expected[line] = table.concat(out)
      ops_by_line[line] = ops
    end
  end
  return expected, ops_by_line
end

local function project_for(projects, path)
  local real = vim.uv.fs_realpath(path) or path
  local best
  for _, project in ipairs(projects or {}) do
    local root = vim.uv.fs_realpath(project.root) or project.root
    if real:sub(1, #root + 1) == root .. '/' and (not best or #root > #best._root) then
      best = project
      best._root = root
    end
  end
  return best
end

local function locale_codes(project)
  local out = {}
  for _, locale in ipairs(project and project.locales or {}) do
    out[#out + 1] = locale.code
  end
  return out
end

local function cli_status(root)
  local result = vim
    .system({
      repo .. '/node_modules/.bin/x18n',
      'status',
      '--root',
      root,
      '--json',
    }, { text = true })
    :wait(20000)
  if result.code ~= 0 then
    return nil, (result.stderr or ''):gsub('%s+$', '')
  end
  local ok, data = pcall(vim.json.decode, result.stdout)
  if not ok or not data.data or not data.data.projects then
    return nil, 'status returned invalid JSON'
  end
  local keys, usages, resources, locales = 0, 0, 0, {}
  for _, project in ipairs(data.data.projects) do
    keys = keys + (project.keys or 0)
    usages = usages + (project.usages or 0)
    resources = resources + (project.resources or 0)
    for _, locale in ipairs(project.locales or {}) do
      locales[#locales + 1] = locale.locale
    end
  end
  return { keys = keys, usages = usages, resources = resources, locales = table.concat(locales, ',') }
end

local function cli_value(root, key, locale)
  local result = vim
    .system({
      repo .. '/node_modules/.bin/x18n',
      'get',
      key,
      '--root',
      root,
      '--json',
    }, { text = true })
    :wait(20000)
  if result.code ~= 0 then
    return nil, (result.stderr or ''):gsub('%s+$', '')
  end
  local ok, data = pcall(vim.json.decode, result.stdout)
  if not ok or not data.data or not data.data.projects then
    return nil, 'get returned invalid JSON'
  end
  for _, project in ipairs(data.data.projects) do
    for _, message in ipairs(project.messages or {}) do
      if message.locale == locale and message.value ~= nil then
        return message.value
      end
    end
  end
  return nil, 'locale ' .. locale .. ' not present in get output'
end

local function write_screen(file_name, lines)
  vim.fn.writefile(lines, out_dir .. '/screens/' .. file_name)
end

local function note_file_failure(relative, filetype, message)
  md[#md + 1] = ('- `%s` (%s): FAIL — %s'):format(relative, filetype or '-', message)
end

local function verify_file(relative)
  local path = tmp_root .. '/' .. project_name .. '/' .. relative
  if vim.fn.filereadable(path) ~= 1 then
    local message = 'file missing from the playground copy: ' .. path
    fail('inline-translations', relative, '-', message)
    note_file_failure(relative, '-', message)
    return
  end
  vim.cmd('edit ' .. vim.fn.fnameescape(path))
  vim.cmd 'filetype detect'
  local bufnr = vim.api.nvim_get_current_buf()
  local filetype = vim.bo[bufnr].filetype

  local attached = wait_for(function()
    return #vim.lsp.get_clients { bufnr = bufnr, name = 'x18n' } > 0
  end, 10000)
  if not attached then
    local supported = table.concat(require('x18n').config.lsp.filetypes or {}, ', ')
    local message = ('no x18n client attached: filetype=%s; lsp.filetypes=%s'):format(filetype, supported)
    fail('inline-translations', relative, '-', message)
    note_file_failure(relative, filetype, message)
    return
  end
  local client = vim.lsp.get_clients({ bufnr = bufnr, name = 'x18n' })[1]
  local namespace = require('x18n.decorations').namespace()
  local uri = vim.uri_from_bufnr(bufnr)

  if
    not wait_for(function()
      return #vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, {}) > 0
    end, 10000)
  then
    local decorations = request(client, 'x18n/decorations', { uri = uri })
    local message = ('no decorations rendered; filetype=%s; server decorations=%d'):format(
      filetype,
      decorations and #(decorations.decorations or {}) or 0
    )
    fail('inline-translations', relative, '-', message)
    note_file_failure(relative, filetype, message)
    return
  end

  local projects = request(client, 'x18n/projects', {}) or {}
  local file_project = project_for(projects, path)
  local locales = locale_codes(file_project)
  if #locales == 0 then
    local message = 'no project locales reported by x18n/projects'
    fail('display-locale', relative, '-', message)
    note_file_failure(relative, filetype, message)
    return
  end
  if only_locale then
    local found = false
    for _, code in ipairs(locales) do
      if code == only_locale then
        found = true
      end
    end
    if not found then
      local message = ('locale not in project; available: %s'):format(table.concat(locales, ','))
      fail('display-locale', relative, only_locale, message)
      note_file_failure(relative, filetype, message)
      return
    end
    locales = { only_locale }
  end

  local current = request(client, 'x18n/decorations', { uri = uri })
  if not current or #(current.decorations or {}) == 0 then
    local contents = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
    local message = 'server returned no decorations for this file'
    if contents:find('<i18n', 1, true) then
      message = message
        .. '; it has an embedded <i18n> resource block, so the server treats it as a locale file and skips code decorations'
    end
    fail('inline-translations', relative, '-', message)
    note_file_failure(relative, filetype, message)
    return
  end
  local decorated = {}
  for _, d in ipairs(current and current.decorations or {}) do
    if d.range then
      decorated[d.range.start.line + 1] = true
    end
  end
  local neutral
  for line = 1, vim.api.nvim_buf_line_count(bufnr) do
    if not decorated[line] then
      neutral = line
      break
    end
  end
  if not neutral then
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { '' })
    neutral = vim.api.nvim_buf_line_count(bufnr)
    vim.wait(400)
  end
  vim.api.nvim_win_set_cursor(0, { neutral, 0 })
  vim.wait(300)
  vim.cmd 'redraw'

  local file_screens = {}
  for _, code in ipairs(locales) do
    require('x18n.actions').set_display_locale(code)
    local decorations
    if
      not wait_for(function()
        decorations = request(client, 'x18n/decorations', { uri = uri })
        return decorations ~= nil and decorations.locale == code
      end, 8000)
    then
      fail('display-locale', relative, code, 'server did not switch to ' .. code)
    else
      local expected, ops_by_line = expected_lines(bufnr, decorations.decorations)
      local actual = {}

      wait_for(function()
        vim.cmd 'redraw'
        actual = {}
        for line in pairs(expected) do
          local row = vim.fn.screenpos(0, line, 1).row
          actual[line] = row > 0 and screen_text(row) or '<line not visible>'
        end
        for line, text in pairs(expected) do
          if trim(actual[line]) ~= trim(text) then
            return false
          end
        end
        return true
      end, 6000)
      vim.cmd 'redraw'
      for line in pairs(expected) do
        local row = vim.fn.screenpos(0, line, 1).row
        actual[line] = row > 0 and screen_text(row) or '<line not visible>'
      end

      for _, d in ipairs(decorations.decorations or {}) do
        if missing_suppressed(bufnr, d) then
          add_check {
            feature = 'missing-and-dynamic',
            file = relative,
            locale = code,
            line = d.range.start.line + 1,
            key = d.key,
            state = d.state,
            status = 'PASS',
            message = 'missing-key diagnostic covers the line; the translation arrow yields',
          }
        end
      end

      local evidence = {
        ('# %s / %s / %s'):format(project_name, relative, code),
        ('filetype: %s'):format(filetype),
        ('project: %s'):format(file_project and file_project.name or '?'),
        ('display locale: %s'):format(decorations.locale or '?'),
        ('cursor line: %d'):format(neutral),
        '',
      }
      local counts = { pass = 0, fail = 0 }
      for line, text in pairs(expected) do
        local ops = ops_by_line[line] or {}
        local features = {}
        local keys, states = {}, {}
        for _, op in ipairs(ops) do
          for feature in op.feature:gmatch '[^,]+' do
            features[feature] = true
          end
          keys[#keys + 1] = op.key or '?'
          states[#states + 1] = op.state or '?'
        end
        local feature_list = vim.tbl_keys(features)
        table.sort(feature_list)
        local actual_text = actual[line] or '<line not visible>'
        local ok = trim(actual_text) == trim(text)
        counts[ok and 'pass' or 'fail'] = counts[ok and 'pass' or 'fail'] + 1
        add_check {
          feature = table.concat(feature_list, ','),
          file = relative,
          locale = code,
          line = line,
          key = table.concat(keys, ','),
          state = table.concat(states, ','),
          expected = text,
          actual = actual_text,
          status = ok and 'PASS' or 'FAIL',
        }
        evidence[#evidence + 1] = ('## line %d  [%s]'):format(line, table.concat(feature_list, ', '))
        evidence[#evidence + 1] = 'RAW      : ' .. (vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1] or '')
        evidence[#evidence + 1] = 'EXPECTED : ' .. text
        evidence[#evidence + 1] = 'SCREEN   : ' .. actual_text
        evidence[#evidence + 1] = 'RESULT   : ' .. (ok and 'PASS' or 'FAIL')
        evidence[#evidence + 1] = ''
      end

      local sample
      for _, d in ipairs(decorations.decorations or {}) do
        if d.state == 'ok' and d.value and d.value ~= '' and d.key then
          sample = d
          break
        end
      end
      if sample then
        local root = file_project and file_project._root or (tmp_root .. '/' .. project_name)
        local value, reason = cli_value(root, sample.key, code)
        if value == nil then
          add_check {
            feature = 'display-locale',
            file = relative,
            locale = code,
            key = sample.key,
            status = 'WARN',
            message = 'CLI cross-check unavailable: ' .. tostring(reason),
          }
        elseif value ~= sample.value then
          fail(
            'display-locale',
            relative,
            code,
            ('CLI value mismatch for %s: decoration=%q cli=%q'):format(sample.key, sample.value, value)
          )
        else
          evidence[#evidence + 1] = ('cross-check: %s = %q (CLI agrees)'):format(sample.key, value)
          evidence[#evidence + 1] = ''
        end
      end
      evidence[#evidence + 1] = ('summary: %d lines pass, %d fail'):format(counts.pass, counts.fail)
      local slug = relative:gsub('[/.]', '_')
      write_screen(('%s__%s__%s.txt'):format(project_name, slug, code), evidence)
      file_screens[#file_screens + 1] = { locale = code, pass = counts.pass, fail = counts.fail }
    end
  end
  md[#md + 1] = ('- `%s` (%s)'):format(relative, filetype)
  for _, screen in ipairs(file_screens) do
    md[#md + 1] = ('  - %s: %d pass, %d fail'):format(screen.locale, screen.pass, screen.fail)
  end
end

local function finish()
  if done then
    return
  end
  done = true
  if timer then
    timer:stop()
    timer:close()
  end
  local status = failures == 0 and 'PASS' or 'FAIL'
  local report = {
    project = project_name,
    status = status,
    checks = checks,
    failures = failures,
  }
  table.insert(md, 1, ('# %s — %s'):format(project_name, status))
  table.insert(md, 2, '')
  vim.fn.writefile(md, out_dir .. '/' .. project_name .. '.md')
  vim.fn.writefile({ vim.json.encode(report) }, out_dir .. '/' .. project_name .. '.json')
  print(('x18n verify %s: %s (%d checks, %d failures)'):format(project_name, status, #checks, failures))
  vim.cmd(failures == 0 and 'qa!' or 'cq')
end

local function main()
  vim.fn.mkdir(out_dir .. '/screens', 'p')
  local project_dir = tmp_root .. '/' .. project_name
  vim.fn.mkdir(project_dir, 'p')
  local copied = vim.fn.system {
    'rsync',
    '-a',
    repo .. '/playground/' .. project_name .. '/',
    project_dir .. '/',
  }
  if vim.v.shell_error ~= 0 then
    fail('inline-translations', '-', '-', 'project copy failed: ' .. copied)
    return
  end

  md[#md + 1] = ('Project directory: playground/%s'):format(project_name)
  md[#md + 1] = ''
  local server, reason = cli_status(project_dir)
  if server then
    md[#md + 1] = ('Server detection: locales=%s resources=%d keys=%d usages=%d'):format(
      server.locales,
      server.resources,
      server.keys,
      server.usages
    )
  else
    add_check { feature = 'harness', status = 'WARN', message = 'CLI status unavailable: ' .. tostring(reason) }
  end
  md[#md + 1] = ''
  md[#md + 1] = '## Files'
  md[#md + 1] = ''

  for _, relative in ipairs(entry.files) do
    local ok, err = pcall(verify_file, relative)
    if not ok then
      fail('harness', relative, '-', 'verification error: ' .. tostring(err))
    end
  end
end

timer = vim.uv.new_timer()
timer:start(120000, 0, function()
  vim.schedule(function()
    fail('harness', '-', '-', 'verification timed out after 120s')
    finish()
  end)
end)

local ok, err = xpcall(main, debug.traceback)
if not ok then
  fail('harness', '-', '-', 'checker crashed: ' .. tostring(err))
end
finish()
