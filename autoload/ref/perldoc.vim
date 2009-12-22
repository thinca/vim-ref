" A ref source for perldoc.
" Version: 0.1.1
" Author : thinca <thinca+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim



if !exists('g:ref_perldoc_cmd')
  let g:ref_perldoc_cmd = executable('perldoc') ? 'perldoc' : ''
endif



function! ref#perldoc#available()  " {{{2
  return g:ref_perldoc_cmd != ''
endfunction



function! ref#perldoc#get_body(query)  " {{{2
  let cmdarg = '-T'
  let q = matchstr(a:query, '\v%(^|\s)\zs[^-]\S*')
  let func = a:query =~# '-f\>'

  let cand = s:appropriate_list(a:query)
  if index(cand, q) < 0
    let list = s:match(cand, q)
    if empty(list)
      throw printf('No documentation found for "%s".', q)
    endif
    return list
  endif

  if func || index(s:list('modules') + s:list('basepod'), q) < 0
    let cmdarg = '-T -f'
  endif

  " Drop the stderr.
  let save_srr = &shellredir
  let &shellredir = '>%s'
  try
    let res = system(printf('%s -o text %s %s',
    \                    g:ref_perldoc_cmd ,cmdarg ,q))
  finally
    let &shellredir = save_srr
  endtry

  if res == ''
    throw printf('No documentation found for "%s".', q)
  endif
  return res
endfunction



function! ref#perldoc#opened(query)  " {{{2
  let b:ref_perldoc_word = matchstr(a:query, '-\@<![^-[:space:]]\+')
  let mode = getline(1) ==# 'NAME' ? (
  \            0 <= index(s:list('basepod'), b:ref_perldoc_word) ? 'perl'
  \                                                             : 'module'):
  \          !search('^\s', 'wn') ? 'list':
  \          !search('^\S', 'wn') ? 'func':
  \                               'source'

  let b:ref_perldoc_mode = mode
  call s:syntax(mode)
endfunction



function! ref#perldoc#complete(query)  " {{{2
  let q = a:query == '' || a:query =~ '\s$' ? '' : split(a:query)[-1]
  if q =~ '-'
    return ['-f', '-m']
  endif

  return s:match(s:appropriate_list(a:query), q)
endfunction



function! ref#perldoc#get_keyword()  " {{{2
  let isk = &l:iskeyword
  setlocal isk& isk+=:
  let kwd = expand('<cword>')
  let &l:iskeyword = isk
  return kwd
endfunction



function! ref#perldoc#leave()
  syntax clear
  unlet! b:current_syntax
  unlet! b:ref_perldoc_mode b:ref_perldoc_word
endfunction



function! s:syntax(mode)  " {{{2
  if exists('b:current_syntax')
  \  && ((a:mode ==# 'source' && b:current_syntax ==# 'perl') ||
  \      (a:mode ==# 'perl'   && b:current_syntax ==# 'ref-perldoc-perl') ||
  \      (a:mode ==# 'module' && b:current_syntax ==# 'ref-perldoc-module') ||
  \      (a:mode ==# 'func'   && b:current_syntax ==# 'ref-perldoc-func'))
    return
  endif

  syntax clear
  unlet! b:current_syntax

  if a:mode ==# 'list'
    return
  endif

  if a:mode ==# 'source'
    runtime! syntax/perl.vim
    return
  endif


  syntax include @refPerldocPerl syntax/perl.vim

  " Adjust the end of heredoc.
  syntax clear perlHereDoc
  " Copy from syntax/perl.vim
  syn region perlHereDoc	matchgroup=perlStringStartEnd start=+<<\z(\I\i*\)+      end=+\z1$+ contains=@perlInterpDQ
  syn region perlHereDoc	matchgroup=perlStringStartEnd start=+<<\s*"\z(.\{-}\)"+ end=+\z1$+ contains=@perlInterpDQ
  syn region perlHereDoc	matchgroup=perlStringStartEnd start=+<<\s*'\z(.\{-}\)'+ end=+\z1$+ contains=@perlInterpSQ
  syn region perlHereDoc	matchgroup=perlStringStartEnd start=+<<\s*""+           end=+$+    contains=@perlInterpDQ,perlNotEmptyLine
  syn region perlHereDoc	matchgroup=perlStringStartEnd start=+<<\s*''+           end=+$+    contains=@perlInterpSQ,perlNotEmptyLine

  if a:mode ==# 'func'
    call s:indent_region('refPerldocRegion', 16, 'contains=@refPerldocPerl')
    syntax match refPerldocTitle '^ \{4}\l\+'
  else
    syntax match refPerldocTitle '^\u.\+$'

    if a:mode ==# 'module'
      syntax region refPerldocSynopsis matchgroup=refPerldocTitle start=/^SYNOPSIS/ end=/\n\ze\S/ contains=@refPerldocPerl
    endif

    call s:indent_region('refPerldocRegion', 6, 'contains=@refPerldocPerl')

    syntax region refPerldocList start=/^ \{4}\ze\%(\*\|\d\+\.\)/ end=/\n\+\ze \{,3}\S/ contains=refPerldocRegionInList
    call s:indent_region('refPerldocRegionInList', 10, 'contains=@refPerldocPerl contained')

  endif


  syntax match refPerldocString /"\_.\{-}"/

  highlight default link refPerldocTitle Title
  highlight default link refPerldocString Constant

  let b:current_syntax = 'ref-perldoc-' . a:mode
endfunction



function! s:indent_region(name, indent, option)
  execute 'syntax region' a:name
  \       'start=/^ \{' . a:indent . '}\ze\S/'
  \       'end=/\n\+\ze \{,' . (a:indent - 1) . '}\S/' a:option
endfunction



function! s:appropriate_list(query)
  return a:query =~# '-f\>' ? s:list('func'):
  \      a:query =~# '-m\>' ? s:list('modules'):
  \                           s:list('all')
endfunction



function! s:match(list, str)
  let matched = filter(copy(a:list), 'v:val =~? "^\\V" . a:str')
  if empty(matched)
    let matched = filter(copy(a:list), 'v:val =~? "\\V" . a:str')
  endif
  return matched
endfunction



function! s:list(name)
  if a:name ==# 'all'
    return s:list('basepod') + s:list('modules') + s:list('func')
  endif
  return ref#cache('perldoc', a:name, s:func(a:name . '_list'))
endfunction



function! s:basepod_list()
  let basepods = []
  let base = system('perl -MConfig -e ' .
  \                 shellescape('print $Config{installprivlib}'))
  for dir in ['pod', 'pods']
    if filereadable(printf('%s/%s/perl.pod', base, dir))
      let base .= '/' . dir
      break
    endif
  endfor

  if isdirectory(base)
    let basepods = map(split(glob(base . '/*.pod'), "\n"),
    \                  'fnamemodify(v:val, ":t:r")')
  endif

  return basepods
endfunction



function! s:modules_list()
  let inc = system('perl -e ' . shellescape('print join('':'', @INC)'))
  let sep = '[/\\]'
  let files = {}
  let modules = []
  for i in split(inc, ':')
    let f = split(glob(i . '/**/*.pm', 0), "\n")
    call filter(f, '!has_key(files, v:val)')
    for file in f
      let files[file] = 1
    endfor
    let l = len(i) + 1
    let modules += map(f,
    \           'substitute(fnamemodify(v:val, ":r")[l :], sep, "::", "g")')
  endfor

  return modules
endfunction



function! s:func_list()
  let doc = system('perldoc -u perlfunc')
  let i = 0
  let funcs = []
  while 1
    let n = match(doc, 'item \l\+', i)
    if n < 0
      break
    endif
    call add(funcs, matchstr(doc, 'item \zs\l\+', i))
    let i = n + 1
  endwhile
  return s:uniq(funcs)
endfunction



function! s:uniq(list)  "{{{2
  let d = {}
  for i in a:list
    let d[i] = 0
  endfor
  return sort(keys(d))
endfunction



function s:func(name)  "{{{2
  return function(matchstr(expand('<sfile>'), '<SNR>\d\+_\zefunc$') . a:name)
endfunction



call ref#detect#register('perl', 'perldoc')




let &cpo = s:save_cpo
unlet s:save_cpo
