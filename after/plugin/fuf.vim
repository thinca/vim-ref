if exists('g:loaded_after_fuf')
  finish
elseif v:version < 702
  echoerr 'FuzzyFinder does not support this version of vim (' . v:version . ').'
  finish
endif
let g:loaded_after_fuf = 1

for s in ['phpmanual', 'refe', 'pydoc', 'perldoc', 'man']
  call add(g:fuf_modes, "ref#". s)
  call fuf#ref#{s}#onInit()
endfor

function s:defineOption(name, default)
  if !exists(a:name)
    let {a:name} = a:default
  endif
endfunction

call s:defineOption('g:fuf_ref_cache_dir', '~/.vim-fuf-cache/ref')
