if exists('g:loaded_autoload_fuf_ref_pydoc') || v:version < 702
  finish
endif
let g:loaded_autoload_fuf_ref_pydoc = 1

let s:FILE_NAME = expand('<sfile>:t:r')
let s:MODE_NAME = expand('<sfile>:h:t') . '#' . s:FILE_NAME

function fuf#ref#pydoc#createHandler(base)
  let a:base['menu'] = s:FILE_NAME
  return fuf#ref#createHandler(a:base)
endfunction

function fuf#ref#pydoc#getSwitchOrder()
  return g:fuf_line_switchOrder
endfunction

"
function fuf#ref#pydoc#renewCache()
  call fuf#ref#deleteCache(s:FILE_NAME)
endfunction

"
function fuf#ref#pydoc#requiresOnCommandPre()
  return 0
endfunction

"
function fuf#ref#pydoc#onInit()
  call fuf#defineLaunchCommand('FufRefPydoc', s:MODE_NAME, '""')
endfunction


