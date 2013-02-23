" A ref source for redis.
" Version: 0.0.1
" Author : walf443 <walf443@gmail.com>
"                : thinca <thinca+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

" this code is based from autoload/ref/rfc.vim
let s:save_cpo = &cpo
set cpo&vim

" options. {{{1
if !exists('g:ref_redis_start_linenumber')  " {{{2
  let g:ref_redis_start_linenumber = 5
endif

if !exists('g:ref_redis_cmd')  " {{{2
  let g:ref_redis_cmd =
  \ executable('elinks') ? 'elinks -dump -no-numbering -no-references %s' :
  \ executable('w3m')    ? 'w3m -dump %s' :
  \ executable('links')  ? 'links -dump %s' :
  \ executable('lynx')   ? 'lynx -dump -nonumbers %s' :
  \ len(globpath(&rtp, 'autoload/wwwrenderer.vim')) > 0
  \   ? ':wwwrenderer#render("%s")' :
  \ ''
endif

if !exists('g:ref_redis_encoding')  " {{{2
  let g:ref_redis_encoding = &termencoding
endif

if !exists('g:ref_redis_use_cache')  " {{{2
  let g:ref_redis_use_cache = 0
endif

let s:source = {'name': 'redis'}  " {{{1

function! s:source.available()
  return !empty(g:ref_redis_cmd)
endfunction

function! s:source.get_body(query)
  if type(g:ref_redis_cmd) == type('')
    let cmd = split(g:ref_redis_cmd, '\s\+')
  elseif type(g:ref_redis_cmd) == type([])
    let cmd = copy(g:ref_redis_cmd)
  else
    return ''
  endif


  let str = tolower(a:query)
  " if str !~? '^redis'
  "   let str = 'redis' . str
  " endif
  " if str !~? '^redis\d\+$'
  "   return ''
  " endif

  let url = 'http://redis.io/commands/' . str
  call map(cmd, 'substitute(v:val, "%s", url, "g")')
  if len(cmd) > 0 && cmd[0] =~ '^:'
    return eval(join(cmd, ' ')[1:])
  elseif g:ref_redis_use_cache
    let expr = 'ref#system(' . string(cmd) . ').stdout'
    let res = join(ref#cache('redis', str, expr), "\n")
  else
    let res = ref#system(cmd).stdout
  endif
  return s:iconv(res, g:ref_redis_encoding, &encoding)
endfunction

function! s:source.opened(query)
  execute "normal! ".g:ref_redis_start_linenumber."z\<CR>"
  call s:syntax(a:query)
endfunction

function! s:source.normalize(query)
  return substitute(substitute(a:query, '\_s\+', ' ', 'g'), '^ \| $', '', 'g')
endfunction


" misc. {{{1
function! s:syntax(query)
endfunction

" iconv() wrapper for safety.
function! s:iconv(expr, from, to)
  if a:from == '' || a:to == '' || a:from ==# a:to
    return a:expr
  endif
  let result = iconv(a:expr, a:from, a:to)
  return result != '' ? result : a:expr
endfunction

function! ref#redis#define()
  return s:source
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
