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

function! ref#alc#available()
  return g:ref_alc_cmd != '' 
endfunction

function! ref#alc#get_body(query)
  let str = substitute(a:query, '\s', '+', 'g')
  return ref#system(printf(g:ref_alc_cmd, 'http://eow.alc.co.jp/'.str.'/UTF-8/?ref=sa'))
endfunction

function! ref#alc#opened(query)
  execute "normal! ".g:ref_alc_start_linenumber."z\<CR>"
  call s:syntax(a:query)
endfunction

function! ref#alc#complete(query)
endfunction

function! ref#alc#get_keyword()
  return expand('<cword>')
endfunction

function! ref#alc#leave()
  syntax clear
  unlet! b:current_syntax
endfunction

call ref#detect#register('alc', 'alc')

function! s:syntax(query)
  if exists('b:current_syntax') && b:current_syntax == 'ref-alc'
    return
  endif

  syntax clear
  unlet! b:current_syntax
  let str = substitute(a:query, '\s\+', '\\|', 'g')
  execute 'syntax match refAlcKeyword "\c\<'.str.'\>"'
  highlight default link refAlcKeyword Special
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
