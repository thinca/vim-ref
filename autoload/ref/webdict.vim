" A ref source for web dictionary.
" Version: 1.0
" Author : thinca <thinca+vim@gmail.com>
" License: zlib License

let s:save_cpo = &cpo
set cpo&vim

" options. {{{1

if !exists('g:ref_source_webdict_cmd')
  let g:ref_source_webdict_cmd =
  \ executable('elinks') ? 'elinks -dump -no-numbering -no-references %s' :
  \ executable('w3m')    ? 'w3m -dump %s' :
  \ executable('links')  ? 'links -dump %s' :
  \ executable('lynx')   ? 'lynx -dump -nonumbers %s' :
  \ len(globpath(&rtp, 'autoload/wwwrenderer.vim')) > 0
  \   ? '=wwwrenderer#render("%s")' :
  \ ''
endif

if !exists('g:ref_source_webdict_sites')
  let g:ref_source_webdict_sites = {}
endif

if !exists('g:ref_source_webdict_encoding')
  let g:ref_source_webdict_encoding = &termencoding
endif

if !exists('g:ref_source_webdict_use_cache')
  let g:ref_source_webdict_use_cache = 0
endif

let s:site_base = {
\   'url': '',
\   'keyword_encoding': 'utf-8',
\ }
function! s:site_base.filter(output)
  return a:output
endfunction



let s:source = {'name': 'webdict'}  " {{{1

function! s:source.available()
  return !empty(g:ref_source_webdict_cmd)
endfunction

function! s:source.get_body(query)
  let cmd = s:get_cmd()
  if empty(cmd)
    throw 'Wrong g:ref_source_webdict_cmd.'
  endif

  let [name, site, keyword] = s:get_site_and_keyword_from_query(a:query)
  if empty(site)
    throw '"' . name . '" does not exist in g:ref_source_webdict_sites.'
  endif
  if empty(site.url)
    throw '"url" is empty: ' . name
  endif
  if stridx(site.url, '%s') < 0
    throw 'Wrong url: ' . site.url
  endif

  let query = name . ' ' . keyword
  let keyword = s:iconv(keyword, &encoding, site.keyword_encoding)
  let arg = ''
  for i in range(strlen(keyword))
    let c = keyword[i]
    let arg .= c =~ '\w' ? c : printf('%%%02X', char2nr(c))
  endfor

  let url = printf(site.url, arg)
  call map(cmd, 'substitute(v:val, "%s", url, "g")')
  if len(cmd) > 0 && cmd[0] =~ '^='
    let res = eval(join(cmd, ' ')[1:])
  elseif len(cmd) > 0 && cmd[0] =~ '^:'
    redir => res
    silent! exe join(cmd, ' ')[1:]
    redir END
  elseif get(site, 'cache', g:ref_source_webdict_use_cache)
    let expr = 'ref#system(' . string(cmd) . ').stdout'
    let res = join(ref#cache('webdict', query, expr), "\n")
  else
    let res = ref#system(cmd).stdout
  endif
  let encoding = get(site, 'output_encoding', g:ref_source_webdict_encoding)
  return {
  \   'body': site.filter(s:iconv(res, encoding, &encoding)),
  \   'query': query,
  \ }
endfunction

function! s:source.opened(query)
  let [name, site, keyword] = s:get_site_and_keyword_from_query(a:query)
  if has_key(site, 'line')
    execute site.line
    execute "normal! z\<CR>"
  endif
  call s:syntax(keyword)
  let b:ref_source_webdict_site = name
endfunction

function! s:source.get_keyword()
  let name = get(b:, 'ref_source_webdict_site',
  \                  get(g:ref_source_webdict_sites, 'default', ''))
  return name . ' ' . expand('<cword>')
endfunction

function! s:source.complete(query)
  if a:query =~# '^\s*\S*$'
    let name = '^\V' . escape(matchstr(a:query, '^\s*\zs\S*\ze$'), '\')
    return filter(keys(g:ref_source_webdict_sites),
    \             'v:val =~# name && v:val !=# "default"')
  endif
  return ''
endfunction

function! s:source.normalize(query)
  return substitute(substitute(a:query, '\_s\+', ' ', 'g'), '^ \| $', '', 'g')
endfunction


" misc. {{{1
function! s:syntax(query)
  syntax clear
  let str = escape(substitute(a:query, '\s\+', '\\_s\\+', 'g'), '"')
  if str =~# '^[[:print:][:space:]]\+$'
    let str = '\<' . str . '\>'
  endif
  execute 'syntax match refWebdictKeyword "\c'.str.'"'
  highlight default link refWebdictKeyword Special
endfunction

function! s:get_cmd()
  if type(g:ref_source_webdict_cmd) == type('')
    return split(g:ref_source_webdict_cmd, '\s\+')
  elseif type(g:ref_source_webdict_cmd) == type([])
    return copy(g:ref_source_webdict_cmd)
  endif
  return []
endfunction

function! s:get_site(name)
  let site = get(g:ref_source_webdict_sites, a:name, 0)
  if type(site) == type('')
    if a:name ==# 'default'
      return s:get_site(site)
    endif
    return extend(copy(s:site_base), {'url': site})
  elseif type(site) == type({})
    return extend(copy(s:site_base), site)
  endif
  return {}
endfunction

function! s:get_site_and_keyword_from_query(query)
  let [name, keyword] = matchlist(a:query, '^\(\S*\)\s*\(.*\)$')[1 : 2]
  let site = s:get_site(name)
  if !empty(site)
    return [name, site, keyword]
  endif
  let keyword = a:query
  if exists('b:ref_source_webdict_site')
    let name = b:ref_source_webdict_site
    let site = s:get_site(name)
    if !empty(site)
      return [name, site, keyword]
    endif
  endif
  let default = get(g:ref_source_webdict_sites, 'default', '')
  if default !=# ''
    let name = default
    let site = s:get_site(name)
  endif
  return [name, site, keyword]
endfunction

function! s:iconv(expr, from, to)
  if a:from == '' || a:to == '' || a:from ==# a:to
    return a:expr
  endif
  let result = iconv(a:expr, a:from, a:to)
  return result != '' ? result : a:expr
endfunction

function! ref#webdict#define()
  return s:source
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
