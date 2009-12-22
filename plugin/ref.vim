" Integrated reference viewer.
" Version: 0.1.0
" Author : thinca <thinca+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

if exists('g:loaded_ref') || v:version < 702
  finish
endif
let g:loaded_ref = 1

let s:save_cpo = &cpo
set cpo&vim


command! -nargs=+ -complete=customlist,ref#complete Ref call ref#ref(<q-args>)

nnoremap <silent> <Plug>(ref-keyword) :<C-u>call ref#jump(0)<CR>
vnoremap <silent> <Plug>(ref-keyword) :<C-u>call ref#jump(1)<CR>

if !exists('g:ref_no_default_key_mappings') || !g:ref_no_default_key_mappings
  silent! nmap <silent> <unique> K <Plug>(ref-keyword)
  silent! vmap <silent> <unique> K <Plug>(ref-keyword)
endif



let &cpo = s:save_cpo
unlet s:save_cpo
