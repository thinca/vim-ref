" A ref source for ReFe.
" Version: 0.3.1
" Author : thinca <thinca+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim



" options. {{{1
if !exists('g:ref_refe_cmd')  " {{{2
  let g:ref_refe_cmd = executable('refe') ? 'refe' : ''
endif
let s:cmd = g:ref_refe_cmd

if !exists('g:ref_refe_encoding')  " {{{2
  let g:ref_refe_encoding = &termencoding
endif

if !exists('g:ref_refe_rsense_cmd')  " {{{2
  let g:ref_refe_rsense_cmd = ''
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
  if s:refe_version() == 2
    " is class or module?
    let class = matchstr(content, '^\v%(require\s+\S+\n\n)?%(class|module) \zs\S+')
    if class != ''
      for [type, sep] in [['Singleton', '.'], ['Instance', '#']]
        let members = s:refe(class . sep).stdout
        let members = substitute(members, '\V' . class . sep, '', 'g')
        let content .= "\n\n---- " . type . " methods ----\n" . members
      endfor
    endif
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



function! s:source.opened(query)  " {{{2
  let [type, _] = s:detect_type()
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
  let id = '\v\w+[!?]?'
  let pos = getpos('.')[1:]

  if &l:filetype ==# 'ref'
    let [type, name] = s:detect_type()

    if type ==# 'list'
      return getline(pos[0])
    endif

    if type ==# 'class'
      if getline('.') =~ '^----'
        return ''
      endif
      let section = search('^---- \w* methods', 'bnW')
      if section != 0
        let sep = matchstr(getline(section), '^---- \zs\w*\ze methods')
        let sep = {'Singleton' : '.', 'Instance' : '#'}[sep]
        return name . sep . expand('<cWORD>')
      endif
    endif

    if s:refe_version() == 2
      let kwd = s:get_word_on_cursor('\[\[\zs.\{-}\ze\]\]')

      if kwd != ''
        if kwd =~# '^man:'
          return ['man', matchstr(kwd, '^man:\zs.*$')]
        endif
        return matchstr(kwd, '^\%(\w:\)\?\zs.*$')
      endif
    endif

  else
    " Literals
    let syn = synIDattr(synID(line('.'), col('.'), 1), 'name')
    if syn ==# 'rubyStringEscape'
      let syn = synIDattr(synstack(line('.'), col('.'))[0], 'name')
    endif
    for s in ['String', 'Regexp', 'Symbol', 'Integer', 'Float']
      if syn =~# '^ruby' . s
        return s
      endif
    endfor

    " RSense
    if !empty(g:ref_refe_rsense_cmd)
      let use_temp = &l:modified || !filereadable(expand('%'))
      if use_temp
        let file = tempname()
        call writefile(getline(1, '$'), file)
      else
        let file = expand('%:p')
      endif

      let pos = getpos('.')
      let ve = &virtualedit
      set virtualedit+=onemore
      try
        let is_call = 0
        if search('\.\_s*\w*\%#[[:alnum:]_!?]', 'cbW')  " Is method call?
          let is_call = 1
        else
          call search('\>', 'cW')  " Move to the end of keyword.
        endif

        " To use the column of character base.
        let col = len(substitute(getline('.')[: col('.') - 2], '.', '.', 'g'))
        let res = ref#system(s:to_a(g:ref_refe_rsense_cmd) +
        \ ['type-inference', '--file=' . file,
        \ printf('--location=%s:%s', line('.'), col)])
        let type = matchstr(res.stdout, '^type: \zs\S\+\ze\n')
        let is_class = type =~ '^<.\+>$'
        if is_class
          let type = matchstr(type, '^<\zs.\+\ze>$')
        endif

        if type != ''
          if is_call
            call setpos('.', pos)
            let type .= (is_class ? '.' : '#') . s:get_word_on_cursor(id)
          endif

          return type
        endif

      finally
        if use_temp
          call delete(file)
        endif
        let &virtualedit = ve
        call setpos('.', pos)
      endtry
    endif
  endif

  let class = '\v\u\w*%(::\u\w*)*'
  let kwd = s:get_word_on_cursor(class)
  if kwd != ''
    return kwd
  endif
  return s:get_word_on_cursor(class . '%([#.]' . id . ')?|' . id)
endfunction



function! s:source.leave()  " {{{2
  syntax clear
endfunction



" functions. {{{1
" Detect the reference type from content.
" - ['list', ''] (Matched list)
" - ['class', class_name] (Summary of class)
" - ['method', class_and_method_name] (Detail of method)
function! s:detect_type()  " {{{2
  let [l1, l2, l3] = [getline(1), getline(2), getline(3)]
  if s:refe_version() == 1
    let m = matchstr(l1, '^==== \zs\S\+\ze ====$')
    if m != ''
      return ['class', m]
    endif

    " include man.*
    if l2 =~ '^\%(---\|:\|=\)'
      return ['method', l1]
    endif

  else
    let require = l1 =~# '^require'
    let m = matchstr(require ? l3 : l1, '^\%(class\|module\|object\) \zs\S\+')
    if m != ''
      return ['class', m]
    endif

    " include builtin variable.
    let m = matchstr(require ? l3 : l2, '^--- \zs\S\+')
    if m != ''
      return ['method', m]
    endif
  endif
  return ['list', '']
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
    syntax region refRefeMethods start="^---- \w* methods .*----$" end="^$" fold contains=refRefeMethod,refRefeMethodHeader
    syntax match refRefeMethod '\S\+' contained
    syntax region refRefeMethodHeader matchgroup=refRefeLine start="^----" end="----$" keepend oneline contained
  endif

  syntax match refRefeClassAndMethod '\v%(\u\w*%(::|\.|#))+\h\w*[?!=~]?' contains=@refRefeClassSepMethod
  syntax cluster refRefeClassSepMethod contains=refRefeCommonClass,refRefeCommonMethod,refRefeCommonSep

  syntax match refRefeCommonSep '::\|#' contained nextgroup=refRefeCommonClass,refRefeCommonMethod
  syntax match refRefeCommonClass '\u\w*' contained nextgroup=refRefeCommonSep
  syntax match refRefeCommonMethod '[[:lower:]_]\w*[?!=~]\?' contained


  highlight default link refRefeMethodHeader rubyClass
  highlight default link refRefeMethod rubyFunction
  highlight default link refRefeLine rubyOperator

  highlight default link refRefeCommonSep rubyOperator
  highlight default link refRefeCommonClass rubyClass
  highlight default link refRefeCommonMethod rubyFunction


  call s:syntax_refe{s:refe_version()}(a:type)

  let b:current_syntax = 'ref-refe-' . a:type
endfunction

function! s:syntax_refe1(type)  " {{{2
  if a:type ==# 'list'
    syntax match refRefeClassOrMethod '^.*$' contains=@refRefeClassSepMethod
  elseif a:type ==# 'class'
    syntax region refRefeRubyCodeBlock start="^  " end="$" contains=@refRefeRuby
    syntax region refRefeClass matchgroup=refRefeLine start="^====" end="====$" keepend oneline
  elseif a:type ==# 'method'
    syntax region refRefeRubyCodeBlock start="^      " end="$" contains=@refRefeRuby
    syntax match refRefeClassOrMethod '\%1l.*$' contains=@refRefeClassSepMethod
    syntax region refRefeRubyCodeInline matchgroup=refRefeLine start="^---" end="$" contains=@refRefeRuby oneline
  endif

  highlight default link refRefeClass rubyClass
endfunction

function! s:syntax_refe2(type)  " {{{2
  " Copy from syntax/ruby.vim
  syn region rubyString start=+\%(\%(class\s*\|\%([]})"'.]\|::\)\)\_s*\|\w\)\@<!<<\z(\h\w*\)\ze+hs=s+2    matchgroup=rubyStringDelimiter end=+^ \{2}\z1$+ contains=rubyHeredocStart,@rubyStringSpecial fold keepend
  syn region rubyString start=+\%(\%(class\s*\|\%([]})"'.]\|::\)\)\_s*\|\w\)\@<!<<"\z([^"]*\)"\ze+hs=s+2  matchgroup=rubyStringDelimiter end=+^ \{2}\z1$+ contains=rubyHeredocStart,@rubyStringSpecial fold keepend
  syn region rubyString start=+\%(\%(class\s*\|\%([]})"'.]\|::\)\)\_s*\|\w\)\@<!<<'\z([^']*\)'\ze+hs=s+2  matchgroup=rubyStringDelimiter end=+^ \{2}\z1$+ contains=rubyHeredocStart		      fold keepend
  syn region rubyString start=+\%(\%(class\s*\|\%([]})"'.]\|::\)\)\_s*\|\w\)\@<!<<`\z([^`]*\)`\ze+hs=s+2  matchgroup=rubyStringDelimiter end=+^ \{2}\z1$+ contains=rubyHeredocStart,@rubyStringSpecial fold keepend

  syntax region refRefeRubyCodeBlock
  \      start=/^ \{2,4}\ze\S/
  \      end=/\n\+\ze \{,1}\S/ contains=@refRefeRuby

  syntax keyword rubyClass class
  syntax keyword rubyInclude include
  syntax match refRefeTitle "^===.\+$"

  if a:type !=# 'list'
    syntax match refRefeAnnotation '^@\w\+'
  endif
  if a:type ==# 'method'
    syntax match refRefeMethod '^--- \w\+[!?]'
  endif

  highlight default link refRefeMethod Function
  highlight default link refRefeTitle Statement
  highlight default link refRefeAnnotation Special
endfunction



function! s:get_word_on_cursor(pat)  " {{{2
  let line = getline('.')
  let pos = col('.')
  let s = 0
  while s < pos
    let [s, e] = [match(line, a:pat, s), matchend(line, a:pat, s)]
    if s < 0
      break
    elseif s <= pos && pos <= e
      return line[s : e - 1]
    endif
    let s += 1
  endwhile
  return ''
endfunction



function! s:to_a(expr)  " {{{2
  return type(a:expr) == type('') ? split(a:expr, '\s\+') :
  \      type(a:expr) != type([]) ? [a:expr] : a:expr
endfunction



function! s:refe(args)  " {{{2
  return ref#system(s:to_a(g:ref_refe_cmd) + s:to_a(a:args))
endfunction



function! s:refe_version()  " {{{2
  if s:cmd !=# g:ref_refe_cmd
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
