" Integrated reference viewer.
" Version: 0.3.1
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

let s:is_win = has('win16') || has('win32') || has('win64')

let s:TYPES = {
\     'number': type(0),
\     'string': type(''),
\     'function': type(function('function')),
\     'list': type([]),
\     'dictionary': type({}),
\     'float': type(0.0),
\   }

let s:sources = {}

let s:prototype = {}  " {{{1
function! s:prototype.opened(query)
endfunction
function! s:prototype.get_keyword()
  return expand('<cword>')
endfunction
function! s:prototype.complete(query)
  return []
endfunction
function! s:prototype.leave()
endfunction



" {{{1

" A function for main command.
function! ref#ref(args)  " {{{2
  try
    let [source, query] = matchlist(a:args, '\v^(\w+)\s*(.*)$')[1:2]
    return ref#open(source, query)
  catch /^Vim(let):E688:/
    call s:echoerr('ref: Invalid argument: ' . a:args)
  catch /^ref:/
    call s:echoerr(v:exception)
  endtry
endfunction



function! ref#complete(lead, cmd, pos)  " {{{2
  let list = matchlist(a:cmd, '^\v.{-}R%[ef]\s+(\w+)\s+(.*)$')
  if list == []
    let s = keys(filter(copy(ref#available_sources()), 'v:val.available()'))
    return filter(s, 'v:val =~ "^".a:lead')
  endif
  let [source, query] = list[1 : 2]
  return get(s:sources, source, s:prototype).complete(query)
endfunction



function! ref#register(source)  " {{{2
  if type(a:source) != type({})
    throw 'ref: Invalid source: The source should be a Dictionary.'
  endif
  let source = extend(copy(s:prototype), a:source)
  call s:validate(source, 'name', 'string')
  call s:validate(source, 'get_body', 'function')
  call s:validate(source, 'opened', 'function')
  call s:validate(source, 'get_keyword', 'function')
  call s:validate(source, 'complete', 'function')
  call s:validate(source, 'leave', 'function')
  let s:sources[source.name] = source
endfunction



function! ref#available_source_names()  " {{{2
  return keys(s:sources)
endfunction



function! ref#available_sources(...)  " {{{2
  return !a:0                    ? copy(s:sources) :
  \      has_key(s:sources, a:1) ? s:sources[a:1]  : 0
endfunction



function! ref#open(source, query, ...)  " {{{2
  if !has_key(s:sources, a:source)
    throw 'ref: The source is not registered: ' . a:source
  endif
  let source = s:sources[a:source]
  if !source.available()
    throw 'ref: This source is unavailable: ' . a:source
  endif

  try
    let res = source.get_body(a:query)
  catch
    call s:echoerr(v:exception)
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
    if b:ref_source != a:source
      call source.leave()
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
function! ref#K(mode)  " {{{2
  try
    call ref#jump(a:mode)
  catch /^ref:/
    call feedkeys('K', 'n')
  endtry
endfunction



function! ref#jump(...)  " {{{2
  let source = 2 <= a:0 ? a:2 : ref#detect()
  if !has_key(s:sources, source)
    throw 'ref: The source is not registered: ' . source
  endif

  let mode = a:0 ? a:1 : 'normal'
  let query = ''
  if mode ==# 'normal'
    let pos = getpos('.')
    let res = s:sources[source].get_keyword()
    call setpos('.', pos)
    if type(res) == type([]) && len(res) == 2
      let [source, query] = res
    else
      let query = res
    endif

  elseif mode =~# '^\v%(visual|line|char|block)$'
    let vm = {
    \ 'visual': visualmode(),
    \ 'line': 'V',
    \ 'char': 'v',
    \ 'block': "\<C-v>" }[mode]
    let [sm, em] = mode ==# 'visual' ? ['<', '>'] : ['[', ']']

    let [reg_save, reg_save_type] = [getreg(), getregtype()]
    let [pos_c, pos_s, pos_e] = [getpos('.'), getpos("'<"), getpos("'>")]

    execute 'silent normal! `' . sm . vm . '`' . em . 'y'
    let query = @"

    " Restore '< '>
    call setpos('.', pos_s)
    execute 'normal!' vm
    call setpos('.', pos_e)
    execute 'normal!' vm
    call setpos('.', pos_c)

    call setreg(v:register, reg_save, reg_save_type)

  endif
  if type(query) == type('') && query != ''
    call ref#open(source, query)
  endif
endfunction



function! ref#detect()
  if exists('b:ref_source')
    let Source = b:ref_source
  elseif exists('g:ref_detect_filetype[&l:filetype]')
    let Source = g:ref_detect_filetype[&l:filetype]
  elseif exists('g:ref_detect_filetype._')
    let Source = g:ref_detect_filetype._
  else
    let Source = ''
  endif

  if type(Source) == s:TYPES.function
    " For dictionary function.
    let s = call(Source, [&l:filetype], g:ref_detect_filetype)
    unlet Source
    let Source = s
  endif

  if type(Source) == s:TYPES.string && Source != ''
    return Source
  endif
  throw 'ref: Can not detect the source.'
endfunction



function! ref#register_detection(ft, source)
  if !exists('g:ref_detect_filetype')
    let g:ref_detect_filetype = {}
  endif
  if !has_key(g:ref_detect_filetype, a:ft)
    let g:ref_detect_filetype[a:ft] = a:source
  endif
endfunction





" Helper functions for source. {{{1
let s:cache = {}
function! ref#cache(source, name, gather)  " {{{2
  if !exists('s:cache[a:source][a:name]')
    if !has_key(s:cache, a:source)
      let s:cache[a:source] = {}
    endif

    let fname = substitute(a:name, '[:;*?"<>|/\\%]',
    \           '\=printf("%%%02x", char2nr(submatch(0)))', 'g')

    if g:ref_cache_dir != ''
      let file = printf('%s/%s/%s', g:ref_cache_dir, a:source, fname)
      if filereadable(file)
        let s:cache[a:source][a:name] = readfile(file)
      endif
    endif

    if !has_key(s:cache[a:source], a:name)
      let cache =
      \  type(a:gather) == s:TYPES.function ? a:gather(a:name) :
      \  type(a:gather) == type({}) && has_key(a:gather, 'call')
      \    && type(a:gather.call) == s:TYPES.function ?
      \       a:gather.call(a:name) :
      \  type(a:gather) == type('') ? eval(a:gather) : []

      if type(cache) == s:TYPES.list
        let s:cache[a:source][a:name] = cache
      elseif type(cache) == s:TYPES.string
        let s:cache[a:source][a:name] = split(cache, "\n")
      else
        throw 'ref: Invalid results of cache: ' . string(cache)
      endif

      if g:ref_cache_dir != ''
        let dir = fnamemodify(file, ':h')
        if !isdirectory(dir)
          call mkdir(dir, 'p')
        endif
        call writefile(s:cache[a:source][a:name], file)
      endif
    endif
  endif

  return s:cache[a:source][a:name]
endfunction



function! ref#system(args, ...)  " {{{2
  let args = type(a:args) == type('') ? split(a:args, '\s\+') : a:args
  if g:ref_use_vimproc
    let stdout = a:0 ? vimproc#system(args, a:1) : vimproc#system(args)
    return {
    \ 'result': vimproc#get_last_status(),
    \ 'stdout': stdout,
    \ 'stderr': vimproc#get_last_errmsg(),
    \ }
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
  let stderr_file = tempname()
  let &shellredir = '>%s 2>' . shellescape(stderr_file)
  let stdout = ''
  try
    let stdout = a:0 ? system(cmd, a:1) : system(cmd)
  finally
    if filereadable(stderr_file)
      let stderr = join(readfile(stderr_file, 'b'), "\n")
      call delete(stderr_file)
    else
      let stderr = ''
    endif
    let &shellredir = save_shellredir
  endtry

  return {
  \ 'result': v:shell_error,
  \ 'stdout': stdout,
  \ 'stderr': stderr
  \ }
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
  silent! file `=bufname`

  execute a:open_cmd

  1  " Move the cursor to the first line.

  call s:sources[b:ref_source].opened(a:query)

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



function! s:validate(source, key, type)  " {{{2
  if !has_key(a:source, a:key)
    throw 'ref: Invalid source: Without key ' . string(a:key)
  elseif type(a:source[a:key]) != s:TYPES[a:type]
    throw 'ref: Invalid source: Key ' . key . ' must be ' . a:type . ', ' .
    \     'but given value is' string(a:source[a:key])
  endif
endfunction



function! s:cmdpath(cmd)  " {{{2
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



function! s:echoerr(msg)  " {{{2
  echohl ErrorMsg
  echomsg a:msg
  echohl None
endfunction



function! s:uniq(list)  " {{{2
  let d = {}
  for i in a:list
    let d[i] = 0
  endfor
  return sort(keys(d))
endfunction



" Register the default sources.
function! s:register_defaults()  " {{{2
  let list = split(globpath(&runtimepath, 'autoload/ref/*.vim'), "\n")
  for name in map(list, 'fnamemodify(v:val, ":t:r")')
    try
      call ref#register(ref#{name}#define())
    catch /:E\%(117\|716\):/
    endtry
  endfor
endfunction

call s:register_defaults()



let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
