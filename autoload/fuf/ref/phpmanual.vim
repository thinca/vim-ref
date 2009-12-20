if exists('g:loaded_autoload_fuf_ref_phpmanual') || v:version < 702
  finish
endif
let g:loaded_autoload_fuf_ref_phpmanual = 1

let s:FILE_NAME = expand('<sfile>:t:r')
let s:MODE_NAME = expand('<sfile>:h:t') . '#' . s:FILE_NAME

function fuf#ref#phpmanual#createHandler(base)
  let a:base['menu'] = s:FILE_NAME
  return fuf#ref#createHandler(a:base)
endfunction

function fuf#ref#phpmanual#getSwitchOrder()
  return g:fuf_line_switchOrder
endfunction

"
function fuf#ref#phpmanual#renewCache()
  call fuf#ref#deleteCache(s:FILE_NAME)
endfunction

"
function fuf#ref#phpmanual#requiresOnCommandPre()
  return 0
endfunction

"
function fuf#ref#phpmanual#onInit()
  call fuf#defineLaunchCommand('FufRefPhpmanual', s:MODE_NAME, '""')
endfunction
