" A ref source for alc.
" Version: 0.2.1
" Author : soh335 <sugarbabe335@gmail.com>
"        : thinca <thinca+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim

" options. {{{1
if !exists('g:ref_alc_start_linenumber')  " {{{2
  let g:ref_alc_start_linenumber = 33
endif

if !exists('g:ref_alc_cmd')  " {{{2
  let g:ref_alc_cmd =
  \ executable('elinks') ? 'elinks -dump -no-numbering -no-references %s' :
  \ executable('w3m')    ? 'w3m -dump %s' :
  \ executable('links')  ? 'links -dump %s' :
  \ executable('lynx')   ? 'lynx -dump -nonumbers %s' :
  \ len(globpath(&rtp, 'autoload/wwwrenderer.vim')) > 0
  \   ? ':wwwrenderer#render("%s")' :
  \ ''
endif

if !exists('g:ref_alc_encoding')  " {{{2
  let g:ref_alc_encoding = &termencoding
endif

if !exists('g:ref_alc_use_cache')  " {{{2
  let g:ref_alc_use_cache = 0
endif



let s:source = {'name': 'alc'}  " {{{1

function! s:source.available()
  return !empty(g:ref_alc_cmd)
endfunction

function! s:source.get_body(query)
  if type(g:ref_alc_cmd) == type('')
    let cmd = split(g:ref_alc_cmd, '\s\+')
  elseif type(g:ref_alc_cmd) == type([])
    let cmd = copy(g:ref_alc_cmd)
  else
    return ''
  endif

  let org = s:iconv(a:query, &encoding, 'utf-8')
  let str = ''
  for i in range(strlen(org))
    let c = org[i]
    let str .= c =~ '\w' ? c : printf('%%%02X', char2nr(c))
  endfor

  let url = 'http://eow.alc.co.jp/' . str . '/UTF-8/'
  call map(cmd, 'substitute(v:val, "%s", url, "g")')
  if len(cmd) > 0 && cmd[0] =~ '^:'
    return eval(join(cmd, ' ')[1:])
  elseif g:ref_alc_use_cache
    let expr = 'ref#system(' . string(cmd) . ').stdout'
    let res = join(ref#cache('alc', a:query, expr), "\n")
  else
    let res = ref#system(cmd).stdout
  endif
  return s:iconv(res, g:ref_alc_encoding, &encoding)
endfunction

function! s:source.opened(query)
  execute "normal! ".g:ref_alc_start_linenumber."z\<CR>"
  call s:syntax(a:query)
endfunction

function! s:source.normalize(query)
  return substitute(substitute(a:query, '\_s\+', ' ', 'g'), '^ \| $', '', 'g')
endfunction


" misc. {{{1
function! s:syntax(query)
  syntax clear
  let str = escape(substitute(a:query, '\s\+', '\\_s\\+', 'g'), '"')
  if str =~# '^[[:print:][:space:]]\+$'
    let str = '\<' . str . '\>'
  endif
  execute 'syntax match refAlcKeyword "\c'.str.'"'
  highlight default link refAlcKeyword Special
endfunction

" iconv() wrapper for safety.
function! s:iconv(expr, from, to)
  if a:from == '' || a:to == '' || a:from ==# a:to
    return a:expr
  endif
  let result = iconv(a:expr, a:from, a:to)
  return result != '' ? result : a:expr
endfunction

function! ref#alc#define()
  return s:source
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
