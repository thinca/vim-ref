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


let s:FUNC_PATTERN = '\%([[:alnum:]_.]\+:\)\?\w\+'


let s:source = ref#man#define()

let s:source.name = 'erlang'

let s:source.man_get_body = s:source.get_body
let s:source.man_opened = s:source.opened
let s:source.man_complete = s:source.complete



function! s:source.get_body(query)  " {{{2
  let module = get(split(a:query, ':'), 0, '')
  let body = self.man_get_body(module)

  " cache
  if type(self.cache(module)) == type(0)
    " Create function list.
    let exports = matchstr(body, '\C\nEXPORTS\n\zs.\{-}\ze\n\w')
    let pat = '^ \{7}' . s:FUNC_PATTERN . '(\_[^)\n]*)\%(\_s\+->\|$\)'
    let lines = filter(split(exports, "\n"), 'v:val =~ pat')
    let pat = '^\s*\%([[:alnum:]_.]\+:\)\?\zs\w\+\ze('
    let funcs = ref#uniq(map(lines, 'module . ":" . matchstr(v:val, pat)'))
    call self.cache(module, funcs)
  endif

  return body
endfunction



function! s:source.opened(query)  " {{{2
  let query = split(a:query, ':')
  call self.man_opened(get(query, 0, ''))
  if 2 <= len(query)
    call search('^ \{7}\%(' . query[0] . ':\)\?' . query[1] . '(', 'w')
    normal! zt
  endif
endfunction



function! s:source.complete(query)  " {{{2
  if a:query =~ ':'
    let module = split(a:query, ':')[0]
    let funcs = self.cache(module)
    return type(funcs) == type(0) ? []
    \    : filter(copy(funcs), 'v:val =~ "^\\V" . a:query')
  endif
  return self.man_complete(a:query)
endfunction



function! s:source.get_keyword()  " {{{2
  return ref#get_text_on_cursor(s:FUNC_PATTERN)
endfunction



function! s:source.option(opt)  " {{{2
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



function! ref#erlang#define()  " {{{2
  return copy(s:source)
endfunction

call ref#register_detection('erlang', 'erlang')  " {{{1



let &cpo = s:save_cpo
unlet s:save_cpo
