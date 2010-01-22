if exists('g:loaded_autoload_fuf_ref_perldoc') || v:version < 702
  finish
endif
let g:loaded_autoload_fuf_ref_perldoc = 1

let s:FILE_NAME = expand('<sfile>:t:r')
let s:MODE_NAME = expand('<sfile>:h:t') . '#' . s:FILE_NAME

function fuf#ref#perldoc#createHandler(base)
  let a:base['menu'] = s:FILE_NAME
  return fuf#ref#createHandler(a:base)
endfunction

function fuf#ref#perldoc#getSwitchOrder()
  return g:fuf_line_switchOrder
endfunction

"
function fuf#ref#perldoc#renewCache()
endfunction

"
function fuf#ref#perldoc#requiresOnCommandPre()
  return 0
endfunction

"
function fuf#ref#perldoc#onInit()
  call fuf#defineLaunchCommand('FufRefPerldoc', s:MODE_NAME, '""')
endfunction
