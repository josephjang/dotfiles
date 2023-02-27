"
" vim-plug
"

call plug#begin()

" A 24bit colorscheme for Vim, Airline and Lightline
Plug 'jacoborus/tender.vim'

" A light and configurable statusline/tabline plugin for Vim
Plug 'itchyny/lightline.vim'

" Nvim Treesitter configurations and abstraction layer
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
" Treesitter playground integrated into Neovim
Plug 'nvim-treesitter/playground'

" Quickstart configs for Nvim LSP
Plug 'neovim/nvim-lspconfig'

call plug#end()

"
" Common Configurations
"

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

set clipboard^=unnamed,unnamedplus

" Global status line at the bottom instead of one for each window
set laststatus=3

" Enables 24-bit RGB color in the TUI
set termguicolors

"
" plugin: tender
"

colorscheme tender

"
" plugin: lightline
"

" set lighline theme inside lightline config
let g:lightline = { 'colorscheme': 'tender' }

"
" plugin: nvim-treesitter
"

lua << EOF

require 'nvim-treesitter.configs'.setup {
	ensure_installed = { "bash", "go", "gomod", "lua", "vim", },

	highlight = {
		enable = true,
		additional_vim_regex_highlighting=false,
	},

	indent = {
		enable = true
	}
}

EOF

"
" plugin: nvim-lspconfig
"

lua << EOF

require 'lspconfig'.gopls.setup {}

EOF

