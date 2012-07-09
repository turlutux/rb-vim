let s:rb_buffer_id = -1
let g:rb_window_height = 8
let s:rb_buffer_name       = '[ReviewBoard]'

let g:filediffs = {}
let g:request_id = 0
let g:review_id = 0

let s:current_file=expand("<sfile>:h:p")

let g:rb_command = expand("<sfile>:h:p") . '/../lib/reviewboard.py'

function! s:RBWindowOpen() range
    " Save the current buffer number.
    let s:rb_buffer_last       = bufnr('%')
    let s:rb_buffer_last_winnr = winnr()
    let l:win_size = g:rb_window_height

    let g:rb_filename = expand("%:p")

    if bufwinnr(s:rb_buffer_id) == -1
        " Special consideration was involved with these sequence
        " of commands.  
        "     First, split the current buffer.
        "     Second, edit a new file.
        "     Third record the buffer number.
        " If a different sequence is followed when the reviewboard
        " buffer is closed, Vim's alternate buffer is the reviewboard
        " instead of the original buffer before the reviewboard
        " was shown.
        let cmd_mod = ''
        if v:version >= 700
            let cmd_mod = 'keepalt '
        endif
        exec 'silent! ' . cmd_mod . 'botright' . ' ' . l:win_size . 'split ' 

        " Using :e and hide prevents the alternate buffer
        " from being changed.
        exec ":e " . escape(s:rb_buffer_name, ' ')
        " Save buffer id
        let s:rb_buffer_id = bufnr('%') + 0
    else
        " If the buffer is visible, switch to it
        exec bufwinnr(s:rb_buffer_id) . "wincmd w"
    endif

    " Mark the buffer as scratch
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal nowrap
    setlocal nonumber
    setlocal nobuflisted
    setlocal noreadonly
    setlocal modifiable

    " Setup buffer variables
    let b:line_number = a:firstline
    let b:num_lines = a:lastline - a:firstline + 1
    let b:filename = g:rb_filename
endfunction

function! s:RBReturnToWindow()
    bdelete
    if bufwinnr(s:rb_buffer_last) != -1
        " If the buffer is visible, switch to it
        exec s:rb_buffer_last_winnr . "wincmd w"
    endif
endfunction

function! s:RBChooseReview(...)
    if a:0 < 1
        call s:RBWindowOpen()

        let l:json = system(g:rb_command." which --user user1")

        " Affect the wrapper variable reviews to let vim knows we have a
        " list
        execute "let b:reviews=" . l:json
        call append(0, b:reviews)

        nnoremap <buffer> <silent> <CR>  :call <SID>RBOpenRequest()<CR>
    else
        call <SID>RBOpenRequest(a:1)
    endif
endfunction
command! -nargs=? RBChooseReview  call s:RBChooseReview(<args>)

function! s:RBOpenRequest(...)
    if a:0 < 1
        let l:line = getline('.')
        let l:matches = matchlist(l:line, '^\[\([0-9]\+\)\]')
        let l:request_id = l:matches[1]
    else
        let l:request_id = a:1
    endif

    let g:request_id = l:request_id

    "call s:RBLoadFileDiffs()
    "call s:RBLoadCurrentDraft()
    "call s:RBReturnToWindow()
    "call s:RBListFiles()
    let l:json = system(g:rb_command." raw -r ".g:request_id)
    let b:lines=split(l:json, '\n')
    call rbpatch#PatchReview(b:lines)

endfunction

function! s:RBLoadFileDiffs()
    let l:json = system(g:rb_command." ldiff -r ".g:request_id)
    execute "let b:filediffs=".l:json
    let g:filediffs = {}
    for l:filediff in b:filediffs
        let g:filediffs[ l:filediff['dest_file'] ] = l:filediff
    endfor
endfunction

function! s:RBListFiles()
    call s:RBWindowOpen()

    let l:json = system(g:rb_command." ldiff -r ".g:request_id)
    execute "let b:filediffs=".l:json
    call append('$', b:filediffs)

    nnoremap <buffer> <silent> <CR> :call <SID>RBOpenFile("edit")<CR>
    nnoremap <buffer> <silent> s :call <SID>RBOpenFile("split")<CR>
    nnoremap <buffer> <silent> v :call <SID>RBOpenFile("vsplit")<CR>
endfunction

function! s:RB(rev)
  set lazyredraw
  " Close any existing cwindows.
  cclose
  let l:grepformat_save = &grepformat
  let l:grepprogram_save = &grepprg
  set grepformat&vim
  set grepformat&vim
  let &grepformat = '%f:%l:%m'
  "let &grepprg = 'pep8 --repeat'
  let &grepprg = s:current_file . '/../lib/reviewboard.py review -r ' . a:rev
  if &readonly == 0 | update | endif
  silent! grep! %
  let &grepformat = l:grepformat_save
  let &grepprg = l:grepprogram_save
  let l:mod_total = 0
  let l:win_count = 1
  " Determine correct window height
  windo let l:win_count = l:win_count + 1
  if l:win_count <= 2 | let l:win_count = 4 | endif
  windo let l:mod_total = l:mod_total + winheight(0)/l:win_count |
        \ execute 'resize +'.l:mod_total
  " Open cwindow
  execute 'belowright copen '.l:mod_total
  nnoremap <buffer> <silent> c :cclose<CR>
  set nolazyredraw
  redraw!
  let tlist=getqflist() ", 'get(v:val, ''bufnr'')')
  if empty(tlist)
	  if !hlexists('GreenBar')
		  hi GreenBar term=reverse ctermfg=white ctermbg=darkgreen guifg=white guibg=darkgreen
	  endif
	  echohl GreenBar
	  echomsg "No diff comments"
	  echohl None
	  cclose
  endif
endfunction
command! -nargs=1 RB :call s:RB(<f-args>)

function! s:RBshipit(rev)
  let s:reviewers = system(s:current_file . '/../lib/reviewboard.py who -r ' . a:rev)
  execute "norm A ". s:reviewers
endfunction
command! -nargs=1 RBshipit :call s:RBshipit(<f-args>)
