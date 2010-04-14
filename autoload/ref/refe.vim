" A ref source for ReFe.
" Version: 0.2.0
" Author : thinca <thinca+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim



" options. {{{1
if !exists('g:ref_refe_cmd')  " {{{2
  let g:ref_refe_cmd = executable('refe') ? 'refe' : ''
endif

if !exists('g:ref_refe_encoding')  " {{{2
  let g:ref_refe_encoding = &termencoding
endif



let s:source = {'name': 'refe'}  " {{{1

function! s:source.available()  " {{{2
  return len(g:ref_refe_cmd)
endfunction



function! s:source.get_body(query)  " {{{2
  let res = s:refe(a:query)
  if res.stderr != ''
    throw matchstr(res.stderr, '^.\{-}\ze\n')
  endif

  let content = res.stdout
  if exists('g:ref_refe_encoding') &&
  \  !empty(g:ref_refe_encoding) && g:ref_refe_encoding != &encoding
    let converted = iconv(content, g:ref_refe_encoding, &encoding)
    if converted != ''
      let content = converted
    endif
  endif

  return content
endfunction



function! s:source.opened(query)  " {{{2
  let type = s:detect_type()

  let ver = s:refe_version()
  if type ==# 'list'
    silent! %s/ /\r/ge
    silent! global/^\s*$/delete _
  endif

  if type ==# 'class' && ver == 1
    silent! %s/[^[:return:]]\n\zs\ze----/\r/ge
  endif
  call s:syntax(type)
  1
endfunction



function! s:source.complete(query)  " {{{2
  let option = s:refe_version() == 2 ? ['-l'] : ['-l', '-s']
  return split(s:refe(option + s:to_a(a:query)).stdout, "\n")
endfunction



function! s:source.special_char_p(ch)  " {{{2
  return a:ch == '#'
endfunction



function! s:source.get_keyword()  " {{{2
  let pos = getpos('.')[1:]
  if &l:filetype ==# 'ref'
    let type = s:detect_type()
    if type ==# 'list'
      return getline(pos[0])
    endif
    if type ==# 'class'
      if getline('.') =~ '^----'
        return ''
      endif
      let class = matchstr(getline(1), '^==== \zs\S*\ze ====$')
      let section = search('^---- \w* methods', 'bnW')
      if section != 0
        let sep = matchstr(getline(section), '^---- \zs\w*\ze methods')
        let sep = {'Singleton' : '.', 'Instance' : '#'}[sep]
        return class . sep . expand('<cWORD>')
      endif
    endif
  else
     " TODO: In the Ruby code.
  endif
  let isk = &l:isk
  setlocal isk& isk+=: isk+=? isk+=!
  let kwd = expand('<cword>')
  let &l:isk = isk
  return kwd
endfunction



function! s:source.leave()  " {{{2
  syntax clear
endfunction



" functions. {{{1
" Detect the reference type from content.
" - list (Matched list)
" - class (Summary of class)
" - method (Detail of method)
function! s:detect_type()  " {{{2
  let l1 = getline(1)
  if s:refe_version() == 1
    if l1 =~ '^===='
      return 'class'
    endif
    let l2 = getline(2)
    if l2 =~ '^---' || l2 =~ '^:'
      return 'method'
    endif
  else
    if l1 =~# '^require'
      return getline(3) =~ '^---' ? 'method' : 'class'
    elseif l1 =~# '^\%(class\|module\)'
      return 'class'
    elseif getline(2) =~ '^---'
      return 'method'
    endif
  endif
  return 'list'
endfunction



function! s:syntax(type)  " {{{2
  if exists('b:current_syntax') && b:current_syntax == 'ref-refe-' . a:type
    return
  endif

  syntax clear

  syntax include @refRefeRuby syntax/ruby.vim

  call s:syntax_refe{s:refe_version()}(a:type)

  let b:current_syntax = 'ref-refe-' . a:type
endfunction

function! s:syntax_refe1(type)  " {{{2
  if a:type ==# 'list'
    syntax match refRefeClassOrMethod '^.*$' contains=@refRefeClassSepMethod
  elseif a:type ==# 'class'
    syntax region refRefeRubyCodeBlock start="^  " end="$" contains=@refRefeRuby
    syntax region refRefeClass matchgroup=refRefeLine start="^====" end="====$" keepend oneline
    syntax region refRefeMethods start="^---- \w* methods .*----$" end="^$" fold contains=refRefeMethod,refRefeMethodHeader
    syntax match refRefeMethod '\S\+' contained
    syntax region refRefeMethodHeader matchgroup=refRefeLine start="^----" end="----$" keepend oneline contained
  elseif a:type ==# 'method'
    syntax region refRefeRubyCodeBlock start="^      " end="$" contains=@refRefeRuby
    syntax match refRefeClassOrMethod '\%1l.*$' contains=@refRefeClassSepMethod
    syntax region refRefeRubyCodeInline matchgroup=refRefeLine start="^---" end="$" contains=@refRefeRuby oneline
  end

  syntax match refRefeClassAndMethod '\v%(\u\w*%(::|#))+\h\w*[?!=~]?' contains=@refRefeClassSepMethod
  syntax cluster refRefeClassSepMethod contains=refRefeCommonClass,refRefeCommonMethod,refRefeCommonSep

  syntax match refRefeCommonSep '::\|#' contained nextgroup=refRefeCommonClass,refRefeCommonMethod
  syntax match refRefeCommonClass '\u\w*' contained nextgroup=refRefeCommonSep
  syntax match refRefeCommonMethod '[[:lower:]_]\w*[?!=~]\?' contained

  highlight default link refRefeClass rubyClass
  highlight default link refRefeMethodHeader rubyClass
  highlight default link refRefeMethod rubyFunction
  highlight default link refRefeLine rubyOperator

  highlight default link refRefeCommonSep rubyOperator
  highlight default link refRefeCommonClass rubyClass
  highlight default link refRefeCommonMethod rubyFunction

endfunction

function! s:syntax_refe2(type)  " {{{2
  " Copy from syntax/ruby.vim
  syn region rubyString start=+\%(\%(class\s*\|\%([]})"'.]\|::\)\)\_s*\|\w\)\@<!<<\z(\h\w*\)\ze+hs=s+2    matchgroup=rubyStringDelimiter end=+^ \{2}\z1$+ contains=rubyHeredocStart,@rubyStringSpecial fold keepend
  syn region rubyString start=+\%(\%(class\s*\|\%([]})"'.]\|::\)\)\_s*\|\w\)\@<!<<"\z([^"]*\)"\ze+hs=s+2  matchgroup=rubyStringDelimiter end=+^ \{2}\z1$+ contains=rubyHeredocStart,@rubyStringSpecial fold keepend
  syn region rubyString start=+\%(\%(class\s*\|\%([]})"'.]\|::\)\)\_s*\|\w\)\@<!<<'\z([^']*\)'\ze+hs=s+2  matchgroup=rubyStringDelimiter end=+^ \{2}\z1$+ contains=rubyHeredocStart		      fold keepend
  syn region rubyString start=+\%(\%(class\s*\|\%([]})"'.]\|::\)\)\_s*\|\w\)\@<!<<`\z([^`]*\)`\ze+hs=s+2  matchgroup=rubyStringDelimiter end=+^ \{2}\z1$+ contains=rubyHeredocStart,@rubyStringSpecial fold keepend

  syntax region refRefeRubyCodeBlock
  \      start=/^ \{2}\ze\S/
  \      end=/\n\+\ze \{,1}\S/ contains=@refRefeRuby

  syntax keyword rubyClass class
  syntax keyword rubyInclude include
  syntax match refRefeTitle "^===.\+$"

  highlight default link refRefeTitle Statement
endfunction



function! s:to_a(expr)  " {{{2
  return type(a:expr) == type('') ? split(a:expr, '\s\+') :
  \      type(a:expr) != type([]) ? [a:expr] : a:expr
endfunction



function! s:refe(args)  " {{{2
  return ref#system(s:to_a(g:ref_refe_cmd) + s:to_a(a:args))
endfunction



function! s:refe_version()  " {{{2
  if !exists('s:cmd') || s:cmd !=# g:ref_refe_cmd
    let s:cmd = g:ref_refe_cmd
    unlet! g:ref_refe_version
  endif
  if !exists('g:ref_refe_version')
    let g:ref_refe_version =
    \   s:refe('--version').stdout =~# 'ReFe version 2' ? 2 : 1
  endif
  return g:ref_refe_version
endfunction



function! ref#refe#define()  " {{{2
  return s:source
endfunction

call ref#register_detection('ruby', 'refe')  " {{{1



let &cpo = s:save_cpo
unlet s:save_cpo
