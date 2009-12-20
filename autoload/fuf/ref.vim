if exists('g:loaded_autoload_fuf_ref') || v:version < 702
  finish
endif
let g:loaded_autoload_fuf_ref = 1

" }}}1
"=============================================================================
" GLOBAL FUNCTIONS {{{1

"
function fuf#ref#createHandler(base)
  return a:base.concretize(copy(s:handler))
endfunction

"
"function fuf#ref#getSwitchOrder()
"  return g:fuf_line_switchOrder
"endfunction
"
""
"function fuf#ref#renewCache()
"endfunction
"
""
"function fuf#ref#requiresOnCommandPre()
"  return 0
"endfunction
"
""
"function fuf#ref#onInit()
"  call fuf#defineLaunchCommand(s:handler.command, s:MODE_NAME, '""')
"endfunction

function! fuf#ref#deleteCache(menu)
  let cacheFile = expand(g:fuf_ref_cache_dir) . "/". a:menu
  call delete(cacheFile)
endfunction

" }}}1
"=============================================================================
" LOCAL FUNCTIONS/VARIABLES {{{1

let s:MODE_NAME = expand('<sfile>:t:r')
"let s:OPEN_TYPE_DELETE = -1

function! s:get_cache(menu)

  if isdirectory(expand(g:fuf_ref_cache_dir)) == 0
    call mkdir(expand(g:fuf_ref_cache_dir), 'p')
  endif

  let cacheFile = expand(g:fuf_ref_cache_dir) . "/". a:menu
  if filereadable(cacheFile)
    let items = readfile(cacheFile)
  else
    let items = ref#{a:menu}#complete('')
    call writefile(items, cacheFile)
  endif

  call map(items, 'fuf#makeNonPathItem(v:val, "")')
  call fuf#mapToSetSerialIndex(items, 1)
  call map(items, 'fuf#setAbbrWithFormattedWord(v:val, 1)')

  return items
endfunction

" }}}1
"=============================================================================
" s:handler {{{1

let s:handler = {}

"
function s:handler.getModeName()
  return s:MODE_NAME
endfunction

"
function s:handler.getPrompt()
  return fuf#formatPrompt(">Ref:". self.menu ."[]>", self.partialMatching)
endfunction

"
function s:handler.getPreviewHeight()
  return g:fuf_previewHeight
endfunction

"
function s:handler.targetsPath()
  return 0
endfunction

"
function s:handler.makePatternSet(patternBase)
  return fuf#makePatternSet(a:patternBase, 's:interpretPrimaryPatternForNonPath',
        \                   self.partialMatching)
endfunction

"
function s:handler.makePreviewLines(word, count)
  let lines = split(ref#{self.menu}#get_body(a:word), "\n")
  return fuf#makePreviewLinesAround(
        \ lines, [], a:count, self.getPreviewHeight())
endfunction

"
function s:handler.getCompleteItems(patternPrimary)
  return self.items
endfunction

"
function s:handler.onOpen(word, mode)
  let s = ""
  if a:mode == 1
    let s = "edit"
  elseif a:mode == 2
    let s = "split"
  elseif a:mode == 3
    let s = "vsplit"
  elseif a:mode == 4
    let s = "tabedit"
  end
  call ref#open(self.menu, a:word, s)
endfunction

"
function s:handler.onModeEnterPre()
  let self.items = s:get_cache(self.menu)
endfunction

"
function s:handler.onModeEnterPost()
endfunction

"
function s:handler.onModeLeavePost(opened)
endfunction

" }}}1
"=============================================================================
" vim: set fdm=marker:
