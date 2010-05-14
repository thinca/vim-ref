" A ref source for Erlang.
" Version: 0.1.0
" Author : thinca <thinca+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim



" config. {{{1
if !exists('g:ref_erlang_cmd')  " {{{2
  let g:ref_erlang_cmd = executable('erl') ? 'erl' : ''
endif



let s:source = ref#man#define()

let s:source.name = 'erlang'

function! s:source.option(opt)  " {{{2
  if a:opt ==# 'cmd'
    return ref#to_list(g:ref_erlang_cmd, '-man')

  elseif a:opt ==# 'manpath'
    if !exists('g:ref_erlang_manpath')  " {{{2
      let g:ref_erlang_manpath = ref#system(ref#to_list(g:ref_erlang_cmd,
      \ '-noshell -eval io:fwrite(code:root_dir()). -s init stop')).stdout
      \ . '/man'
    endif
    return g:ref_erlang_manpath

  endif
  return ''
endfunction



function! ref#erlang#define()  " {{{2
  return copy(s:source)
endfunction

call ref#register_detection('erlang', 'erlang')  " {{{1



let &cpo = s:save_cpo
unlet s:save_cpo
