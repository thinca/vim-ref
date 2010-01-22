" A ref source for ReFe.
" Version: 0.1.0
" Author : thinca <thinca+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim



if !exists('g:ref_refe_cmd')
  let g:ref_refe_cmd = executable('refe') ? 'refe' : ''
endif

if !exists('g:ref_refe_encoding')
  let g:ref_refe_encoding = &termencoding
endif



function! ref#refe#available()  " {{{2
  return g:ref_refe_cmd != ''
endfunction



function! ref#refe#get_body(query)  " {{{2
  let content = ref#system(s:to_a(g:ref_refe_cmd) + s:to_a(a:query))
  let err = ref#last_stderr()
  if err =~# '\v' . join(['^not match: .', '^unmatched .',
    \ '^premature end of regular expression:',
    \ '^invalid regular expression;'], '|')
    throw matchstr(err, '^.\+\ze\n')
  endif

  if exists('g:ref_refe_encoding') &&
  \  !empty(g:ref_refe_encoding) && g:ref_refe_encoding != &encoding
    let converted = iconv(content, g:ref_refe_encoding, &encoding)
    if converted != ''
      let content = converted
    endif
  endif

  return content
endfunction



function! ref#refe#opened(query)  " {{{2
  let type = s:detect_type()
  if type ==# 'list'
    silent! %s/ /\r/ge
  elseif type ==# 'class'
    silent! %s/[^[:return:]]\n\zs\ze----/\r/ge
  endif
  call s:syntax(type)
endfunction



function! ref#refe#complete(query)  " {{{2
  return split(ref#system(s:to_a(g:ref_refe_cmd) +
  \            ['-l', '-s'] + s:to_a(a:query)), "\n")
endfunction



function! ref#refe#special_char_p(ch)
  return a:ch == '#'
endfunction



function! ref#refe#get_keyword()  " {{{2
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



function! ref#refe#leave()
  syntax clear
endfunction



" Detect the reference type from content.
" - list (Matched list)
" - class (Summary of class)
" - method (Detail of method)
function! s:detect_type()  " {{{2
  let l1 = getline(1)
  if l1 =~ '^===='
    return 'class'
  endif
  let l2 = getline(2)
  if l2 =~ '^---' || l2 =~ '^:'
    return 'method'
  endif
  return 'list'
endfunction



function! s:syntax(type)  " {{{2
  if exists('b:current_syntax') && b:current_syntax == 'ref-refe-' . a:type
    return
  endif

  syntax clear

  syntax include @refRefeRuby syntax/ruby.vim

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

  let b:current_syntax = 'ref-refe-' . a:type
endfunction



function! s:to_a(expr)
  return type(a:expr) == type('') ? split(a:expr, '\s\+') :
  \      type(a:expr) != type([]) ? [a:expr] : a:expr
endfunction



call ref#detect#register('ruby', 'refe')



let &cpo = s:save_cpo
unlet s:save_cpo
