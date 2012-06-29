" To change mapping, just put
" let g:pep8_map='whatever'
" in your .vimrc
" To change the color of
command! -nargs=1 RB :call s:RB(<f-args>)
command! -nargs=1 RBshipit :call s:RBshipit(<f-args>)

let s:current_file=expand("<sfile>:h:p")

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

function! s:RBshipit(rev)
  let s:reviewers = system(s:current_file . '/../lib/reviewboard.py who -r ' . a:rev)
  execute "norm A ". s:reviewers
endfunction

"   if !exists('g:pep8_map')
" 	  let g:pep8_map='<F5>'
"   endif
" if ( !hasmapto('<SID>PEP8()') && (maparg(g:pep8_map) == '') )
"   exe 'nnoremap <silent> '. g:pep8_map .' :call <SID>Pep8()<CR>'
"   map <F5> :call <SID>Pep8()<CR>
"   map! <F5> :call <SID>Pep8()<CR>
" else
"   if ( !has("gui_running") || has("win32") )
"     echo "Python PEP8 Error: No Key mapped.\n".
"           \ g:pep8_map ." is taken and a replacement was not assigned."
"   endif
" endif

