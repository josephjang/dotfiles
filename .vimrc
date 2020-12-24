" pathogen
execute pathogen#infect()

" vim-plug

call plug#begin('~/.vim/plugged')

Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

" Vim configuration for Rust
Plug 'rust-lang/rust.vim'

" Syntax checking hacks for vim
Plug 'vim-syntastic/syntastic'

call plug#end()

syntax on
filetype plugin indent on

set ts=4
set sts=4
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

""" bash scripts (*.sh)

" use 2 spaces
au BufRead,BufNewFile *.sh set sw=2 sts=2 expandtab
" automatically indent on loading
au BufRead *.sh normal gg=G

""" plugin: syntastic
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0


""" plugin: rust.vim
let g:rustfmt_autosave = 1

