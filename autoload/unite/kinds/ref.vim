" unite kind: ref
" Version: 0.1.1
" Author : thinca <thinca+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim

let s:kind = {
\   'name' : 'ref',
\   'default_action' : 'open',
\   'action_table': {},
\   'parents': ['openable'],
\ }

let s:kind.action_table.open = {
\   'is_selectable' : 1,
\ }

function! s:kind.action_table.open.func(candidates)
  for c in a:candidates
    call ref#open(c.action__ref_source.name, c.word, {'new': 1, 'open': 'edit'})
  endfor
endfunction

function! unite#kinds#ref#define()
  return s:kind
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
