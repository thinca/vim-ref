if exists('g:loaded_autoload_fuf_ref_refe') || v:version < 702
  finish
endif
let g:loaded_autoload_fuf_ref_refe = 1

let s:FILE_NAME = expand('<sfile>:t:r')
let s:MODE_NAME = expand('<sfile>:h:t') . '#' . s:FILE_NAME

function fuf#ref#refe#createHandler(base)
  let a:base['menu'] = s:FILE_NAME
  return fuf#ref#createHandler(a:base)
endfunction

function fuf#ref#refe#getSwitchOrder()
  return g:fuf_line_switchOrder
endfunction

"
function fuf#ref#refe#renewCache()
endfunction

"
function fuf#ref#refe#requiresOnCommandPre()
  return 0
endfunction

"
function fuf#ref#refe#onInit()
  call fuf#defineLaunchCommand('FufRefRefe', s:MODE_NAME, '""')
endfunction

