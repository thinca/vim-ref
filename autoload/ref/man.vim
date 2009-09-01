" A ref source for manpage.
" Version: 0.1.0
" Author : thinca <http://d.hatena.ne.jp/thinca/>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim



if !exists('g:ref_man_cmd')
  let g:ref_man_cmd = 'man'
endif


if !exists('g:ref_man_use_escape_sequence')
  let g:ref_man_use_escape_sequence = 0
endif



if !exists('g:ref_man_highlight_limit')
  let g:ref_man_highlight_limit = 1000
endif



function! ref#man#available()  " {{{2
  return executable(matchstr(g:ref_man_cmd, '^\w*'))
endfunction



function! ref#man#get_body(query)  " {{{2
  return system(g:ref_man_cmd . ' ' . a:query)
endfunction



function! ref#man#opened(query)  " {{{2
  if g:ref_man_use_escape_sequence && line ('$') <= g:ref_man_highlight_limit
    call s:highlight_escape_sequence()
  else
    silent! execute "% substitute/\<ESC>\\[[0-9;]*m//ge"
    call histdel('/', -1)

    call s:syntax()
  endif
endfunction



function! ref#man#get_keyword()  " {{{2
  let isk = &l:iskeyword
  setlocal isk& isk+=. isk+=( isk+=)
  let word = expand('<cword>')
  setlocal isk& isk+=.
  let m = matchlist(word, '\(\k\+\)\%((\(\d\))\)\?')
  let keyword = m[1]
  if m[2] != ''
    let keyword = m[2] . ' ' . keyword
  endif
  let &l:iskeyword = isk
  return keyword
endfunction



let s:complcache = {}
function! ref#man#complete(query)  " {{{2
  let sec = matchstr(a:query, '^\d') - 0
  let query = matchstr(a:query, '\v^%(\d\s+)?\zs.*')

  if query == ''
    return []
  endif

  let head = query[0]
  if !has_key(s:complcache, head)
    let c = map(range(10), '[]')
    for path in split(system('manpath')[0 : -2], ':')
      for n in range(1, 9)
        let dir = path . '/man' . n
        if isdirectory(dir)
          let c[n] += map(split(glob(printf('%s*/%s*', dir, head)),
          \   "\n"), 'matchstr(v:val, ".*/\\zs[^/.]*\\ze\\.")')
        endif
      endfor
    endfor

    for n in range(1, 9)
      let c[n] = s:uniq(c[n])
      let c[0] += c[n]
    endfor
    let c[0] = s:uniq(c[0])

    let s:complcache[head] = c
  endif

  return filter(copy(s:complcache[head][sec]), 'v:val =~# "^\\V" . query')
endfunction



function! ref#man#leave()  " {{{2
  syntax clear
  unlet! b:current_syntax
endfunction



function! s:uniq(list)  " {{{2
  let d = {}
  for i in a:list
    let d[i] = 0
  endfor
  return sort(keys(d))
endfunction



function! s:syntax()  " {{{2
  if exists('b:current_syntax') && b:current_syntax == 'man'
    return
  endif

  syntax clear

  unlet! b:current_syntax

  runtime! syntax/man.vim
endfunction



" Got this function from vimshell. Thanks Shougo!
" Original function: interactive#highlight_escape_sequence()
function! s:highlight_escape_sequence()  " {{{2
  syntax clear
  1
  let [reg_save, reg_save_type] = [getreg(), getregtype()]

  let l:color_table = [ 0x00, 0x5F, 0x87, 0xAF, 0xD7, 0xFF ]
  let l:grey_table = [
  \0x08, 0x12, 0x1C, 0x26, 0x30, 0x3A, 0x44, 0x4E, 
  \0x58, 0x62, 0x6C, 0x76, 0x80, 0x8A, 0x94, 0x9E, 
  \0xA8, 0xB2, 0xBC, 0xC6, 0xD0, 0xDA, 0xE4, 0xEE
  \]

  while search("\<ESC>\\[[0-9;]*m", 'c')
    normal! dfm

    let [lnum, col] = getpos('.')[1:2]
    if len(getline('.')) == col
      let col += 1
    endif
    let syntax_name = 'EscapeSequenceAt_' . bufnr('%') . '_' . lnum . '_' . col
    execute 'syntax region' syntax_name 'start=+\%' . lnum . 'l\%' . col . 'c+ end=+\%$+' 'contains=ALL'

    let highlight = ''
    for color_code in split(matchstr(@", '[0-9;]\+'), ';')
      if color_code == 0"{{{
        let highlight .= ' cterm=NONE ctermfg=NONE ctermbg=NONE gui=NONE guifg=NONE guibg=NONE'
      elseif color_code == 1
        let highlight .= ' cterm=BOLD gui=BOLD'
      elseif color_code == 4
        let highlight .= ' cterm=UNDERLINE gui=UNDERLINE'
      elseif color_code == 7
        let highlight .= ' cterm=REVERSE gui=REVERSE'
      elseif color_code == 8
        let highlight .= ' ctermfg=0 ctermbg=0 guifg=#000000 guibg=#000000'
      elseif 30 <= color_code && color_code <= 37 
        " Foreground color.
        let highlight .= printf(' ctermfg=%d guifg=%s', color_code - 30, g:Interactive_EscapeColors[color_code - 30])
      elseif color_code == 38
        " Foreground 256 colors.
        let l:color = split(matchstr(@", '[0-9;]\+'), ';')[2]
        if l:color >= 232
          " Grey scale.
          let l:gcolor = l:grey_table[(l:color - 232)]
          let highlight .= printf(' ctermfg=%d guifg=#%02x%02x%02x', l:color, l:gcolor, l:gcolor, l:gcolor)
        elseif l:color >= 16
          " RGB.
          let l:gcolor = l:color - 16
          let l:red = l:color_table[l:gcolor / 36]
          let l:green = l:color_table[(l:gcolor % 36) / 6]
          let l:blue = l:color_table[l:gcolor % 6]

          let highlight .= printf(' ctermfg=%d guifg=#%02x%02x%02x', l:color, l:red, l:green, l:blue)
        else
          let highlight .= printf(' ctermfg=%d guifg=%s', l:color, g:Interactive_EscapeColors[l:color])
        endif
        break
      elseif color_code == 39
        " TODO
      elseif 40 <= color_code && color_code <= 47 
        " Background color.
        let highlight .= printf(' ctermbg=%d guibg=%s', color_code - 40, g:Interactive_EscapeColors[color_code - 40])
      elseif color_code == 48
        " Background 256 colors.
        let l:color = split(matchstr(@", '[0-9;]\+'), ';')[2]
        if l:color >= 232
          " Grey scale.
          let l:gcolor = l:grey_table[(l:color - 232)]
          let highlight .= printf(' ctermbg=%d guibg=#%02x%02x%02x', l:color, l:gcolor, l:gcolor, l:gcolor)
        elseif l:color >= 16
          " RGB.
          let l:gcolor = l:color - 16
          let l:red = l:color_table[l:gcolor / 36]
          let l:green = l:color_table[(l:gcolor % 36) / 6]
          let l:blue = l:color_table[l:gcolor % 6]

          let highlight .= printf(' ctermbg=%d guibg=#%02x%02x%02x', l:color, l:red, l:green, l:blue)
        else
          let highlight .= printf(' ctermbg=%d guibg=%s', l:color, g:Interactive_EscapeColors[l:color])
        endif
        break
      elseif color_code == 49
        " TODO
      endif"}}}
    endfor
    if len(highlight)
      execute 'highlight' syntax_name highlight
    endif
  endwhile
  call setreg(v:register, reg_save, reg_save_type)
endfunction



let &cpo = s:save_cpo
unlet s:save_cpo
