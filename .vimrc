syntax on
filetype plugin indent on

set ts=4
set sts=0
set sw=4

" Show the cursor position
set ruler
" Show the filename in the window titlebar
set title

set hlsearch

au BufRead,BufNewFile *.thrift set filetype=thrift
au BufRead,BufNewFile *.proto set filetype=proto
au BufRead,BufNewFile *.md set filetype=md
au! Syntax thrift source ~/.vim/thrift.vim
au! Syntax proto source ~/.vim/proto.vim

