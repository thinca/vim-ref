" A ref source for redis.
" Version: 0.0.1
" Author : walf443 <walf443@gmail.com>
"                : thinca <thinca+vim@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

" this code is based from autoload/ref/rfc.vim
let s:save_cpo = &cpo
set cpo&vim

" options. {{{1
if !exists('g:ref_redis_start_linenumber')  " {{{2
  let g:ref_redis_start_linenumber = 5
endif

if !exists('g:ref_redis_cmd')  " {{{2
  let g:ref_redis_cmd =
  \ executable('elinks') ? 'elinks -dump -no-numbering -no-references %s' :
  \ executable('w3m')    ? 'w3m -dump %s' :
  \ executable('links')  ? 'links -dump %s' :
  \ executable('lynx')   ? 'lynx -dump -nonumbers %s' :
  \ len(globpath(&rtp, 'autoload/wwwrenderer.vim')) > 0
  \   ? '=wwwrenderer#render("%s")' :
  \ ''
endif

if !exists('g:ref_redis_encoding')  " {{{2
  let g:ref_redis_encoding = &termencoding
endif

if !exists('g:ref_redis_use_cache')  " {{{2
  let g:ref_redis_use_cache = 0
endif

let s:source = {'name': 'redis'}  " {{{1

function! s:source.available()
  return !empty(g:ref_redis_cmd)
endfunction

function! s:source.get_keyword()
  let isk = &l:iskeyword
  setlocal isk& isk+=-
  let kwd = expand('<cword>')
  let &l:iskeyword = isk
  return kwd
endfunction

function! s:source.complete(query)
  let q = a:query == '' || a:query =~ '\s$' ? '' : split(a:query)[-1]

  let list = s:list()
  let q = toupper(q)
  return s:head(list, q)
endfunction

function! s:source.get_body(query)
  if type(g:ref_redis_cmd) == type('')
    let cmd = split(g:ref_redis_cmd, '\s\+')
  elseif type(g:ref_redis_cmd) == type([])
    let cmd = copy(g:ref_redis_cmd)
  else
    return ''
  endif

  let str = toupper(a:query)
  let cand = s:list()
  let hit = 0 <= index(cand, str)
  if !hit
    let list = s:match(cand, str)
    if !empty(list)
      return list
    endif
    throw printf('No documentation found for "%s".', str)
  endif

  let url = 'http://redis.io/commands/' . str
  call map(cmd, 'substitute(v:val, "%s", url, "g")')
  if len(cmd) > 0 && cmd[0] =~ '^='
    let res = eval(join(cmd, ' ')[1:])
  elseif len(cmd) > 0 && cmd[0] =~ '^:'
    redir => res
    silent! exe join(cmd, ' ')[1:]
    redir END
  elseif g:ref_redis_use_cache
    let expr = 'ref#system(' . string(cmd) . ').stdout'
    let res = join(ref#cache('redis', str, expr), "\n")
  else
    let res = ref#system(cmd).stdout
  endif
  " let res = substitute(res, 'Related commands\r\n\r\n.*\r\n\r\n\r\n', '\r\n', '')

  " delete related commands
  let res = substitute(res, 'Related commands\n\n.*\n\n\s*Available', '   Available', '')
  return s:iconv(res, g:ref_redis_encoding, &encoding)
endfunction

function! s:source.opened(query)
  let cand = s:list()
  let hit = 0 <= index(cand, a:query)
  if hit
      execute "normal! ".g:ref_redis_start_linenumber."z\<CR>"
      call s:syntax(a:query)
  endif
endfunction

function! s:source.normalize(query)
  return substitute(substitute(a:query, '\_s\+', ' ', 'g'), '^ \| $', '', 'g')
endfunction


" misc. {{{1
function! s:syntax(query)
  if ( exists('b:current_syntax') && ( b:current_syntax ==# 'ref-redis' ) )
      return
  endif

  syntax clear
  unlet! b:current_syntax
  let commands = map(copy(s:list()), 'substitute(v:val, "-", " ", "")')
  syntax case match
  for keyword in commands
    execute 'syntax match refRedisCommand "\<'.keyword.'\>"'
  endfor
  highlight default link refRedisCommand Special

  let b:current_syntax = 'ref-redis'
endfunction

" iconv() wrapper for safety.
function! s:iconv(expr, from, to)
  if a:from == '' || a:to == '' || a:from ==# a:to
    return a:expr
  endif
  let result = iconv(a:expr, a:from, a:to)
  return result != '' ? result : a:expr
endfunction

function! s:list()
    return ref#cache('redis', 'command_list', s:func('redis_command_list'))
endfunction

function! s:head(list, query)
  let pat = '^\V' . a:query . '\S\*\v\zs.*$'
  return ref#uniq(map(filter(copy(a:list), 'v:val =~# pat'),
  \                   'substitute(v:val, pat, "", "")'))
endfunction

function! s:match(list, str)
  let matched = filter(copy(a:list), 'v:val =~? "^\\V" . a:str')
  if empty(matched)
    let matched = filter(copy(a:list), 'v:val =~? "\\V" . a:str')
  endif
  return matched
endfunction

function! s:func(name)
  return function(matchstr(expand('<sfile>'), '<SNR>\d\+_\zefunc$') . a:name)
endfunction

function! s:redis_command_list(dummy)
  let commands = []
  if type(g:ref_redis_cmd) == type('')
    let cmd = split(g:ref_redis_cmd, '\s\+')
  elseif type(g:ref_redis_cmd) == type([])
    let cmd = copy(g:ref_redis_cmd)
  else
    return ''
  endif
  let url = 'http://redis.io/commands'
  call map(cmd, 'substitute(v:val, "%s", url, "g")')

  let res = ref#system(cmd).stdout
  for line in split(res, "\n")
    let matches = matchlist(line, '\(\u\+\s\%(\u\{2,}\s\)\?\)')
    if !empty(matches) && len(matches) > 1
        let result = toupper(substitute(
              \ substitute(matches[1], '\s$', '', ''), '\s', '-', ''))
        call add(commands, result)
    endif
  endfor

  return commands
endfunction

function! ref#redis#define()
  return s:source
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
