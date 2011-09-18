" ku source: ref
" Version: 0.2.1
" Author : thinca <thinca+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim

function! ku#ref#available_sources()
  return map(ref#available_source_names(), '"ref/" . v:val')
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
  return map(ref#available_sources(a:ext).complete(a:pattern),
  \          '{"word": v:val, "menu": a:ext}')
endfunction

function! ku#ref#acc_valid_p(ext, item, sep)
  let s = ref#available_sources(a:ext)
  return has_key(s, 'acc_valid_p') ? s.acc_valid_p(a:item, a:sep) : 0
endfunction

function! ku#ref#special_char_p(ext, ch)
  let s = ref#available_sources(a:ext)
  return has_key(s, 'special_char_p') ? s.special_char_p(a:ch) : 0
endfunction

function! ku#ref#on_before_action(ext, item)
  let s = ref#available_sources(a:ext)
  return has_key(s, 'on_before_action') ? s.on_before_action(a:item) : a:item
endfunction

function! ku#ref#on_source_enter(ext)
  let s = ref#available_sources(a:ext)
  return has_key(s, 'on_source_enter') ? s.on_source_enter() : 0
endfunction

function! ku#ref#on_source_leave(ext)
  let s = ref#available_sources(a:ext)
  return has_key(s, 'on_source_leave') ? s.on_source_leave() : 0
endfunction

function! ku#ref#open(item)
  call ref#open(a:item.menu, a:item.word, {'open': ''})
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
