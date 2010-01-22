if exists('g:loaded_autoload_fuf_ref_man') || v:version < 702
  finish
endif
let g:loaded_autoload_fuf_ref_man = 1

let s:FILE_NAME = expand('<sfile>:t:r')
let s:MODE_NAME = expand('<sfile>:h:t') . '#' . s:FILE_NAME

function fuf#ref#man#createHandler(base)
  let a:base['menu'] = s:FILE_NAME
  return fuf#ref#createHandler(a:base)
endfunction

function fuf#ref#man#getSwitchOrder()
  return g:fuf_line_switchOrder
endfunction

"
function fuf#ref#man#renewCache()
endfunction

"
function fuf#ref#man#requiresOnCommandPre()
  return 0
endfunction

"
function fuf#ref#man#onInit()
  call fuf#defineLaunchCommand('FufRefMan', s:MODE_NAME, '""')
endfunction
