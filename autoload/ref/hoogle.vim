" A ref source for Hoogle.
" Version: 0.0.1
" Author : ujihisa <ujihisa at gmail dot com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim



" options. {{{1
if !exists('g:ref_hoogle_cmd')  " {{{2
  let g:ref_hoogle_cmd = executable('hoogle') ? 'hoogle' : ''
endif
let s:cmd = g:ref_hoogle_cmd

let s:source = {'name': 'hoogle'}  " {{{1

function! s:source.available()  " {{{2
  return !empty(g:ref_hoogle_cmd)
endfunction



function! s:source.get_body(query)  " {{{2
  let query = substitute(a:query, " ::.*", "", "")
  let query = substitute(query, '^\(\u\)', '+\1', "")
  let res = s:hoogle(query)
  if res.stderr != ''
    throw matchstr(res.stderr, '^.\{-}\ze\n')
  endif

  let content = split(res.stdout, "\n")
  return len(content) > 0 && a:query == content[0] ?
        \ {'query': a:query, 'body': s:hoogle('--info '. query).stdout} :
        \ content
endfunction



function! s:source.get_keyword()  " {{{2
  let id = '\v\w+[!?]?'
  let pos = getpos('.')[1:]

  if &l:filetype ==# 'ref-hoogle'
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

    if s:hoogle_version() == 2
      let kwd = ref#get_text_on_cursor('\[\[\zs.\{-}\ze\]\]')

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
    if !empty(g:ref_haskell_rsense_cmd)
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
        let res = ref#system(ref#to_list(g:ref_haskell_rsense_cmd) +
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
            let type .= (is_class ? '.' : '#') . ref#get_text_on_cursor(id)
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
  let kwd = ref#get_text_on_cursor(class)
  if kwd != ''
    return kwd
  endif
  return ref#get_text_on_cursor(class . '%([#.]' . id . ')?|' . id)
endfunction


" functions. {{{1
" Detect the haskellrence type from content.
" - ['list', ''] (Matched list)
" - ['class', class_name] (Summary of class)
" - ['method', class_and_method_name] (Detail of method)
function! s:detect_type()  " {{{2
  let [l1, l2, l3] = [getline(1), getline(2), getline(3)]
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
  return ['list', '']
endfunction



function! s:syntax(type)  " {{{2
endfunction



function! s:hoogle(args)  " {{{2
  return ref#system(ref#to_list(g:ref_hoogle_cmd) + ref#to_list(a:args))
endfunction






function! ref#hoogle#define()  " {{{2
  return copy(s:source)
endfunction

call ref#register_detection('haskell', 'hoogle')  " {{{1



let &cpo = s:save_cpo
unlet s:save_cpo