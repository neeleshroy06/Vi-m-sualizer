" vimshow.vim - logs completed NORMAL-mode commands (with English description)
" to a file that visualizer.py displays. Insert-mode typing is never logged.
let s:cpo_save = &cpo
set cpo&vim

" Shared file: Windows -> the user's temp folder; macOS/Linux -> /tmp.
" Set VIMSHOW_FILE before starting Vim and the overlay to use another path.
" Override before sourcing if needed, e.g. on a shared server:
" let g:vs_file = expand('~/.vim_cmd.txt')
if !exists('g:vs_file')
  if exists('$VIMSHOW_FILE') && $VIMSHOW_FILE !=# ''
    let g:vs_file = $VIMSHOW_FILE
  elseif has('win32')
    let g:vs_file = expand('$TEMP') . '\vim_cmd.txt'
  else
    let g:vs_file = '/tmp/vim_cmd.txt'
  endif
endif

" For remote Vim, set these before sourcing this file:
" let g:vs_transport = 'tcp'
" let g:vs_port = 8765
if !exists('g:vs_transport') | let g:vs_transport = 'file' | endif
if !exists('g:vs_host') | let g:vs_host = '127.0.0.1' | endif
if !exists('g:vs_port') | let g:vs_port = 8765 | endif

let s:buf = ''
let s:tcp_channel = 0

" ---------- capture ----------
function! Vs_log(k) abort
  let s:buf .= a:k
  return a:k
endfunction

function! Vs_logk(label, key) abort      " label is logged, key is executed
  let s:buf .= a:label
  return a:key
endfunction

function! Vs_logarg(k) abort             " keys that take an argument key
  let c = getcharstr()
  if c ==# "\<Esc>"
    let s:buf = ''
    return "\<Esc>"
  endif
  let s:buf .= a:k . c
  return a:k . c
endfunction

function! Vs_esc() abort
  let s:buf = ''
  return "\<Esc>"
endfunction

" single keys (normal + operator-pending). i/a are text-object prefixes in
" operator-pending mode, so they are handled below with an argument key.
for s:k in split('bcdeghjklnopsuvwxyABCDEGHIJKLNOPSVXY0123456789$^%{}()>.,;*#+-_=~!&', '\zs')
  exe 'nnoremap <expr> <silent> ' . s:k . ' Vs_log("' . s:k . '")'
  exe 'onoremap <expr> <silent> ' . s:k . ' Vs_log("' . s:k . '")'
endfor
nnoremap <expr> <silent> i Vs_log('i')
nnoremap <expr> <silent> a Vs_log('a')
onoremap <expr> <silent> i Vs_logarg('i')
onoremap <expr> <silent> a Vs_logarg('a')
nnoremap <expr> <silent> <lt> Vs_log('<')
onoremap <expr> <silent> <lt> Vs_log('<')

" prefix keys with an argument (f x, g g, z z, "a, m a, @a, ...)
for s:k in ['f', 'F', 't', 'T', 'g', 'z', '[', ']', "'", '`']
  let s:e = escape(s:k, '\"')
  exe 'nnoremap <expr> <silent> ' . s:k . ' Vs_logarg("' . s:e . '")'
  exe 'onoremap <expr> <silent> ' . s:k . ' Vs_logarg("' . s:e . '")'
endfor
for s:k in ['r', 'm', '@', 'Z', '"']
  let s:e = escape(s:k, '\"')
  exe 'nnoremap <expr> <silent> ' . s:k . ' Vs_logarg("' . s:e . '")'
endfor

" control keys
nnoremap <expr> <silent> <C-r> Vs_logk('^R', "\<C-r>")
nnoremap <expr> <silent> <C-d> Vs_logk('^D', "\<C-d>")
nnoremap <expr> <silent> <C-u> Vs_logk('^U', "\<C-u>")
nnoremap <expr> <silent> <C-f> Vs_logk('^F', "\<C-f>")
nnoremap <expr> <silent> <C-b> Vs_logk('^B', "\<C-b>")
nnoremap <expr> <silent> <Esc> Vs_esc()
onoremap <expr> <silent> <Esc> Vs_esc()

" ex commands and searches: log the final command line
let s:aborted = 0
cnoremap <expr> <Esc> Vs_cabort()
cnoremap <expr> <C-c> Vs_cabort()
function! Vs_cabort() abort
  let s:aborted = 1
  return "\<C-c>"
endfunction

augroup VimShow
  autocmd!
  autocmd CmdlineEnter * let s:aborted = 0
  autocmd CmdlineLeave * call s:Cmdline()
  autocmd SafeState * call s:Flush()
augroup END

function! s:Cmdline() abort
  if s:aborted | return | endif
  let t = getcmdtype()
  if t ==# ':' || t ==# '/' || t ==# '?'
    let s:buf = t . getcmdline()
  endif
endfunction

" ---------- dictionaries (vimtutor commands) ----------
let s:ops = {'d': 'delete', 'c': 'change', 'y': 'yank', '>': 'indent',
  \ '<': 'unindent', '=': 'auto-indent', 'gu': 'lowercase', 'gU': 'uppercase',
  \ 'g~': 'toggle case'}

let s:mots = {'w': 'word forward', 'b': 'word back', 'e': 'end of word',
  \ '0': 'line start', '$': 'line end', '^': 'first non-blank',
  \ 'j': 'down', 'k': 'up', 'h': 'left', 'l': 'right',
  \ '}': 'next paragraph', '{': 'prev paragraph', '(': 'prev sentence',
  \ ')': 'next sentence', 'gg': 'top of file', 'G': 'end of file',
  \ '%': 'matching bracket', ';': 'repeat f/t', ',': 'reverse f/t',
  \ 'n': 'next match', 'N': 'prev match', '*': 'next word under cursor',
  \ '#': 'prev word under cursor'}

let s:objs = {'iw': 'inner word', 'aw': 'a word', 'ip': 'inner paragraph',
  \ 'ap': 'a paragraph', 'is': 'inner sentence', 'as': 'a sentence',
  \ 'i"': 'inside quotes', 'a"': 'around quotes', "i'": 'inside single quotes',
  \ "a'": 'around single quotes', 'i(': 'inside parens', 'a(': 'around parens',
  \ 'ib': 'inside parens', 'i)': 'inside parens', 'i{': 'inside braces',
  \ 'a{': 'around braces', 'iB': 'inside braces', 'i[': 'inside brackets',
  \ 'a[': 'around brackets', 'it': 'inside tag', 'at': 'around tag'}

let s:ft = {'f': 'to', 'F': 'back to', 't': 'before', 'T': 'back before'}

let s:special = {'x': 'delete char', 'X': 'delete char before', 'u': 'undo',
  \ '^R': 'redo', 'p': 'paste after', 'P': 'paste before', 'i': 'insert',
  \ 'a': 'append', 'I': 'insert at line start', 'A': 'append at line end',
  \ 'o': 'open line below', 'O': 'open line above', 's': 'substitute char',
  \ 'S': 'substitute line', 'D': 'delete to line end', 'C': 'change to line end',
  \ 'Y': 'yank line', 'J': 'join lines', '.': 'repeat last change',
  \ '~': 'toggle case', 'v': 'visual select', 'V': 'visual line select',
  \ 'ZZ': 'save & quit', 'ZQ': 'quit without saving', 'zz': 'center screen',
  \ 'gg': 'top of file', 'G': 'end of file', '^D': 'half page down',
  \ '^U': 'half page up', '^F': 'page down', '^B': 'page up',
  \ 'H': 'top of screen', 'L': 'bottom of screen', 'M': 'middle of screen'}

let s:ex = {':w': 'save', ':q': 'quit', ':q!': 'quit without saving',
  \ ':wq': 'save & quit', ':x': 'save & quit', ':set number': 'show line numbers',
  \ ':set nu': 'show line numbers'}

" ---------- describe ----------
function! s:Mot(m) abort
  if has_key(s:objs, a:m) | return s:objs[a:m] | endif
  if has_key(s:mots, a:m) | return s:mots[a:m] | endif
  if a:m =~# '^[fFtT].$'
    return s:ft[a:m[0]] . ' "' . a:m[1] . '"'
  endif
  return a:m
endfunction

function! s:Describe(raw) abort
  let b = a:raw
  if b[0] ==# ':'
    return b . '  (' . get(s:ex, b, 'ex command') . ')'
  endif
  if b[0] ==# '/' || b[0] ==# '?'
    return b . '  (search)'
  endif

  let reg = matchstr(b, '^"\zs.')
  let b = substitute(b, '^".', '', '')
  let suffix = reg ==# '' ? '' : ' [register ' . reg . ']'

  " [count] operator [count] (motion | text object | operator again)
  let m = matchlist(b, '\C^\(\d*\)\(g[uU~]\|[dcy<>=]\)\(\d*\)\(.\+\)$')
  if !empty(m)
    let n = (m[1] ==# '' ? 1 : str2nr(m[1])) * (m[3] ==# '' ? 1 : str2nr(m[3]))
    let what = m[4] ==# m[2] ? 'line' : s:Mot(m[4])
    return a:raw . '  (' . s:ops[m[2]] . ' ' . (n > 1 ? n . '× ' : '') . what . ')' . suffix
  endif

  let m = matchlist(b, '\C^\(\d*\)\(.\+\)$')
  if empty(m) | return a:raw | endif
  let n = m[1] ==# '' ? 1 : str2nr(m[1])
  let c = m[2]
  if has_key(s:special, c)
    let name = s:special[c]
  elseif c =~# '^r.$'
    let name = 'replace with "' . c[1] . '"'
  elseif c =~# '^m.$'
    let name = 'set mark ' . c[1]
  elseif c =~# "^['`].$"
    let name = 'jump to mark ' . c[1]
  elseif c =~# '^@.$'
    let name = 'run macro ' . c[1]
  elseif s:Mot(c) !=# c
    let name = 'move ' . s:Mot(c)
  else
    let name = ''
  endif
  if name ==# '' | return a:raw . suffix | endif
  return a:raw . '  (' . (n > 1 ? n . '× ' : '') . name . ')' . suffix
endfunction

" ---------- flush when Vim is idle (command complete) ----------
function! s:SendTcp(message) abort
  if !exists('*ch_open') | return 0 | endif
  try
    if type(s:tcp_channel) != v:t_channel || ch_status(s:tcp_channel) !=# 'open'
      let s:tcp_channel = ch_open(g:vs_host . ':' . g:vs_port,
        \ {'mode': 'raw', 'waittime': 200})
    endif
    if type(s:tcp_channel) == v:t_channel && ch_status(s:tcp_channel) ==# 'open'
      call ch_sendraw(s:tcp_channel, a:message . "\n")
      return 1
    endif
  catch
    let s:tcp_channel = 0
  endtry
  return 0
endfunction

function! s:Flush() abort
  if s:buf ==# '' | return | endif
  let id = trim(reltimestr(reltime()))
  let message = id . '|' . s:Describe(s:buf)
  try
    if g:vs_transport ==# 'tcp' && s:SendTcp(message)
      let s:buf = ''
      return
    endif
    let l:dir = fnamemodify(g:vs_file, ':h')
    if !isdirectory(l:dir) | call mkdir(l:dir, 'p') | endif
    call writefile([message], g:vs_file)
  catch
  endtry
  let s:buf = ''
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save
