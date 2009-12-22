" Integrated reference viewer.
" Version: 0.1.0
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
    let reg = @@
    normal! gvy
    let query = @@
    let @@ = reg
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
      \  type(a:gather) == type(function('function')) ? a:gather() :
      \  type(a:gather) == type({}) && has_key(a:gather, 'call') &&
      \  type(a:gather.call) == type(function('function')) ? a:gather.call() :
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
  if has('win16') || has('win32') || has('win64')
    " In Windows, '*' cannot be used for a buffer name.
    let bufname = substitute(bufname, '\*', '', 'g')
  endif
  noautocmd silent! file `=bufname`

  execute a:open_cmd

  if exists('*ref#{b:ref_source}#opened')
    call ref#{b:ref_source}#opened(a:query)
  endif

  setlocal nomodifiable readonly
  1  " Move the cursor to the first line.
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
