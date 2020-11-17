function! s:TasksFiles()
  setlocal filetype=tasks
  if !exists('g:tasks_warntime')
    let g:tasks_warntime = 3
  endif
  lua require('tasks')
endfunction

autocmd BufEnter *.tasks call <SID>TasksFiles()
