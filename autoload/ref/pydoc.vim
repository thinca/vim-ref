" A ref source for pydoc.
" Version: 0.4.2
" Author : thinca <thinca+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim

" options. {{{1
if !exists('g:ref_pydoc_cmd')  " {{{2
  let g:ref_pydoc_cmd = executable('python') ? 'python -m pydoc' : ''
endif

if !exists('g:ref_pydoc_complete_head')  " {{{2
  let g:ref_pydoc_complete_head = 0
endif


let s:source = {'name': 'pydoc'}  " {{{1

function! s:source.available()
  return !empty(g:ref_pydoc_cmd)
endfunction

function! s:source.get_body(query)
  if a:query != ''
    let content = ref#system(ref#to_list(g:ref_pydoc_cmd, a:query)).stdout
    if content !~# '^no Python documentation found'
      return content
    endif
  endif

  let list = self.complete(a:query)
  if list == []
    throw split(content, "\n")[0]
  endif
  if len(list) == 1
    return ref#system(ref#to_list(g:ref_pydoc_cmd, list)).stdout
  endif
  return list
endfunction

function! s:source.opened(query)
  call s:syntax(s:get_info()[0])
endfunction

function! s:source.complete(query)
  let cmd = ref#to_list(g:ref_pydoc_cmd, '-k .')
  let mapexpr = 'matchstr(v:val, "^[[:alnum:]._]*")'
  let all_list = self.cache('list',
  \                    printf('map(split(ref#system(%s).stdout, "\n"), %s)',
  \                           string(cmd), string(mapexpr)))

  if g:ref_pydoc_complete_head
    let q = a:query == '' || a:query =~ '\s$' ? '' : split(a:query)[-1]
    let all_list = s:head(all_list, q)
  endif

  let list = filter(copy(all_list), 'v:val =~# "^\\V" . a:query')
  if !empty(list)
    return list
  endif
  return filter(copy(all_list), 'v:val =~# "\\V" . a:query')
endfunction

function! s:source.get_keyword()
  if &l:filetype ==# 'ref-pydoc'
    let [type, name, scope] = s:get_info()

    if type ==# 'package' || type ==# 'module'
      let line = getline('.')

      let secline = search('^\u[A-Z ]*\u$', 'bnW')
      let section = secline == 0 ? '' : getline(secline)

      if section ==# 'PACKAGE CONTENTS'
        let package = matchstr(line, '^\s*\zs\S\+')
        if package != ''
          return name . '.' . package
        endif
      endif

      if section ==# 'CLASSES'
        let class = matchstr(line, '^\s*class \zs\k\+')
        if class != ''
          return printf('%s.%s', name, class)
        endif

        let class = matchstr(line, '^\s*\zs[[:alnum:].]\+')
        if class != ''
          if type ==# 'package'
            return class
          endif
          return printf('%s.%s', name, class)
        endif

        let class = matchstr(line, '^\s*\zs\k\+\ze = class')
        if class != ''
          return printf('%s.%s', name, class)
        endif

        let method = matchstr(line, '^     |  \zs\k\+\ze(.*)$')
        if method != ''
          call search('^    \%(class \k\+\|\k\+\ze = class\)', 'beW')
          return printf('%s.%s.%s', name, expand('<cword>'), method)
        endif
      endif

      let func = matchstr(line, '^    \zs\k\+\ze(.*)$')
      if func != ''
        return name . '.' . func
      endif

    elseif type ==# 'class'
      let m = matchstr(getline('.'), '^ |  \zs\k\+\ze(.*)$')
      if m != ''
        return printf('%s.%s.%s', scope, name, m)
      endif

    endif

    if type !=# 'list'
      " xxx.yy*y.zzzClass -> xxx.yyy (* means cursor)
      let line = getline('.')
      let [pre, post] = [line[: col('.') - 2], line[col('.') - 1 :]]
      let kwd = matchstr(pre, '\v%(\k|\.)*$') . matchstr(post, '^\k*')
      if kwd != ''
        return kwd
      endif
    endif
  else
    " In Python code.
    let module = s:ExpandModulePath()
    if module != ''
      return module
    endif
  endif

  return ref#get_text_on_cursor('[[:alnum:].]\+')
endfunction


" functions {{{1

" Get informations of current document.
" [type, name, scope]
" type:
" - package
" - module
" - class
" - method
" - function
" - list (matched list)
" name:
"   package name, module name, class name, method name, or function name.
" scope:
"   Scope.
function! s:get_info()
  let isk = &l:isk
  setlocal isk& isk+=.

  let list = matchlist(getline(1),
  \  '\v^Help on %(built-in )?(%(\w|-)+)%( (\k+))?%( in %(\w+ )?(\k+))?:')

  let &l:isk = isk
  if list == []
    return ['list', '', '']
  endif
  return list[1 : 3]
endfunction

function! s:syntax(type)
  if a:type ==# 'list'
    syntax clear
    return
  elseif exists('b:current_syntax') && b:current_syntax ==# 'ref-pydoc'
    return
  endif

  syntax clear


  syntax match refPydocHeader '^[[:upper:][:space:]]\+$'
  syntax match refPydocClass '^    class\>' nextgroup=refPydocClassName skipwhite
  syntax match refPydocClassName '\k\+' contained
  syntax match refPydocMethod '\k\+\ze('
  syntax match refPydocVertical '^\s\+|'
  syntax match refPydocHorizon '--------------------------------------------*'

  highlight default link refPydocHeader Type
  highlight default link refPydocClass Statement
  highlight default link refPydocClassName Identifier
  highlight default link refPydocMethod Function
  highlight default link refPydocVertical PreProc
  highlight default link refPydocHorizon PreProc

  let b:current_syntax = 'ref-pydoc'
endfunction

function! s:head(list, query)
  let pat = '^\V' . a:query . '\v\w*(\.)?\zs.*$'
  return ref#uniq(map(filter(copy(a:list), 'v:val =~# pat'),
  \             'substitute(v:val, pat, "", "")'))
endfunction

function! s:ExpandModulePath()
  " Extract the 'word' at the cursor, expanding leftwards across identifiers
  " and the . operator, and rightwards across the identifier only.
  "
  " For example:
  " import xml.dom.minidom
  " ^ !
  "
  " With the cursor at ^ this returns 'xml'; at ! it returns 'xml.dom'.
  "
  " Source: https://github.com/fs111/pydoc.vim/blob/master/ftplugin/python_pydoc.vim
  let l:line = getline(".")
  let l:pre = l:line[:col(".") - 1]
  let l:suf = l:line[col("."):]
  return matchstr(pre, "[A-Za-z0-9_.]*$") . matchstr(suf, "^[A-Za-z0-9_]*")
endfunction

function! ref#pydoc#define()
  return copy(s:source)
endfunction

call ref#register_detection('python', 'pydoc')

let &cpo = s:save_cpo
unlet s:save_cpo
