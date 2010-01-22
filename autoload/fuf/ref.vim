"
" add your .vimrc this setting.
" let g:fuf_modes = ['buffer', 'file', 'dir', 'mrufile', 'mrucmd',
"        \   'bookmark', 'tag', 'taggedfile',
"        \   'jumplist', 'changelist', 'quickfix', 'line', 'help',
"        \   'givenfile', 'givendir', 'givencmd',
"        \   'callbackfile', 'callbackitem',
"        \   'ref#phpmanual', 'ref#refe', 'ref#pydoc', 'ref#perldoc', 'ref#man']
"

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

" }}}1
"=============================================================================
" LOCAL FUNCTIONS/VARIABLES {{{1

let s:MODE_NAME = expand('<sfile>:t:r')
"let s:OPEN_TYPE_DELETE = -1


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
  let self.items = ref#{self.menu}#complete('')
  call map(self.items, 'fuf#makeNonPathItem(v:val, "")')
  call fuf#mapToSetSerialIndex(self.items, 1)
  call map(self.items, 'fuf#setAbbrWithFormattedWord(v:val, 1)')
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
