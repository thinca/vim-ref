" A ref source for perldoc.
" Version: 0.3.4
" Author : thinca <thinca+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim

" config. {{{1
if !exists('g:ref_perldoc_cmd')  " {{{2
  let g:ref_perldoc_cmd = executable('perldoc') ? 'perldoc' : ''
endif

if !exists('g:ref_perldoc_complete_head')  " {{{2
  let g:ref_perldoc_complete_head = 0
endif


let s:source = {'name': 'perldoc'}  " {{{1

function! s:source.available()
  return len(g:ref_perldoc_cmd)
endfunction

function! s:source.get_body(query)
  let q = matchstr(a:query, '\v%(^|\s)\zs[^-]\S*')

  let cand = s:appropriate_list(a:query)
  let hit = 0 <= index(cand, q)
  if !hit
    let list = s:match(cand, q)
    if !empty(list)
      return list
    endif
  endif

  let cmdarg = ['-T', '-o', 'text']
  if a:query =~# '-f\>' ||
  \   (hit && index(s:list('modules') + s:list('basepod'), q) < 0)
    let cmdarg += ['-f']
  elseif a:query =~# '-m\>'
    let cmdarg += ['-m']
  endif

  let res = ref#system((type(g:ref_perldoc_cmd) == type('') ?
  \   split(g:ref_perldoc_cmd, '\s\+') : g:ref_perldoc_cmd) + cmdarg + [q])

  if res.stdout == ''
    throw printf('No documentation found for "%s".', q)
  endif
  return res.stdout
endfunction

function! s:source.opened(query)
  let b:ref_perldoc_word = matchstr(a:query, '-\@<![^-[:space:]]\+')
  let mode = getline(1) ==# 'NAME' ? (
  \            0 <= index(s:list('basepod'), b:ref_perldoc_word) ? 'perl'
  \                                                             : 'module'):
  \          !search('^\s', 'wn') ? 'list':
  \          !search('^\S', 'wn') ? 'func':
  \                               'source'

  let b:ref_perldoc_mode = mode

  nnoremap <silent> <buffer> <expr> <Plug>(ref-source-perldoc-switch)
  \ b:ref_perldoc_mode ==# 'module' ? ":\<C-u>Ref perldoc -m " .
  \                                b:ref_perldoc_word . "\<CR>" :
  \ b:ref_perldoc_mode ==# 'source' ? ":\<C-u>Ref perldoc " .
  \                                b:ref_perldoc_word . "\<CR>" :
  \ ''

  silent! nmap <buffer> <unique> s <Plug>(ref-source-perldoc-switch)

  call s:syntax(mode)
endfunction

function! s:source.complete(query)
  let q = a:query == '' || a:query =~ '\s$' ? '' : split(a:query)[-1]
  if q =~ '-'
    return ['-f', '-m']
  endif

  let list = s:appropriate_list(a:query)
  return g:ref_perldoc_complete_head ? s:head(list, q) : s:match(list, q)
endfunction

function! s:source.get_keyword()
  let isk = &l:iskeyword
  setlocal isk& isk+=:
  let kwd = expand('<cword>')
  let &l:iskeyword = isk
  return kwd
endfunction

function! s:source.leave()
  unlet! b:ref_perldoc_mode b:ref_perldoc_word
  silent! nunmap <buffer> <Plug>(ref-source-perldoc-switch)
  " FIXME: The following is not able to customize.
  silent! nunmap <buffer> s
endfunction


" functions. {{{1
function! s:syntax(mode)
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
  \                           s:list('modules') + s:list('basepod')
endfunction

function! s:match(list, str)
  let matched = filter(copy(a:list), 'v:val =~? "^\\V" . a:str')
  if empty(matched)
    let matched = filter(copy(a:list), 'v:val =~? "\\V" . a:str')
  endif
  return matched
endfunction

function! s:head(list, query)
  let pat = '^\V' . a:query . '\w\*\v(::)?\zs.*$'
  return ref#uniq(map(filter(copy(a:list), 'v:val =~# pat'),
  \                   'substitute(v:val, pat, "", "")'))
endfunction

function! s:list(name)
  return ref#cache('perldoc', a:name, s:func(a:name . '_list'))
endfunction

function! s:basepod_list(name)
  let basepods = []
  let base = ref#system(['perl', '-MConfig', '-e',
  \                      'print $Config{installprivlib}']).stdout
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

function! s:modules_list(name)
  let inc = ref#system(['perl', '-e', 'print join('';'', @INC)']).stdout
  let sep = '[/\\]'
  let files = {}
  let modules = []
  for i in split(inc, ';')
    let f = split(glob(i . '/**/*.pm', 0), "\n")
    \     + split(glob(i . '/**/*.pod', 0), "\n")
    call filter(f, '!has_key(files, v:val)')
    for file in f
      let files[file] = 1
    endfor
    let l = len(i) + 1
    let modules += map(f,
    \           'substitute(fnamemodify(v:val, ":r")[l :], sep, "::", "g")')
  endfor

  return ref#uniq(modules)
endfunction

function! s:func_list(name)
  let doc = ref#system('perldoc -u perlfunc').stdout
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
  return ref#uniq(funcs)
endfunction

function! s:func(name)
  return function(matchstr(expand('<sfile>'), '<SNR>\d\+_\zefunc$') . a:name)
endfunction

function! ref#perldoc#define()
  return s:source
endfunction

call ref#register_detection('perl', 'perldoc')

let &cpo = s:save_cpo
unlet s:save_cpo
