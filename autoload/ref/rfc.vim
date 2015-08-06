" A ref source for rfc.
" Version: 0.2.1
" Author : tyru <tyru.exe@gmail.com>
" ref-alc Author : soh335 <sugarbabe335@gmail.com>
"                : thinca <thinca+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim

" options. {{{1
if !exists('g:ref_rfc_start_linenumber')  " {{{2
  let g:ref_rfc_start_linenumber = 33
endif

if !exists('g:ref_rfc_cmd')  " {{{2
  let g:ref_rfc_cmd =
  \ executable('elinks') ? 'elinks -dump -no-numbering -no-references %s' :
  \ executable('w3m')    ? 'w3m -dump %s' :
  \ executable('links')  ? 'links -dump %s' :
  \ executable('lynx')   ? 'lynx -dump -nonumbers %s' :
  \ len(globpath(&rtp, 'autoload/wwwrenderer.vim')) > 0
  \   ? '=wwwrenderer#render("%s")' :
  \ ''
endif

if !exists('g:ref_rfc_encoding')  " {{{2
  let g:ref_rfc_encoding = &termencoding
endif

if !exists('g:ref_rfc_use_cache')  " {{{2
  let g:ref_rfc_use_cache = 0
endif



let s:source = {'name': 'rfc'}  " {{{1

function! s:source.available()
  return !empty(g:ref_rfc_cmd)
endfunction

function! s:source.get_body(query)
  if type(g:ref_rfc_cmd) == type('')
    let cmd = split(g:ref_rfc_cmd, '\s\+')
  elseif type(g:ref_rfc_cmd) == type([])
    let cmd = copy(g:ref_rfc_cmd)
  else
    return ''
  endif

  let str = tolower(a:query)
  if str !~? '^rfc'
    let str = 'rfc' . str
  endif
  if str !~? '^rfc\d\+$'
    return ''
  endif

  let url = 'http://tools.ietf.org/html/' . str
  call map(cmd, 'substitute(v:val, "%s", url, "g")')
  if len(cmd) > 0 && cmd[0] =~ '^='
    let res = eval(join(cmd, ' ')[1:])
  elseif len(cmd) > 0 && cmd[0] =~ '^:'
    redir => res
    silent! exe join(cmd, ' ')[1:]
    redir END
  elseif g:ref_rfc_use_cache
    let expr = 'ref#system(' . string(cmd) . ').stdout'
    let res = join(ref#cache('rfc', str, expr), "\n")
  else
    let res = ref#system(cmd).stdout
  endif
  return s:iconv(res, g:ref_rfc_encoding, &encoding)
endfunction

function! s:source.opened(query)
  execute "normal! ".g:ref_rfc_start_linenumber."z\<CR>"
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
  execute 'syntax match refRfcKeyword "\c'.str.'"'
  highlight default link refRfcKeyword Special
endfunction

" iconv() wrapper for safety.
function! s:iconv(expr, from, to)
  if a:from == '' || a:to == '' || a:from ==# a:to
    return a:expr
  endif
  let result = iconv(a:expr, a:from, a:to)
  return result != '' ? result : a:expr
endfunction

function! ref#rfc#define()
  return s:source
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
