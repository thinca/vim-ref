" A ref source for alc.
" Version: 0.1.1
" Author : soh335 <sugarbabe335@gmail.com>
"        : thinca <thinca+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim

if !exists('g:ref_alc_start_linenumber')
  let g:ref_alc_start_linenumber = 33
endif

if !exists('g:ref_alc_cmd')
  let g:ref_alc_cmd =
  \ executable('elinks') ? 'elinks -dump -no-numbering -no-references %s' :
  \ executable('w3m')    ? 'w3m -dump %s' :
  \ executable('links')  ? 'links -dump %s' :
  \ executable('lynx')   ? 'lynx -dump -nonumbers %s' :
  \ ''
endif

if !exists('g:ref_alc_encoding')
  let g:ref_alc_encoding = &termencoding
endif

function! ref#alc#available()
  return !empty(g:ref_alc_cmd)
endfunction

function! ref#alc#get_body(query)
  if type(g:ref_phpmanual_cmd) == type('')
    let cmd = split(g:ref_phpmanual_cmd, '\s\+')
  elseif type(g:ref_phpmanual_cmd) == type([])
    let cmd = copy(g:ref_phpmanual_cmd)
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
  let res = ref#system(map(cmd, 'substitute(v:val, "%s", url, "g")'))
  return s:iconv(res, g:ref_alc_encoding, &encoding)
endfunction

function! ref#alc#opened(query)
  execute "normal! ".g:ref_alc_start_linenumber."z\<CR>"
  call s:syntax(a:query)
endfunction

function! ref#alc#leave()
  syntax clear
endfunction

function! s:syntax(query)
  if exists('b:current_syntax') && b:current_syntax == 'ref-alc'
    return
  endif

  syntax clear
  let str = escape(substitute(a:query, '\s\+', '\\_s\\+', 'g'), '"')
  execute 'syntax match refAlcKeyword "\c\<'.str.'\>"'
  highlight default link refAlcKeyword Special
endfunction



" iconv() wrapper for safety.
function! s:iconv(expr, from, to)  " {{{2
  if a:from == '' || a:to == '' || a:from ==# a:to
    return a:expr
  endif
  let result = iconv(a:expr, a:from, a:to)
  return result != '' ? result : a:expr
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
