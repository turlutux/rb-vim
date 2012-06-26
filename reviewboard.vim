let s:rb_buffer_id = -1
let g:rb_window_height = 8
let s:rb_buffer_name       = '[ReviewBoard]'

let g:filediffs = {}
let g:request_id = 0
let g:review_id = 0
let g:base_path = '/home/alain/linux_env/' "XXX User defined...alternatively, search for git root

let g:rb_command = expand("<sfile>:h:p") . '/vimrb.py'

function! s:RBCommand(command_args)
    let l:json = system(g:rb_command." ".a:command_args)
    execute "let l:object=".l:json
    return l:object
endfunction

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

    nnoremap <buffer> <silent> <Leader>s :call <SID>RBSaveComment()<CR>
endfunction



function! s:RBRelabelComments()
    sign unplace *
    let b:comment_signs = {}
    call s:RBLabelComments()
endfunction

function! s:RBSaveComment()
    let l:content = join(getline(0,'$'),"\n")
    let l:diff_filename = substitute(b:filename, "^".g:base_path, "", "")
    let l:filediff_id = g:filediffs["".l:diff_filename]['id']
    if g:review_id == ""
        call s:RBCreateDraft()
    endif
    let l:command_options = "-q ".g:request_id." -r ".g:review_id." -l ".b:line_number." -c \"".l:content."\" -n ".b:num_lines." -f ".l:filediff_id." -d 1 --dest" "XXX Note that dest is hardcoded default for now
    let l:new_comment = s:RBCommand( " comment ". l:command_options )
    call s:RBReturnToWindow()
    call add(b:comments, l:new_comment)
    call s:RBRelabelComments()
endfunction

command! -range -nargs=? RBWindowOpen  <line1>,<line2>call s:RBWindowOpen(<args>)
map <Leader>rb :RBWindowOpen<CR>

sign define draft_comment text=cc texthl=RBDraftComment
sign define public_comment text=pc texthl=RBPublicComment

function! s:RBLabelComments()
    if !exists("b:comments")
        let b:comments = s:RBCommand("diff -q ".g:request_id)
    endif

    silent let b:comment_signs = {}
    for l:comment in b:comments
        for i in range(1, l:comment['num_lines'])
            "Sign ids must be numbers
            let l:sign_id = l:comment['id']+(i*1000000)
            let l:line_number = l:comment['first_line']+i-1
            let l:sign_name = 'draft_comment'
            if l:comment['public'] == 'true'
                let l:sign_name = 'public_comment'
            endif

            let l:line_number = l:comment['first_line']+i-1
            let b:comment_signs[l:line_number] = l:sign_id
            exec ":sign place ".l:sign_id." line=".l:line_number." name=".l:sign_name." file=" .expand("%:p")
        endfor
    endfor
endfunction
command! RBLabelComments call s:RBLabelComments()
"XXX map <Leader>cc :RBLabelComments<CR>

function! s:RBDisplayComment()
    let l:current_line = line(".")
    for l:comment in b:comments
        for i in range(1, l:comment['num_lines'])
            let l:line_number = l:comment['first_line']+i-1
            if l:line_number == l:current_line
                call s:RBWindowOpen()
                silent %d
                let @c = l:comment['text']
                put! c
            endif
        endfor
    endfor
endfunction
command! RBDisplayComment call s:RBDisplayComment()


function! s:RBChooseReview(...)
    if a:0 < 1
        call s:RBWindowOpen()

        let l:json = system(g:rb_command." request -u dale")
        execute "let b:reviews=".l:json
        for l:review in b:reviews
            call append('$', "[".l:review['id']."] ".l:review['summary'])
        endfor

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

    call s:RBLoadFileDiffs()
    call s:RBLoadCurrentDraft()

    call s:RBReturnToWindow()

    call s:RBListFiles()

    au BufNewFile,BufRead * highlight RBPublicComment term=bold ctermfg=0 ctermbg=69
    au BufNewFile,BufRead * highlight RBDraftComment term=bold ctermfg=0 ctermbg=2
endfunction


function! s:RBLoadFileDiffs()
    let l:json = system(g:rb_command." file_diffs -q ".g:request_id)
    execute "let b:filediffs=".l:json
    let g:filediffs = {}
    for l:filediff in b:filediffs
        let g:filediffs[ l:filediff['dest_file'] ] = l:filediff
    endfor
endfunction
command! RBLoadFileDiffs  call s:RBLoadFileDiffs()

function! s:RBLoadCurrentDraft()
    let g:review_id = + system(g:rb_command." draft_id -q ".g:request_id)
endfunction

function! s:RBCreateDraft()
    let g:review_id = + system(g:rb_command." draft_id -q ".g:request_id." --create")
endfunction

function! s:RBListFiles()
    call s:RBWindowOpen()

    for [l:file_name, l:file_diff] in items(g:filediffs)
        call append('$', l:file_name)
    endfor

    nnoremap <buffer> <silent> <CR> :call <SID>RBOpenFile("edit")<CR>
    nnoremap <buffer> <silent> s :call <SID>RBOpenFile("split")<CR>
    nnoremap <buffer> <silent> v :call <SID>RBOpenFile("vsplit")<CR>
endfunction
command! RBListFiles  call s:RBListFiles()

function! s:RBOpenFile(command)
    let l:file_name = g:base_path . getline('.')

    call s:RBReturnToWindow()

    exec a:command." ".l:file_name
    call s:RBLabelComments()
endfunction

function! s:RBReturnToWindow()
    bdelete
    if bufwinnr(s:rb_buffer_last) != -1
        " If the buffer is visible, switch to it
        exec s:rb_buffer_last_winnr . "wincmd w"
    endif
endfunction

function! s:RBDiffSource()
    " Duplicated. Refactor.
    let l:diff_filename = substitute(expand("%:p"), "^".g:base_path, "", "")
    let l:filediff_source_revision = g:filediffs["".l:diff_filename]['source_revision']

    call s:RBOpenTempBuffer()

    execute "r !git show ".l:filediff_source_revision
    :0d
    diffthis
    wincmd p
    diffthis
endfunction
command! RBDiffSource  call s:RBDiffSource()

function! s:RBOpenTempBuffer()
    vnew
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal nowrap
    setlocal nonumber
    setlocal nobuflisted
    setlocal noreadonly
    setlocal modifiable
endfunction
