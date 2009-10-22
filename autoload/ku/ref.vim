" ku source: ref
" Version: 0.1.0
" Author : thinca <thinca+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim


function! ku#ref#available_sources()
  return map(filter(ref#list(), 'exists("*ref#{v:val}#complete")'),
  \          '"ref/" . v:val')
endfunction



function! ku#ref#action_table(ext)
  return {
  \    'default': 'ku#ref#open',
  \    'open': 'ku#ref#open',
  \  }
endfunction



function! ku#ref#key_table(ext)
  return {
  \   "\<C-o>": 'open',
  \   'o': 'open',
  \ }
endfunction



function! ku#ref#gather_items(ext, pattern)
  return map(ref#{a:ext}#complete(a:pattern),
  \          '{"word": v:val, "menu": a:ext}')
endfunction



function! ku#ref#acc_valid_p(ext, item, sep)
  if exists('*ref#{a:ext}#acc_valid_p')
    return ref#{a:ext}#acc_valid_p(a:item, a:sep)
  endif
  return 0
endfunction



function! ku#ref#special_char_p(ext, ch)
  if exists('*ref#{a:ext}#special_char_p')
    return ref#{a:ext}#special_char_p(a:ch)
  endif
  return 0
endfunction



function! ku#ref#on_before_action(ext, item)
  if exists('*ref#{a:ext}#on_before_action')
    return ref#{a:ext}#on_before_action(a:item)
  endif
  return a:item
endfunction



function! ku#ref#on_source_enter(ext)
  if exists('*ref#{a:ext}#on_source_enter')
    return ref#{a:ext}#on_source_enter()
  endif
  return 0
endfunction



function! ku#ref#on_source_leave(ext)
  if exists('*ref#{a:ext}#on_source_leave')
    return ref#{a:ext}#on_source_leave()
  endif
  return 0
endfunction



function! ku#ref#open(item)
  call ref#open(a:item.menu, a:item.word, '')
endfunction




let &cpo = s:save_cpo
unlet s:save_cpo
