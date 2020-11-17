-- Manage tasks with ease. Supports deadlines and timestamps
-- Highlights deadlines based on the time left till they are
-- they are over, for easier visual understanding.
-- To activate it in a file:
-- lua require('tasks')
-- Setup an autocommand:
-- autocmd BufEnter *.tasks lua require('tasks')

-- Variables -{{{
local api = vim.api
local timeformat = ' <%Y-%m-%d %a %b>'
local deadline_warntime = api.nvim_get_var('tasks_warntime')
-- }}}
-- Remove the timestamp (if any) -{{{
local function RemoveTime()
  -- Remove only if time is present (duh). Also don't do anything on blank lines
  if api.nvim_get_current_line() ~= '' and string.match(api.nvim_get_current_line(), '<.*>$') then
    api.nvim_command('normal! $"_da>x')
  end
end
-- }}}
-- Insert today's time -{{{
local function InsertTime()
  if api.nvim_get_current_line() ~= '' then -- Don't do anything on a blank line
    RemoveTime()
    api.nvim_command('normal! A' .. os.date(timeformat))
  end
end
-- }}}
-- Create a new task -{{{
local function NewTask()
  api.nvim_command('normal! ' .. (api.nvim_get_current_line() == '' and 'i' or 'o' ) .. '[ ] ')
  api.nvim_command('startinsert!')
end
-- }}}
-- Change the state of a task -{{{
local function ChangeState()
  local currenttask = api.nvim_get_current_line() -- The current task

  if localtask ~= '' then -- Don't do anything on a blank line
    local initpos = api.nvim_win_get_cursor(0) -- The initial cursor position

    if string.match(currenttask, '^%[ %].*') then

      -- Mark it as ongoing
      api.nvim_command('normal! 0lr-')

    elseif string.match(currenttask, '^%[%-%].*') then

      -- Mark it completed ('✕') and insert the time when it was completed
      api.nvim_command('normal! 0lr✕')
      InsertTime()
      api.nvim_command('normal! $F<aCompleted: ')
      initpos[2] = initpos[2] + 2

    elseif string.match(currenttask, '^%[✕%].*') then

      -- Mark it cancelled ('X') and remove the time period (if any)
      api.nvim_command('normal! 0lrX')
      RemoveTime()
      initpos[2] = initpos[2] - 2

    else

      -- Mark it as new
      api.nvim_command('normal! 0lr ')
    end

    api.nvim_command('silent! write')
    api.nvim_win_set_cursor(0, initpos) -- Reset cursor position
  end
end
-- }}}
-- Insert/remove deadlines -{{{
local function Deadline()
  local currenttask = api.nvim_get_current_line() -- The current task

  -- Don't do anything on a blank line or on a completed task
  if localtask ~= '' and (not string.match(currenttask, '^%[✕%].*')) then
    local initpos = api.nvim_win_get_cursor(0) -- The initial cursor position

    if string.match(api.nvim_get_current_line(), '<Deadline:.*>$') then
      -- Remove a deadline if already present
      RemoveTime()
    else
      -- Insert a deadline

      -- Date
      local curDate = os.date('%d')
      local dlDate = api.nvim_call_function('input', {'Enter the date (Default - ' .. curDate .. '): '})
      local dlDate = dlDate == '' and curDate or dlDate

      -- Month
      local curMonth = os.date('%m')
      local dlMonth = api.nvim_call_function('input', {'Enter the month (Default - ' .. curMonth .. '): '})
      local dlMonth = dlMonth == '' and curMonth or dlMonth

      -- Year
      local curYear = os.date('%y')
      local dlYear = api.nvim_call_function('input', {'Enter the year (Default - ' .. curYear .. '): '})
      local dlYear = dlYear == '' and curYear or dlYear
      local dlYear = os.date('%C') * 100 + dlYear

      local deadline = os.time{year = dlYear, month = dlMonth, day = dlDate}
      local daysleft = math.ceil(os.difftime(deadline, os.time()) / (24 * 60 * 60))
      local deadlinedate = os.date(timeformat, os.time(os.date("*t")) + daysleft * 24 * 3600)

      api.nvim_command('normal! A' .. deadlinedate)
      api.nvim_command('normal! $F<aDeadline: ')
    end

    api.nvim_command('silent! write')
    api.nvim_command('call feedkeys("\\<C-l>", "n")')
    api.nvim_win_set_cursor(0, initpos) -- Reset cursor position
  end
end
-- }}}
-- Colors and autocommands -{{{
local function Init()

  -- Colors
  api.nvim_command('highlight! Comment gui=strikethrough'       )

  api.nvim_command('syntax match Identifier "\\v^\\["'          )
  api.nvim_command('syntax match Function "✕"'                  )
  api.nvim_command('syntax match Type "-"'                      )
  api.nvim_command('syntax match Constant "\\v\\]\\s.*"'        )
  api.nvim_command('syntax match Identifier "\\c\\]"'           )
  api.nvim_command('syntax match Identifier "\\v\\<.*\\>"'      )
  api.nvim_command('syntax match Comment "\\v\\[X\\].*"'        )
  api.nvim_command('syntax match String "\\v\\<Completed:.*\\>"')
  api.nvim_command('syntax match Type "\\v\\<Deadline:.*\\>"'   )

  api.nvim_command('highlight! link DeadlineOver Comment')
  api.nvim_command('highlight! link DeadlineNear WarningMsg')

  -- Autocommands
  api.nvim_command('autocmd InsertLeave ' .. api.nvim_buf_get_name(0) .. ' silent! write | lua require"tasks".RefDeadlines()')
  api.nvim_command('autocmd CursorMoved ' .. api.nvim_buf_get_name(0) .. ' if virtcol(".") < 5 | execute "normal! 04l" | endif')
  api.nvim_command('autocmd CursorMovedI ' .. api.nvim_buf_get_name(0) .. ' if virtcol(".") < 5 | execute "normal! 04l" | endif')
end
-- }}}
-- Check if deadline on the current task has passed -{{{
local function CheckDeadline()
  local currenttask = api.nvim_get_current_line() -- The current task

  -- Only work on lines containing a deadline
  if string.match(currenttask, '.*<Deadline: .*>') then

    -- The deadline
    local deadline = string.gsub(string.gsub(currenttask, '.*<Deadline: ', ''), ' .*>$', '')

    -- Split the deadline into date, month and year
    local result = {}
    local match

    for match in (deadline .. '-'):gmatch("(.-)" .. '-') do
      table.insert(result, match)
    end

    dlYear, dlMonth, dlDate = result[1], result[2], result[3]

    -- Get the difference between today's date and the date of the deadline
    local deadlinereal = os.time{year = dlYear, month = dlMonth, day = dlDate}
    local daysleft = math.ceil(os.difftime(deadlinereal, os.time()) / (24 * 60 * 60))

    -- If the deadline is over or near highlight it as a warning
    if daysleft < 1 then
      -- The deadline is over
      api.nvim_call_function('matchadd', {'DeadlineOver', '<Deadline: ' .. deadline .. '.*$'})
    elseif daysleft <= deadline_warntime then
      api.nvim_call_function('matchadd', {'DeadlineNear', '<Deadline: ' .. deadline .. '.*$'})
    end

  end
end
-- }}}
-- Check the deadlines in the files -{{{
local function RefDeadlines()
  local initpos = api.nvim_win_get_cursor(0) -- The initial cursor position
  api.nvim_call_function('clearmatches', {}) -- Clear the matches
  api.nvim_win_set_cursor(0, {1, 0}) -- Top of the file

  -- Check all the deadlines in the file
  while api.nvim_call_function('line', {'.'}) < api.nvim_call_function('line', {'$'}) do
    CheckDeadline()
    api.nvim_command('normal! j')
  end
  CheckDeadline()

  api.nvim_win_set_cursor(0, initpos) -- Reset cursor position
end
-- }}}
-- Edit a task -{{{
local function EditTask()
  api.nvim_command('normal! 04l')

  -- Check if the task has a deadline
  if string.match(api.nvim_get_current_line(), '.*<.*>$') then
    api.nvim_feedkeys('vf<2hc', 'n', 1) -- change 'to' the deadline
  else
    api.nvim_feedkeys('C', 'n', 1)
  end
end
-- }}}
-- Initialization -{{{
Init()
api.nvim_win_set_cursor(0, {1, 5})
api.nvim_buf_set_keymap(0, 'n', 'o',      ':lua require"tasks".New()<CR>',          { noremap = true, silent = true })
api.nvim_buf_set_keymap(0, 'n', 'O',      'O<Esc>:lua require"tasks".New()<CR>',    { noremap = true, silent = true })
api.nvim_buf_set_keymap(0, 'i', '<CR>',   '<Esc>:lua require"tasks".New()<CR>',     { noremap = true, silent = true })

api.nvim_buf_set_keymap(0, 'n', '<Tab>',  ':lua require"tasks".Cycle()<CR>',        { noremap = true, silent = true })
api.nvim_buf_set_keymap(0, 'n', 't',      ':lua require"tasks".Deadline()<CR>',     { noremap = true, silent = true })
api.nvim_buf_set_keymap(0, 'n', 'R',      ':lua require"tasks".RefDeadlines()<CR>', { noremap = true, silent = true })

api.nvim_buf_set_keymap(0, 'n', 'cc',     '0C',                                     { noremap = true, silent = true })
api.nvim_buf_set_keymap(0, 'n', 'C',      ':lua require"tasks".EditTask()<CR>',     { noremap = true, silent = true })

api.nvim_buf_set_keymap(0, 'n', 'K',      ':move -2<CR>',                           { noremap = true, silent = true })
api.nvim_buf_set_keymap(0, 'n', 'J',      ':move +1<CR>',                           { noremap = true, silent = true })
RefDeadlines()
-- }}}

return {
  New = NewTask,
  Cycle = ChangeState,
  Deadline = Deadline,
  RefDeadlines = RefDeadlines,
  EditTask = EditTask,
  BackSpace = BackSpace
}
