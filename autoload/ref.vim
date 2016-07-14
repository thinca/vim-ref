" Integrated reference viewer.
" Version: 0.4.3
" Author : thinca <thinca+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim

" Options. {{{1
if !exists('g:ref_open')
  let g:ref_open = 'split'
endif

if !exists('g:ref_cache_dir')
  let g:ref_cache_dir = expand('~/.cache/vim-ref')
endif

if !exists('g:ref_use_vimproc')
  let g:ref_use_vimproc = globpath(&runtimepath, 'autoload/vimproc.vim') != ''
endif

let s:is_win = has('win16') || has('win32') || has('win64')

let s:T = {
\     'number': type(0),
\     'string': type(''),
\     'function': type(function('function')),
\     'list': type([]),
\     'dictionary': type({}),
\     'float': type(0.0),
\   }

let s:options = ['-open=', '-new', '-nocache', '-noenter', '-updatecache']

let s:sources = {}

let s:prototype = {}  " {{{1
function! s:prototype.available()
  return 1
endfunction
function! s:prototype.opened(query)
endfunction
function! s:prototype.get_keyword()
  return expand('<cword>')
endfunction
function! s:prototype.normalize(query)
  return a:query
endfunction
function! s:prototype.leave()
endfunction
function! s:prototype.cache(name, ...)
  return call('ref#cache', [self.name, a:name] + a:000)
endfunction


" API functions. {{{1

" A function for main command.
function! ref#ref(args)
  try
    let parsed = s:parse_args(a:args)
    return ref#open(parsed.source, parsed.query, parsed.options)
  catch /^ref:/
    call s:echoerr(v:exception)
  endtry
endfunction

function! ref#complete(lead, cmd, pos)
  let cmd = a:cmd[: a:pos - 1]
  try
    let parsed = s:parse_args(matchstr(cmd, '^\v.{-}R%[ef]\s+\zs.*$'))
  catch
    return []
  endtry
  try
    if has_key(parsed.options, 'nocache')
      let s:nocache = 1
    endif
    if has_key(parsed.options, 'updatecache')
      let s:updatecache = 1
    endif
    if parsed.source == '' || (parsed.query == '' && cmd =~ '\S$')
      let lead = matchstr(cmd, '-\w*$')
      if lead != ''
        return filter(copy(s:options), 'v:val =~ "^" . lead && ' .
        \      '!has_key(parsed.options, matchstr(v:val, "\\w\\+"))')
      endif
      let s = keys(filter(copy(ref#available_sources()), 'v:val.available()'))
      return filter(s, 'v:val =~ "^".a:lead')
    endif
    let source = get(s:sources, parsed.source, s:prototype)
    return has_key(source, 'complete') ? source.complete(parsed.query) : []
  finally
    unlet! s:nocache s:updatecache
  endtry
endfunction

function! ref#K(mode)
  try
    call ref#jump(a:mode)
  catch /^ref:/
    if a:mode ==# 'visual'
      call feedkeys('gvK', 'n')
    else
      call feedkeys('K', 'n')
    endif
  endtry
endfunction

function! ref#open(source, query, ...)
  try
    let options = a:0 ? a:1 : {}
    if (exists('g:ref_noenter') && g:ref_noenter) ||
    \  (exists('b:ref_noenter') && b:ref_noenter)
      let options.noenter = '1'
    endif
    if has_key(options, 'nocache')
      let s:nocache = 1
    endif
    if has_key(options, 'updatecache')
      let s:updatecache = 1
    endif
    return s:open(a:source, a:query, options)
  finally
    unlet! s:nocache s:updatecache
  endtry
endfunction

function! ref#jump(...)
  let args = copy(a:000)
  let options = {}

  for a in args
    if type(a) == s:T.dictionary
      call extend(options, a)
    endif
    unlet a
  endfor
  call filter(args, 'type(v:val) != s:T.dictionary')

  let sources = 2 <= len(args) ? args[1] : ref#detect()
  let mode = get(args, 0, 'normal')

  let last_exception = ''
  for source in s:flatten(s:to_list(sources))
    if !has_key(s:sources, source)
      throw 'ref: The source is not registered: ' . source
    endif

    let [source, query] = s:get_query(mode, source)
    if type(query) == s:T.string && query != ''
      try
        call ref#open(source, query, options)
        return
      catch /^ref:/
        let last_exception = v:exception
      endtry
    endif
  endfor

  if last_exception != ''
    throw last_exception
  endif
endfunction

function! ref#register(source)
  if type(a:source) == s:T.list
    for source in a:source
      call ref#register(source)
    endfor
    return
  elseif type(a:source) != s:T.dictionary
    throw 'ref: Invalid source: The source should be a Dictionary.'
  endif
  let source = extend(copy(s:prototype), a:source)
  call s:validate(source, 'name', 'string')
  call s:validate(source, 'available', 'function')
  call s:validate(source, 'get_body', 'function')
  call s:validate(source, 'opened', 'function')
  call s:validate(source, 'get_keyword', 'function')
  call s:validate(source, 'normalize', 'function')
  call s:validate(source, 'leave', 'function')
  let s:sources[source.name] = source
endfunction

function! ref#available_source_names()
  return keys(s:sources)
endfunction

function! ref#available_sources(...)
  return !a:0                    ? copy(s:sources) :
  \      has_key(s:sources, a:1) ? s:sources[a:1]  : 0
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

  while type(Source) == s:T.function
    " For dictionary function.
    let dict = exists('g:ref_detect_filetype') ? g:ref_detect_filetype : {}
    let s = call(Source, [&l:filetype], dict)
    unlet Source
    let Source = s
  endwhile

  if type(Source) == s:T.string || type(Source) == s:T.list
    return Source
  endif
  return ''
endfunction

function! ref#register_detection(ft, source, ...)
  if !exists('g:ref_detect_filetype')
    let g:ref_detect_filetype = {}
  endif
  let way = a:0 ? a:1 : 'ignore'
  if has_key(g:ref_detect_filetype, a:ft) && way !=# 'overwrite'
    let val = s:to_list(g:ref_detect_filetype[a:ft])
    let sources = s:to_list(a:source)
    if way ==# 'prepend'
      let g:ref_detect_filetype[a:ft] = sources + val
    elseif way ==# 'append'
      let g:ref_detect_filetype[a:ft] = val + sources
    endif
  else
    let g:ref_detect_filetype[a:ft] = a:source
  endif
endfunction


" Helper functions for source. {{{1
let s:cache = {}
function! ref#cache(source, ...)
  if a:0 == 0
    let [from, to] = ['%\(\x\x\)', '\=eval("\"\\x".submatch(1)."\"")']
    return g:ref_cache_dir == '' ? [] :
    \ map(split(glob(printf('%s/%s/*', g:ref_cache_dir, a:source)), "\n"),
    \     'substitute(fnamemodify(v:val, ":t"), from, to, "g")')
  endif

  let name = a:1
  if name is ''
    throw 'ref: The name for cache is empty.'
  endif
  let get_only = a:0 == 1
  let update = get(a:000, 2, 0) || exists('s:updatecache')
  if exists('s:nocache')
    if get_only
      return 0
    endif
    return s:gather_cache(name, a:2)
  endif

  if update || !exists('s:cache[a:source][name]')
    if !has_key(s:cache, a:source)
      let s:cache[a:source] = {}
    endif

    if g:ref_cache_dir != ''
      let file = printf('%s/%s/%s', g:ref_cache_dir, a:source, s:escape(name))
      if filereadable(file)
        let s:cache[a:source][name] = readfile(file)
      endif
    endif

    if update || !has_key(s:cache[a:source], name)
      if get_only
        return 0
      endif
      let s:cache[a:source][name] = s:gather_cache(name, a:2)

      if g:ref_cache_dir != ''
        let dir = fnamemodify(file, ':h')
        if !isdirectory(dir)
          call mkdir(dir, 'p')
        endif
        call writefile(s:cache[a:source][name], file)
      endif
    endif
  endif

  return s:cache[a:source][name]
endfunction

function! ref#rmcache(...)
  if g:ref_cache_dir == ''
    return
  endif
  if !a:0
    for source in split(glob(g:ref_cache_dir . '/*'), "\n")
      call ref#rmcache(fnamemodify(source, ':t'))
    endfor
    return
  endif
  let source = a:1
  let names = 2 <= a:0 ? ref#to_list(a:2) : ref#cache(source)
  for name in names
    call delete(printf('%s/%s/%s', g:ref_cache_dir, source, s:escape(name)))
  endfor

  if !has_key(s:cache, source)
    return
  endif
  if a:0
    for name in names
      if has_key(s:cache[source], name)
        call remove(s:cache[source], name)
      endif
    endfor
  else
    call remove(s:cache, source)
  endif
endfunction

function! ref#system(args, ...)
  let args = ref#to_list(a:args)
  if g:ref_use_vimproc
    try
      let stdout = a:0 ? vimproc#system(args, a:1) : vimproc#system(args)
      return {
      \ 'result': vimproc#get_last_status(),
      \ 'stdout': stdout,
      \ 'stderr': vimproc#get_last_errmsg(),
      \ }
    catch
    endtry
  endif

  if s:is_win
    " Here is a command that want to execute.
    "   something.bat keyword
    "
    " The command is actually executed by the following form.
    "   cmd.exe /c something.bat keyword
    "
    " Any arguments may include whitespace and some character needs escaping,
    " so we need to quote each arguments.
    "   cmd.exe /c "something.bat" "keyword"
    "
    " But cmd.exe handles it as one argument like ``something.bat" "keyword''.
    " So, we have to quote the command again.
    "   cmd.exe /c ""something.bat" "keyword""
    "
    " Here, cmd.exe behaves strangely.  When the command is a .bat file,
    " %~dp0 in the file is expanded to the current directory.
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
    if exists('+shellxescape') && &shellxquote ==# '('
      let esc_chars = &shellxescape
      let save_shellxescape = &shellxescape
      let &shellxescape = ''
    else
      let esc_chars = '"&|<>()@^'
    endif
    let esc_pat = '[' . escape(esc_chars, '\]') . ']'
    let cmd = join(map(args,
    \   'q . substitute(v:val, esc_pat, "^\\0", "g") . q'),
    \   ' ')
    if !exists('+shellxquote') || &shellxquote ==# ''
      let cmd = '( ' . cmd . ' )'
    endif
  else
    let cmd = join(map(args, 'shellescape(v:val)'))
  endif
  let save_shellredir = &shellredir
  let stderr_file = tempname()
  let &shellredir = '>%s 2>' . shellescape(stderr_file) . ' '
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
    if exists('save_shellxescape')
      let &shellxescape = save_shellxescape
    endif
  endtry

  return {
  \ 'result': v:shell_error,
  \ 'stdout': stdout,
  \ 'stderr': stderr
  \ }
endfunction

function! ref#to_list(...)
  let list = []
  for a in a:000
    let list += type(a) == s:T.string ? split(a) : s:to_list(a)
    unlet a
  endfor
  return list
endfunction

function! ref#uniq(list)
  let d = {}
  for i in a:list
    let d['_' . i] = 0
  endfor
  return map(sort(keys(d)), 'v:val[1 :]')
endfunction

function! ref#get_text_on_cursor(pat)
  let line = getline('.')
  let pos = col('.')
  let s = 0
  while s < pos
    let [s, e] = [match(line, a:pat, s), matchend(line, a:pat, s)]
    if s < 0
      break
    elseif s < pos && pos <= e
      return line[s : e - 1]
    endif
    let s += 1
  endwhile
  return ''
endfunction


" Misc. {{{1
function! s:initialize_buffer(source)
  setlocal nobuflisted
  setlocal buftype=nofile noswapfile
  setlocal bufhidden=delete
  setlocal nonumber
  setlocal norelativenumber

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

function! s:parse_args(argline)
  let res = {'source': '', 'query': '', 'options': {}}
  let rest = a:argline
  try
    while rest =~ '\S'
      let [word, rest] = matchlist(rest, '\v^(-?\w*%(\=\S*)?)\s*(.*)$')[1 : 2]
      if word =~# '^-'
        let [word, value] = matchlist(word, '\v^-(\w*)%(\=(.*))?$')[1 : 2]
        if word != ''
          let res.options[word] = value
        endif
      else
        let [res.source, res.query, rest] = [word, rest, '']
      endif
    endwhile
  catch
    throw 'ref: Invalid argument: ' . a:argline
  endtry

  return res
endfunction

function! s:gather_cache(name, gather)
  let type = type(a:gather)
  let cache =
  \  type == s:T.function ? a:gather(a:name) :
  \  type == s:T.dictionary && has_key(a:gather, 'call')
  \    && type(a:gather.call) == s:T.function ?
  \       a:gather.call(a:name) :
  \  type == s:T.string ? eval(a:gather) :
  \  type == s:T.list ? a:gather : []

  if type(cache) == s:T.list
    return cache
  elseif type(cache) == s:T.string
    return split(cache, "\n")
  endif
  throw 'ref: Invalid results of cache: ' . string(cache)
endfunction

function! s:get_query(mode, source)
  let [source, query] = [a:source, '']
  if a:mode ==# 'normal'
    let pos = getpos('.')
    let res = s:sources[source].get_keyword()
    call setpos('.', pos)
    if type(res) == s:T.list && len(res) == 2
      let [source, query] = res
    else
      let query = res
    endif

  elseif a:mode =~# '^\v%(visual|line|char|block)$'
    let vm = {
    \ 'visual': visualmode(),
    \ 'line': 'V',
    \ 'char': 'v',
    \ 'block': "\<C-v>" }[a:mode]
    let [sm, em] = a:mode ==# 'visual' ? ['<', '>'] : ['[', ']']

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
  return [source, query]
endfunction

function! s:open(source, query, options)
  if !has_key(s:sources, a:source)
    throw 'ref: The source is not registered: ' . a:source
  endif
  let source = s:sources[a:source]
  if !source.available()
    throw 'ref: This source is unavailable: ' . a:source
  endif

  let query = source.normalize(a:query)
  try
    let res = source.get_body(query)
    if type(res) == s:T.dictionary
      let dict = res
      unlet res
      let res = dict.body
      if has_key(dict, 'query')
        let query = dict.query
      endif
    endif
  catch
    let mes = v:exception
    if mes =~# '^Vim'
      let mes .= "\n" . v:throwpoint
    endif
    if mes =~# '^ref:'
      let mes = matchstr(mes, '^ref:\s*\zs.*')
    endif
    throw printf('ref: %s: %s', a:source, mes)
  endtry

  if type(res) == s:T.list
    let newres = join(res, "\n")
    unlet! res
    let res = newres
  endif
  if type(res) != s:T.string || res == ''
    throw printf('ref: %s: The body is empty. (query=%s)', a:source, query)
  endif

  let pos = getpos('.')

  if has_key(a:options, 'noenter')
    let w:ref_back = 1
  endif

  let bufnr = 0
  if !has_key(a:options, 'new')
    for i in range(0, winnr('$'))
      let n = winbufnr(i)
      if getbufvar(n, '&filetype') =~# '^ref-'
        if i != 0
          execute i 'wincmd w'
        endif
        let bufnr = n
        break
      endif
    endfor
  endif

  if bufnr == 0
    silent! execute has_key(a:options, 'open') ? a:options.open : g:ref_open
    enew
    call s:initialize_buffer(a:source)
  else
    setlocal modifiable noreadonly
    % delete _
    if b:ref_source !=# a:source
      syntax clear
      call source.leave()
    endif
  endif

  " FIXME: not cool...
  let s:res = res
  call s:open_source(a:source, query, 'silent :1 put = s:res | 1 delete _')
  unlet! s:res

  if !(0 <= b:ref_history_pos
  \ && b:ref_history[b:ref_history_pos][0] ==# a:source
  \ && b:ref_history[b:ref_history_pos][1] ==# query)
    let b:ref_history_pos += 1
    if b:ref_history_pos < len(b:ref_history)
      unlet! b:ref_history[b:ref_history_pos :]
    endif
    if 0 < b:ref_history_pos
      let b:ref_history[-1][3] = pos
    endif
    call add(b:ref_history, [a:source, query, changenr(), []])
  endif

  if has_key(a:options, 'noenter')
    for t in range(1, tabpagenr('$'))
      for w in range(1, winnr('$'))
        if gettabwinvar(t, w, 'ref_back')
          execute 'tabnext' t
          execute w 'wincmd w'
          unlet! w:ref_back
        endif
      endfor
    endfor
  endif
endfunction

" A function for key mapping for K.
function! s:open_source(source, query, open_cmd)
  if !exists('b:ref_source') || b:ref_source !=# a:source
    let b:ref_source = a:source
    execute 'setlocal filetype=ref-' . a:source
  endif

  let bufname = printf('[ref-%s:%s]', b:ref_source,
  \                    substitute(a:query, '[\r\n]', '', 'g'))
  if s:is_win
    " In Windows, '*' cannot be used for a buffer name.
    let bufname = substitute(bufname, '\*', '', 'g')
  endif

  setlocal modifiable noreadonly

  silent! file `=bufname`

  execute a:open_cmd

  1  " Move the cursor to the first line.

  call s:sources[b:ref_source].opened(a:query)

  setlocal nomodifiable readonly
endfunction

function! s:move_history(n)
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
  call s:open_source(source, query, 'silent! undo ' . changenr)
  call setpos('.', pos)
endfunction

function! s:dump_history()
  for i in range(len(b:ref_history))
    echo printf('%s%3d %s: %s', i == b:ref_history_pos ? '>' : ' ', i + 1,
      \ b:ref_history[i][0], b:ref_history[i][1])
  endfor
  let i = input('Enter nr of choice (CR to abort):')
  if i =~ '\d\+'
    call s:move_history(i - b:ref_history_pos - 1)
  endif
endfunction

function! s:validate(source, key, type)
  if !has_key(a:source, a:key)
    throw 'ref: Invalid source: Without key ' . string(a:key)
  elseif type(a:source[a:key]) != s:T[a:type]
    throw 'ref: Invalid source: Key ' . key . ' must be ' . a:type . ', ' .
    \     'but given value is' . string(a:source[a:key])
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

function! s:escape(name)
    return substitute(a:name, '[:;*?"<>|/\\%]',
    \                 '\=printf("%%%02x", char2nr(submatch(0)))', 'g')
endfunction

function! s:echoerr(msg)
  echohl ErrorMsg
  for line in split(a:msg, "\n")
    echomsg line
  endfor
  echohl None
endfunction

function! s:to_list(expr)
  return type(a:expr) == s:T.list ? a:expr : [a:expr]
endfunction

function! s:flatten(list)
  let list = []
  for i in a:list
    if type(i) == s:T.list
      let list += s:flatten(i)
    else
      call add(list, i)
    endif
    unlet! i
  endfor
  return list
endfunction


" Register the default sources. {{{1
function! s:register_defaults()
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
