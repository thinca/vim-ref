" A ref source for Erlang.
" Version: 0.1.2
" Author : thinca <thinca+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim



" config. {{{1
if !exists('g:ref_erlang_cmd')  " {{{2
  let g:ref_erlang_cmd = executable('erl') ? 'erl' : ''
endif


let s:FUNC_PATTERN = '\%([[:alnum:]_.]\+:\)\?\w\+'


let s:source = ref#man#define()  " {{{1

let s:source.name = 'erlang'

let s:source.man_get_body = s:source.get_body
let s:source.man_opened = s:source.opened
let s:source.man_complete = s:source.complete



function! s:source.get_body(query)
  let query = a:query
  let module = get(split(query, ':'), 0, '')
  try
    let body = self.man_get_body(module)
  catch /^\@<!\%(Vim\)/
    let query = 'erlang:' . module
    let module = 'erlang'
    let bif = self._func_list(module)
    let i = index(bif, query)
    if i < 0
      throw v:exception
    endif
    let body = self.man_get_body(module)
  endtry

  " cache
  call self._func_list(module, body)

  return {'body': body, 'query': query}
endfunction

function! s:source.opened(query)
  let query = split(a:query, ':')
  call self.man_opened(get(query, 0, ''))
  if 2 <= len(query)
    call search('^ \{7}\%(' . query[0] . ':\)\?' . query[1] . '(', 'w')
    normal! zt
  endif
endfunction

function! s:source.complete(query)
  if a:query =~ ':'
    let module = split(a:query, ':')[0]
    let funcs = self._func_list(module)
    return filter(copy(funcs), 'v:val =~ "^\\V" . a:query')
  endif
  return self.man_complete(a:query)
endfunction

function! s:source.get_keyword()
  return ref#get_text_on_cursor(s:FUNC_PATTERN)
endfunction

function! s:source.option(opt)
  if a:opt ==# 'cmd'
    return ref#to_list(g:ref_erlang_cmd, '-man')

  elseif a:opt ==# 'manpath'
    if !exists('g:ref_erlang_manpath')
      let g:ref_erlang_manpath = ref#system(ref#to_list(g:ref_erlang_cmd,
      \ '-noshell -eval io:fwrite(code:root_dir()). -s init stop')).stdout
      \ . '/man'
    endif
    return g:ref_erlang_manpath

  endif
  return ''
endfunction

function! s:source._func_list(module, ...)
  " cache
  let funcs = self.cache(a:module)
  if type(funcs) == type(0)
    unlet funcs
    try
      let body = a:0 ? a:1 : self.man_get_body(a:module)
    catch
      return []
    endtry
    " Create function list.
    let exports = matchstr(body, '\C\nEXPORTS\n\zs.\{-}\ze\n\w')
    let pat = '^ \{7}' . s:FUNC_PATTERN . '(\_[^)\n]*)\%(\_s\+->\|$\)'
    let lines = filter(split(exports, "\n"), 'v:val =~ pat')
    let pat = '^\s*\%([[:alnum:]_.]\+:\)\?\zs\w\+\ze('
    let funcs = ref#uniq(map(lines, 'a:module . ":" . matchstr(v:val, pat)'))
    call self.cache(a:module, funcs)
  endif
  return funcs
endfunction

function! ref#erlang#define()
  return copy(s:source)
endfunction

call ref#register_detection('erlang', 'erlang')

let &cpo = s:save_cpo
unlet s:save_cpo
