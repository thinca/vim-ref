" A ref source for php manual.
" Version: 0.2.0
" Author : thinca <thinca+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim

if !exists('g:ref_phpmanual_path')
  let g:ref_phpmanual_path = ''
endif

if !exists('g:ref_phpmanual_cmd')
  let g:ref_phpmanual_cmd = 
  \ executable('elinks') ? 'elinks -dump -no-numbering -no-references %s' :
  \ executable('w3m')    ? 'w3m -dump %s' :
  \ executable('links')  ? 'links -dump %s' :
  \ executable('lynx')   ? 'lynx -dump -nonumbers %s' :
  \ ''
endif



function! ref#phpmanual#available()  " {{{2
  return isdirectory(g:ref_phpmanual_path) &&
  \      len(g:ref_phpmanual_cmd)
endfunction



function! ref#phpmanual#get_body(query)  " {{{2
  let name = substitute(tolower(a:query), '_', '-', 'g')
  let pre = g:ref_phpmanual_path . '/'

  if name =~ '::'
    let file = pre . substitute(name, '::', '.', 'g') . '.html'
    if filereadable(file)
      return s:execute(file)
    endif
    let name = substitute(name, '::', '-', 'g')
  endif

  for section in ['function.', 'ref.', 'class.', '']
    let file = pre . section . name . '.html'
    if filereadable(file)
      return s:execute(file)
    endif
  endfor

  if name == ''
    return s:cache('function') + s:cache('ref') + s:cache('class')
  endif

  for pat in ['%s.*', '*.%s.*', 'function.*%s*.html']
    let file = glob(pre . printf(pat, name))
    if file != ''
      let files = split(file, "\n")
      if len(files) == 1
        return s:execute(files[0])
      endif
      return substitute(join(
      \      map(files, 'matchstr(v:val, ".*[/\\\\]\\zs\\S*\\ze\\.html$")'),
      \      "\n"), '-', '_', 'g')
    endif
  endfor

  throw 'no match: ' . a:query
endfunction



function! ref#phpmanual#opened(query)  " {{{2
  call s:syntax()
endfunction



function! ref#phpmanual#complete(query)  " {{{2
  let name = substitute(tolower(a:query), '::', '_', 'g')
  let pre = g:ref_phpmanual_path . '/'

  for kind in ['function', 'ref', 'class']
    let list = filter(copy(s:cache(kind)), 'v:val =~# name')
    if list != []
      return list
    endif
  endfor
  return []
endfunction



function! ref#phpmanual#get_keyword()  " {{{2
  let isk = &l:isk
  setlocal isk& isk+=- isk+=. isk+=:
  let kwd = expand('<cword>')
  let &l:isk = isk
  return kwd
endfunction



function! ref#phpmanual#leave()  " {{{2
  syntax clear
  unlet! b:current_syntax
endfunction



function! s:syntax()  " {{{2
  if exists('b:current_syntax') && b:current_syntax == 'ref-phpmanual'
    return
  endif

  syntax clear

  unlet! b:current_syntax
  syntax include @refPhpmanualPHP syntax/php.vim
  syntax match refPhpmanualFunc '\h\w*\ze()'

  syn region phpRegion matchgroup=Delimiter start="<?php" end="?>" contains=@phpClTop

  highlight default link refPhpmanualFunc phpFunctions

  let b:current_syntax = 'ref-phpmanual'
endfunction



function! s:execute(file)  "{{{2
  if type(g:ref_phpmanual_cmd) == type('')
    let cmd = split(g:ref_phpmanual_cmd, '\s\+')
  elseif type(g:ref_phpmanual_cmd) == type([])
    let cmd = copy(g:ref_phpmanual_cmd)
  else
    return ''
  endif

  let file = escape(a:file, '\')
  let res = ref#system(map(cmd, 'substitute(v:val, "%s", file, "g")'))
  if &termencoding != '' && &termencoding !=# &encoding
    let converted = iconv(res, &termencoding, &encoding)
    if converted != ''
      let res = converted
    endif
  endif
  return res
endfunction



function! s:gather_func(name)  "{{{2
  let list = glob(g:ref_phpmanual_path . '/' . a:name . '.*.html')
  let pat = a:name . '\.\zs.*\ze\.html$'
  return map(split(list, "\n"),
  \      'substitute(matchstr(v:val, pat), "-", "_", "g")')
endfunction



function! s:func(name)  "{{{2
  return function(matchstr(expand('<sfile>'), '<SNR>\d\+_\zefunc$') . a:name)
endfunction



function! s:cache(kind)
  return ref#cache('phpmanual', a:kind, s:func('gather_func'))
endfunction



call ref#detect#register('php', 'phpmanual')



let &cpo = s:save_cpo
unlet s:save_cpo
