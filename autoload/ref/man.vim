" A ref source for manpage.
" Version: 0.0.1
" Author : thinca <http://d.hatena.ne.jp/thinca/>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim



if !exists('g:ref_man_cmd')
  let g:ref_man_cmd = 'man'
endif


function! ref#man#available()  " {{{2
  return executable(matchstr(g:ref_man_cmd, '^\w*'))
endfunction



function! ref#man#get_body(query)  " {{{2
  return system(g:ref_man_cmd . ' ' . a:query)
endfunction



function! ref#man#opened(query)  " {{{2
  call s:highlight_escape_sequence()
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
      let c[0] += c[n]
    endfor

    let s:complcache[head] = c
  endif

  return filter(copy(s:complcache[head][sec]), 'v:val =~# "^\\V" . query')
endfunction



function! s:highlight_escape_sequence()  " {{{2
  syntax clear
  1
  let [reg_save, reg_save_type] = [getreg(), getregtype()]
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
      if color_code == 0  "{{{
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
          let l:gcolor = (l:color - 232) * 11
          if l:gcolor != 0
            let l:gcolor += 2
          endif
          let highlight .= printf(' ctermfg=%d guifg=#%02x%02x%02x', l:color, l:gcolor, l:gcolor, l:gcolor)
        elseif l:color >= 16
          let l:gcolor = l:color - 16
          let l:red = l:gcolor / 36 * 40
          let l:green = (l:gcolor - l:gcolor/36 * 36) / 6 * 40
          let l:blue = l:gcolor % 6 * 40

          if l:red != 0
            let l:red += 15
          endif
          if l:blue != 0
            let l:blue += 15
          endif
          if l:green != 0
            let l:green += 15
          endif
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
          let l:gcolor = (l:color - 232) * 11
          if l:gcolor != 0
            let l:gcolor += 2
          endif
          let highlight .= printf(' ctermbg=%d guibg=#%02x%02x%02x', l:color, l:gcolor, l:gcolor, l:gcolor)
        elseif l:color >= 16
          let l:gcolor = l:color - 16
          let l:red = l:gcolor / 36 * 40
          let l:green = (l:gcolor - l:gcolor/36 * 36) / 6 * 40
          let l:blue = l:gcolor % 6 * 40

          if l:red != 0
            let l:red += 15
          endif
          if l:blue != 0
            let l:blue += 15
          endif
          if l:green != 0
            let l:green += 15
          endif
          let highlight .= printf(' ctermbg=%d guibg=#%02x%02x%02x', l:color, l:red, l:green, l:blue)
        else
          let highlight .= printf(' ctermbg=%d guibg=%s', l:color, g:Interactive_EscapeColors[l:color])
        endif
        break
      elseif color_code == 49
        " TODO
      endif  "}}}
    endfor
    if len(highlight)
      execute 'highlight' syntax_name highlight
    endif
  endwhile
  call setreg(v:register,reg_save, reg_save_type)
endfunction



let &cpo = s:save_cpo
unlet s:save_cpo
