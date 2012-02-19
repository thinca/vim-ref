" A ref source for R help.
" Version: 0.1
" Author : Kozo Nishida <knishida@riken.jp>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim

" config. {{{1
if !exists('g:ref_R_cmd')  " {{{2
  let g:ref_R_cmd = executable('R') ? 'R -q -e' : ''
endif

let s:source = {'name': 'R'}  " {{{1

function! s:source.available()
  return !empty(g:ref_R_cmd)
endfunction

function! s:source.get_body(query)
  if a:query != ''
    let content = ref#system(ref#to_list(g:ref_R_cmd, a:query)).stdout
    return content
  endif
endfunction

function! ref#R#define()
  return copy(s:source)
endfunction

if s:source.available()
  call ref#register_detection('R', 'R')
endif

let &cpo = s:save_cpo
unlet s:save_cpo
