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

if !exists('g:ref_clojure_overview')  " {{{2
  let g:ref_clojure_overview = 0
endif

" constants. {{{1
let s:is_win = has('win16') || has('win32') || has('win64')

let s:path_separator = s:is_win ? ';' : ':'


let s:source = {'name': 'clojure'}  " {{{1

function! s:source.available()
  return len(g:ref_clojure_cmd)
endfunction

function! s:source.get_body(query)
  let query = a:query
  let classpath = $CLASSPATH
  let $CLASSPATH = s:classpath()
  let pre = s:precode()
  try
    if query =~ '^#".*"$'
      let query = query[2 : -2]
    else
      let res = s:clj(printf('%s(doc %s)', pre, query))
      let body = res.stdout
      if body != ''
        let query = matchstr(body, '^-*\n\zs.\{-}\ze\n')
        return query != '' ? {'body': body, 'query': query} : body
      endif
    endif
    let res = s:clj(printf('%s(find-doc "%s")', pre, escape(query, '"')))
    if res.stdout != ''
      return g:ref_clojure_overview ? s:to_overview(res.stdout)
      \                             : res.stdout
    endif
  finally
    let $CLASSPATH = classpath
  endtry
  throw printf('No document found for "%s"', query)
endfunction

function! s:source.opened(query)
  call s:syntax()
endfunction

function! s:source.get_keyword()
  let isk = &l:iskeyword
  setlocal iskeyword+=?,-,*,!,+,/,=,<,>,.,:
  let keyword = expand('<cword>')
  let &l:iskeyword = isk
  if &l:filetype ==# 'ref-clojure' && keyword =~ '.\.$'
    " This is maybe a period of the end of sentence.
    let keyword = keyword[: -2]
  endif
  return keyword
endfunction


" functions. {{{1
function! s:clj(code)
  return ref#system(ref#to_list(g:ref_clojure_cmd, '-'), a:code)
endfunction

function! s:to_overview(body)
  let parts = split(a:body, '-\{25}\n')[1 :]
  return map(parts, 'join(split(v:val, "\n")[0 : 1], "   ")')
endfunction

function! s:get_classpath(var)
  if !exists(a:var)
    return []
  endif
  let var = eval(a:var)
  return type(var) == type([]) ? var : split(var, s:path_separator)
endfunction

function! s:classpath()
  let cp = s:get_classpath('b:ref_clojure_classpath') +
  \        s:get_classpath('g:ref_clojure_classpath')
  return join(cp, s:path_separator)
endfunction

function! s:precode()
  return get(g:, 'ref_clojure_precode', '')
  \    . get(b:, 'ref_clojure_precode', '')
endfunction

function! s:syntax()
  if exists('b:current_syntax') && b:current_syntax == 'ref-clojure'
    return
  endif

  syntax clear
  syntax match refClojureDelimiter "^-\{25}\n" nextgroup=refClojureFunc
  syntax match refClojureFunc "^.\+$" contained

  highlight default link refClojureDelimiter Delimiter
  highlight default link refClojureFunc Function

  let b:current_syntax = 'ref-clojure'
endfunction

function! ref#clojure#define()
  return copy(s:source)
endfunction

call ref#register_detection('clojure', 'clojure')

let &cpo = s:save_cpo
unlet s:save_cpo
