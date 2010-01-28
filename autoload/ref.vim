" Integrated reference viewer.
" Version: 0.2.0
" Author : thinca <thinca+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim

if !exists('g:ref_open')
  let g:ref_open = 'split'
endif

if !exists('g:ref_cache_dir')
  let g:ref_cache_dir = expand('~/.vim_ref_cache')
endif

if !exists('g:ref_use_vimproc')
  let g:ref_use_vimproc = exists('*vimproc#system')
endif

let s:last_stderr = ''

let s:is_win = has('win16') || has('win32') || has('win64')


" {{{1

" A function for main command.
function! ref#ref(args)  " {{{2
  let [source, query] = matchlist(a:args, '\v^(\w+)\s*(.*)$')[1:2]
  return ref#open(source, query)
endfunction



function! ref#complete(lead, cmd, pos)  " {{{2
  let list = matchlist(a:cmd, '^\v.{-}R%[ef]\s+(\w+)\s+(.*)$')
  if list == []
    return filter(ref#list(), 'v:val =~ "^".a:lead')
  endif
  let [subcmd, query] = list[1 : 2]
  if exists('*ref#{subcmd}#complete')
    return ref#{subcmd}#complete(query)
  endif
  return []
endfunction



" Get available reference list.
function! ref#list()  " {{{2
  let list = split(globpath(&runtimepath, 'autoload/ref/*.vim'), "\n")
  return s:uniq(filter(map(list, 'fnamemodify(v:val, ":t:r")'),
  \             'ref#{v:val}#available()'))
endfunction



function! ref#open(source, query, ...)  " {{{2
  if index(ref#list(), a:source) < 0 || !exists('*ref#{a:source}#available')
  \   || !ref#{a:source}#available()
    echoerr 'Reference unavailable:' a:source
    return
  endif

  try
    let res = ref#{a:source}#get_body(a:query)
  catch
    echohl ErrorMsg
    echo v:exception
    echohl None
    return
  endtry

  if type(res) == type([])
    let newres = join(res, "\n")
    unlet! res
    let res = newres
  endif
  if type(res) != type('') || res == ''
    return
  endif

  let pos = getpos('.')

  let bufnr = 0
  for i in range(1, winnr('$'))
    let n = winbufnr(i)
    if getbufvar(n, '&filetype') == 'ref'
      execute i 'wincmd w'
      let bufnr = i
      break
    endif
  endfo

  if bufnr == 0
    silent! execute (a:0 ? a:1 : g:ref_open)
    enew
    call s:initialize_buffer(a:source)
  else
    setlocal modifiable noreadonly
    % delete _
    if b:ref_source != a:source && exists('*ref#{b:ref_source}#leave')
      call ref#{b:ref_source}#leave()
    endif
  endif
  let b:ref_source = a:source

  " FIXME: not cool...
  let s:res = res
  call s:open(a:query, 'silent :1 put = s:res | 1 delete _')
  unlet! s:res

  let b:ref_history_pos += 1
  unlet! b:ref_history[b:ref_history_pos :]
  if 0 < b:ref_history_pos
    let b:ref_history[-1][3] = pos
  endif
  call add(b:ref_history, [a:source, a:query, changenr(), []])
endfunction



" A function for key mapping for K.
function! ref#jump(...)  " {{{2
  let source = ref#detect#detect()
  if source == ''
    call feedkeys('K', 'n')
    return
  endif

  if a:0 && a:1
    let [reg_save, reg_save_type] = [getreg(), getregtype()]
    silent normal! gvy
    let query = @"
    call setreg(v:register, reg_save, reg_save_type)

  elseif exists('*ref#{source}#get_keyword')
    let pos = getpos('.')
    let query = ref#{source}#get_keyword()
    call setpos('.', pos)
  else
    let query = expand('<cword>')
  endif
  if type(query) == type('') && query != ''
    call ref#open(source, query)
  endif
endfunction





" Helper functions for source. {{{1
let s:cache = {}
function! ref#cache(source, name, gather)  " {{{2
  if !exists('s:cache[a:source][a:name]')
    if !has_key(s:cache, a:source)
      let s:cache[a:source] = {}
    endif

    let file = printf('%s/%s/%s', g:ref_cache_dir, a:source, a:name)
    if filereadable(file)
      let s:cache[a:source][a:name] = readfile(file)
    else
      let s:cache[a:source][a:name] =
      \  type(a:gather) == type(function('function')) ? a:gather(a:name) :
      \  type(a:gather) == type({}) && has_key(a:gather, 'call')
      \    &&  type(a:gather.call) == type(function('function')) ?
      \        a:gather.call(a:name) :
      \  type(a:gather) == type('') ? eval(a:gather) : []

      if g:ref_cache_dir != ''
        let dir = printf('%s/%s', g:ref_cache_dir, a:source)
        if !isdirectory(dir)
          call mkdir(dir, 'p')
        endif
        call writefile(s:cache[a:source][a:name], file)
      endif
    endif
  endif

  return s:cache[a:source][a:name]
endfunction



function! ref#system(args, ...)
  let args = type(a:args) == type('') ? split(a:args, '\s\+') : a:args
  if g:ref_use_vimproc
    return a:0 ? vimproc#system(args, a:1) : vimproc#system(args)
  endif

  if s:is_win
    " Here is a command that want to execute.
    "   something.bat keyword
    "
    " The command is executed by following form in fact.
    "   cmd.exe /c something.bat keyword
    "
    " Any arguments may including whitespace and other character needs escape.
    " So, quote each arguments.
    "   cmd.exe /c "something.bat" "keyword"
    "
    " But, cmd.exe handle it as one argument like ``something.bat" "keyword''.
    " So, quote the command again.
    "   cmd.exe /c ""something.bat" "keyword""
    "
    " Here, cmd.exe do strange behavior.  When the command is .bat file,
    " %~dp0 in the file is expanded to current directory.
    " For example
    "   C:\Program Files\some\example.bat: (in $PATH)
    "   @echo %~f0
    "
    "   (in cmd.exe)
    "   C:\>example.bat
    "   C:\Program Files\some\example.bat
    "
    "   C:\>cmd.exe /c example.bat
    "   C:\Program Files\some\example.bat
    "
    "   C:\>cmd.exe /c ""example.bat""
    "   C:\example.bat
    "
    "   C:\>cmd.exe /c ""C:\Program Files\some\example.bat""
    "   C:\Program Files\some\example.bat
    "
    " By occasion of above, the command should be converted to fullpath.
    let args[0] = s:cmdpath(args[0])
    let q = '"'
    let cmd = q . join(map(args,
    \   'q . substitute(escape(v:val, q), "[<>^|&]", "^\\0", "g") . q'),
    \   ' ') . q
  else
    let cmd = join(map(args, 'shellescape(v:val)'))
  endif
  let save_shellredir = &shellredir
  let stderr = tempname()
  let &shellredir = '>%s 2>' . shellescape(stderr)
  let result = ''
  try
    let result = a:0 ? system(cmd, a:1) : system(cmd)
  finally
    if filereadable(stderr)
      let s:last_stderr = join(readfile(stderr, 'b'), "\n")
      call delete(stderr)
    else
      let s:last_stderr = ''
    endif
    let &shellredir = save_shellredir
  endtry

  return result
endfunction



function! ref#shell_error()
  return g:ref_use_vimproc ? vimproc#get_last_status() : v:shell_error
endfunction



function! ref#last_stderr()
  return g:ref_use_vimproc ? vimproc#get_last_errmsg() : s:last_stderr
endfunction







" Misc. {{{1
function! s:initialize_buffer(source)  " {{{2
  setlocal nobuflisted
  setlocal buftype=nofile noswapfile
  setlocal bufhidden=delete
  setlocal nonumber

  let b:ref_history = []  " stack [source, query, changenr, cursor]
  let b:ref_history_pos = -1  " pointer

  nnoremap <buffer> <Plug>(ref-forward)
  \        :<C-u>call <SID>move_history(v:count1)<CR>
  nnoremap <buffer> <Plug>(ref-back)
  \        :<C-u>call <SID>move_history(-v:count1)<CR>

  if !exists('g:ref_no_default_key_mappings')
  \   || !g:ref_no_default_key_mappings
    map <buffer> <silent> <CR> <Plug>(ref-keyword)
    map <buffer> <silent> <2-LeftMouse> <Plug>(ref-keyword)
    map <buffer> <silent> <C-]> <Plug>(ref-keyword)

    map <buffer> <silent> <C-t> <Plug>(ref-back)
    map <buffer> <silent> <C-o> <Plug>(ref-back)
    map <buffer> <silent> <C-i> <Plug>(ref-forward)
  endif

  setlocal filetype=ref

  command! -bar -buffer RefHistory call s:dump_history()
endfunction


function! s:open(query, open_cmd)  " {{{2
  setlocal modifiable noreadonly

  let bufname = printf('[ref-%s:%s]', b:ref_source, a:query)
  if s:is_win
    " In Windows, '*' cannot be used for a buffer name.
    let bufname = substitute(bufname, '\*', '', 'g')
  endif
  noautocmd silent! file `=bufname`

  execute a:open_cmd

  1  " Move the cursor to the first line.

  if exists('*ref#{b:ref_source}#opened')
    call ref#{b:ref_source}#opened(a:query)
  endif

  setlocal nomodifiable readonly
endfunction



function! s:move_history(n)  " {{{2
  let next = b:ref_history_pos + a:n

  if next < 0
    let next = 0
  elseif len(b:ref_history) <= next
    let next = len(b:ref_history) - 1
  endif

  if next == b:ref_history_pos
    return
  endif
  let b:ref_history_pos = next

  let [source, query, changenr, pos] = b:ref_history[next]
  let b:ref_source = source
  call s:open(query, 'silent! undo ' . changenr)
  call setpos('.', pos)
endfunction



function! s:dump_history()  " {{{2
  for i in range(len(b:ref_history))
    echo printf('%s%3d %s: %s', i == b:ref_history_pos ? '>' : ' ', i + 1,
      \ b:ref_history[i][0], b:ref_history[i][1])
  endfor
  let i = input('Enter nr of choice (CR to abort):')
  if i =~ '\d\+'
    call s:move_history(i - b:ref_history_pos - 1)
  endif
endfunction



function! s:cmdpath(cmd)
  " Search the fullpath of command for MS Windows.
  let full = glob(a:cmd)
  if a:cmd ==? full
    " Already fullpath.
    return a:cmd
  endif

  let extlist = split($PATHEXT, ';')
  if a:cmd =~? '\V\%(' . substitute($PATHEXT, ';', '\\|', 'g') . '\)\$'
    call insert(extlist, '', 0)
  endif
  for dir in split($PATH, ';')
    for ext in extlist
      let full = glob(dir . '\' . a:cmd . ext)
      if full != ''
        return full
      endif
    endfor
  endfor
  return ''
endfunction




function! s:uniq(list)
  let d = {}
  for i in a:list
    let d[i] = 0
  endfor
  return sort(keys(d))
endfunction



let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
