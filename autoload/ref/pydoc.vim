" A ref source for pydoc.
" Version: 0.1.1
" Author : thinca <thinca+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim



if !exists('g:ref_pydoc_cmd')
  let g:ref_pydoc_cmd = executable('pydoc') ? 'pydoc' : ''
endif



function! ref#pydoc#available()  " {{{2
  return g:ref_pydoc_cmd != ''
endfunction



function! ref#pydoc#get_body(query)  " {{{2
  let matchedlist = 0
  if a:query == ''
    let matchedlist = 1
  else
    let args = join(map(split(a:query), 'shellescape(v:val)'), ' ')
    let content = system(g:ref_pydoc_cmd . ' ' . args)
    if content =~ 'no Python documentation found'
      let matchedlist = 1
    endif
  endif

  if matchedlist
    let list = ref#pydoc#complete(a:query)
    if list == []
      throw split(content, "\n")[0]
    endif
    if len(list) == 1
      return system(g:ref_pydoc_cmd . ' ' . shellescape(list[0]))
    endif
    return list
  endif

  return content
endfunction



function! ref#pydoc#opened(query)  " {{{2
  call s:syntax(s:get_info()[0])
endfunction



function! ref#pydoc#complete(query)  " {{{2
  let cmd = g:ref_pydoc_cmd . ' -k .'
  let mapexpr = 'matchstr(v:val, "^[[:alnum:]._]*")'
  let all_list = ref#cache('pydoc', 'list',
  \                    printf('map(split(system(%s), "\n"), %s)',
  \                           string(cmd), string(mapexpr)))
  let list = filter(copy(all_list), 'v:val =~ "^\\V" . a:query')
  if !empty(list)
    return list
  endif
  return filter(copy(all_list), 'v:val =~ "\\V" . a:query')
endfunction



function! ref#pydoc#get_keyword()  " {{{2
  if &l:filetype == 'ref'
    let [type, name, scope] = s:get_info()

    if type == 'package' || type == 'module'
      let line = getline('.')

      let secline = search('^\u[A-Z ]*\u$', 'bnW')
      let section = secline == 0 ? '' : getline(secline)

      if section == 'PACKAGE CONTENTS'
        let package = matchstr(line, '^\s*\zs\S\+')
        if package != ''
          return name . '.' . package
        endif
      endif

      if section == 'CLASSES'
        let class = matchstr(line, '^\s*\zs\S\+$')
        if class != ''
          if type == 'package'
            return class
          endif
          return printf('%s.%s', name, class)
        endif

        let class = matchstr(line, '^\s*class \zs\k\+')
        if class != ''
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

    elseif type == 'class'
      let m = matchstr(getline('.'), '^ |  \zs\k\+\ze(.*)$')
      if m != ''
        return printf('%s.%s.%s', scope, name, m)
      endif

    endif

    if type != 'list'
      " xxx.yy*y.zzzClass -> xxx.yyy (* means cursor)
      let line = getline('.')
      let [pre, post] = [line[: col('.') - 2], line[col('.') - 1 :]]
      let kwd = matchstr(pre, '\v%(\k|\.)*$') . matchstr(post, '^\k*')
      if kwd != ''
        return kwd
      endif
    endif
  else
    " TODO: In a Python code.
  endif

  let isk = &l:isk
  setlocal isk& isk+=.
  let kwd = expand('<cword>')
  let &l:isk = isk
  return kwd
endfunction



function! ref#pydoc#leave()
  syntax clear
  unlet! b:current_syntax
endfunction



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
function! s:get_info()  " {{{2
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
  if exists('b:current_syntax') && b:current_syntax == 'ref-pydoc'
    " return
  endif

  syntax clear
  unlet! b:current_syntax

  if a:type == 'list'
    return
  endif

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



call ref#detect#register('python', 'pydoc')



let &cpo = s:save_cpo
unlet s:save_cpo
