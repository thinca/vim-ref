" A ref source to use the appropriate source.
" Version: 0.0.1
" Author : thinca <thinca+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim



function! ref#detect#available()
  return strlen(s:detect())
endfunction



function! ref#detect#get_body(query)
  return ref#{s:detect()}#get_body(a:query)
endfunction



function! ref#detect#opened(query)
  if exists('*ref#{s:detect()}#opened')
    return ref#{s:detect()}#opened(a:query)
  endif
endfunction



function! ref#detect#complete(query)
  if !exists('*ref#{s:detect()}#complete')
    return []
  endif
  return ref#{s:detect()}#complete(a:query)
endfunction



function! ref#detect#get_keyword()
  if !exists('*ref#{s:detect()}#complete')
    return expand('<cword>')
  endif
  return ref#{s:detect()}#get_keyword()
endfunction



function! ref#detect#detect()
  call ref#list()  " load sources.  (It is not too good code.)
  return s:detect()
endfunction



function! ref#detect#register(ft, source)
  if !exists('g:ref_detect_filetype')
    let g:ref_detect_filetype = {}
  endif
  if !has_key(g:ref_detect_filetype, a:ft)
    let g:ref_detect_filetype[a:ft] = a:source
  endif
endfunction



function! s:detect()
  let source = ''
  if exists('b:ref_source')
    let source = b:ref_source
  elseif exists('g:ref_detect_filetype[&l:filetype]')
    let source = g:ref_detect_filetype[&l:filetype]
  endif
  if source == 'detect' || source == ''
    let source = ''
  endif
  return source
endfunction



let &cpo = s:save_cpo
unlet s:save_cpo
