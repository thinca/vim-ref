" A ref source for clojure.
" Version: 0.1.0
" Author : thinca <thinca+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim



" options. {{{1
if !exists('g:ref_clojure_cmd')  " {{{2
  let g:ref_clojure_cmd = executable('clj') ? 'clj' : ''
endif

let s:is_win = has('win16') || has('win32') || has('win64')

let s:path_separator = s:is_win ? ';' : ':'



let s:source = {'name': 'clojure'}  " {{{1

function! s:source.available()  " {{{2
  return len(g:ref_clojure_cmd)
endfunction

function! s:source.get_body(query)  " {{{2
  let classpath = $CLASSPATH
  let $CLASSPATH = s:classpath()
  try
    let res = s:clj(printf('(doc %s)', a:query))
    if res.stdout != ''
      return res.stdout
    endif
    let res = s:clj(printf('(find-doc "%s")', escape(a:query, '"')))
    if res.stdout != ''
      return res.stdout
    endif
  finally
    let $CLASSPATH = classpath
  endtry
  throw printf('No document found for "%s"', a:query)
endfunction



" functions. {{{1
function! s:clj(code)  " {{{2
  return ref#system(ref#to_list(g:ref_clojure_cmd, '-'), a:code)
endfunction



function! s:get_classpath(var)  " {{{2
  if !exists(a:var)
    return []
  endif
  let var = eval(a:var)
  return type(var) == type([]) ? var : split(var, s:path_separator)
endfunction



function! s:classpath()  " {{{2
  let cp = s:get_classpath('b:ref_clojure_classpath') +
  \        s:get_classpath('g:ref_clojure_classpath')
  return join(cp, s:path_separator)
endfunction



function! ref#clojure#define()  " {{{2
  return s:source
endfunction

call ref#register_detection('clojure', 'clojure')  " {{{1

let &cpo = s:save_cpo
unlet s:save_cpo
