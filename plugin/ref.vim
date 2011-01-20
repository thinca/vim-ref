" Integrated reference viewer.
" Version: 0.4.3
" Author : thinca <thinca+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

if exists('g:loaded_ref')
  finish
endif
let g:loaded_ref = 1

let s:save_cpo = &cpo
set cpo&vim


command! -nargs=+ -complete=customlist,ref#complete Ref call ref#ref(<q-args>)

nnoremap <silent> <Plug>(ref-keyword) :<C-u>call ref#K('normal')<CR>
vnoremap <silent> <Plug>(ref-keyword) :<C-u>call ref#K('visual')<CR>

if !exists('g:ref_no_default_key_mappings') || !g:ref_no_default_key_mappings
  silent! nmap <silent> <unique> K <Plug>(ref-keyword)
  silent! vmap <silent> <unique> K <Plug>(ref-keyword)
endif



let &cpo = s:save_cpo
unlet s:save_cpo
