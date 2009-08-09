" A ref source for php manual.
" Version: 0.0.1
" Author : thinca <http://d.hatena.ne.jp/thinca/>
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
  \      executable(matchstr(g:ref_phpmanual_cmd, '^\w*'))
endfunction



function! ref#phpmanual#get_body(query)  " {{{2
  let name = substitute(a:query, '_', '-', 'g')

  for section in ['function.', 'ref.', 'class.', '']
    let file = g:ref_phpmanual_path . '/' . section . name . '.html'
    if filereadable(file)
      return system(printf(g:ref_phpmanual_cmd, file))
    endif
  endfor

  for pat in ['%s.*', '*.%s.*', 'function.*%s*.html']
    let file = glob(g:ref_phpmanual_path . '/' . printf(pat, name))
    if file != ''
      let files = split(file, "\n")
      if len(files) == 1
        return system(printf(g:ref_phpmanual_cmd, files[0]))
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
  let name = substitute(a:query, '_', '-', 'g')
  let pre = g:ref_phpmanual_path . '/'

  for [globpat, retpat] in [
  \   ['function.%s*', 'function\.\zs.*\ze\.html$'],
  \   ['ref.%s*', 'ref\.\zs.*\ze\.html$'],
  \   ['class.%s*', 'class\.\zs.*\ze\.html$']]
    let file = glob(pre . printf(globpat, name) . '.html')
    if file != ''
      return map(split(file, "\n"),
      \ 'substitute(matchstr(v:val, retpat), "-", "_", "g")')
    endif
  endfor
  return []
endfunction



function! ref#phpmanual#get_keyword()  " {{{2
  let isk = &l:isk
  setlocal isk& isk+=- isk+=.
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



call ref#detect#register('php', 'phpmanual')



let &cpo = s:save_cpo
unlet s:save_cpo
