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
  let query = a:query
  let classpath = $CLASSPATH
  let $CLASSPATH = s:classpath()
  let pre = s:precode()
  try
    if query =~ '^/.\+/$'
      let query = query[1 : -2]
    else
      let res = s:clj(printf('%s(doc %s)', pre, query))
      if res.stdout != ''
        return res.stdout
      endif
    endif
    let res = s:clj(printf('%s(find-doc "%s")', pre, escape(query, '"')))
    if res.stdout != ''
      return res.stdout
    endif
  finally
    let $CLASSPATH = classpath
  endtry
  throw printf('No document found for "%s"', query)
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



function! s:precode()  " {{{2
  return get(g:, 'ref_clojure_precode', '')
  \    . get(b:, 'ref_clojure_precode', '')
endfunction



function! ref#clojure#define()  " {{{2
  return copy(s:source)
endfunction

call ref#register_detection('clojure', 'clojure')  " {{{1

let &cpo = s:save_cpo
unlet s:save_cpo
