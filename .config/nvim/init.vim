"
" vim-plug
"

call plug#begin()

" A 24bit colorscheme for Vim, Airline and Lightline
Plug 'jacoborus/tender.vim'

" 🍨 Soothing pastel theme for (Neo)vim
Plug 'catppuccin/nvim', { 'as': 'catppuccin' }

" A light and configurable statusline/tabline plugin for Vim
Plug 'itchyny/lightline.vim'

" Nvim Treesitter configurations and abstraction layer
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
" Treesitter playground integrated into Neovim
Plug 'nvim-treesitter/playground'

" Quickstart configs for Nvim LSP
Plug 'neovim/nvim-lspconfig'

" Supercharge your Rust experience in Neovim! A heavily modified fork of rust-tools.nvim
Plug 'mrcjkb/rustaceanvim'

" A completion plugin for neovim coded in Lua.
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-buffer'
Plug 'hrsh7th/cmp-path'
Plug 'hrsh7th/cmp-cmdline'
Plug 'hrsh7th/nvim-cmp'

Plug 'hrsh7th/cmp-vsnip'
Plug 'hrsh7th/vim-vsnip'

Plug 'hrsh7th/cmp-nvim-lua'
Plug 'hrsh7th/cmp-nvim-lsp-signature-help'

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

" Always show status line
" https://neovim.io/doc/user/options.html#'laststatus'
set laststatus=2
" Global status line at the bottom instead of one for each window
"set laststatus=3

" Enables 24-bit RGB color in the TUI
set termguicolors

"
" plugin: catppuccin
"

colorscheme catppuccin


"
" plugin: lightline
"

" set lighline theme inside lightline config
let g:lightline = { 'colorscheme': 'tender' }

"
" lspconfig
"

lua << EOF

-- Use the new vim.lsp.config API instead of lspconfig.setup()
local lsp_config = require('lspconfig.configs')

-- Configure gopls using the new API
vim.lsp.config.gopls = {
  cmd = { 'gopls' },
  filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
  root_markers = { 'go.work', 'go.mod', '.git' },
}

-- Enable gopls
vim.lsp.enable('gopls')

-- Global mappings.
-- See `:help vim.diagnostic.*` for documentation on any of the below functions
vim.keymap.set('n', '<space>e', vim.diagnostic.open_float)
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)
vim.keymap.set('n', ']d', vim.diagnostic.goto_next)
vim.keymap.set('n', '<space>q', vim.diagnostic.setloclist)

-- Use LspAttach autocommand to only map the following keys
-- after the language server attaches to the current buffer
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('UserLspConfig', {}),
  callback = function(ev)
    -- Enable completion triggered by <c-x><c-o>
    vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'

    -- Buffer local mappings.
    -- See `:help vim.lsp.*` for documentation on any of the below functions
    local opts = { buffer = ev.buf }
    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
    vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
    vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, opts)
    vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, opts)
    vim.keymap.set('n', '<space>wl', function()
      print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, opts)
    vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, opts)
    vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, opts)
    vim.keymap.set({ 'n', 'v' }, '<space>ca', vim.lsp.buf.code_action, opts)
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
    vim.keymap.set('n', '<space>f', function()
      vim.lsp.buf.format { async = true }
    end, opts)
  end,
})

EOF


"
" plugin: nvim-treesitter
"

lua << EOF

require 'nvim-treesitter.configs'.setup {
	ensure_installed = { "bash", "go", "gomod", "lua", "vim", "rust", },

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
" plugin: nvim-cmp
"

"
" Based on nvim-cmp's recommended configuration:
" https://github.com/hrsh7th/nvim-cmp?tab=readme-ov-file#recommended-configuration
"

lua <<EOF
  -- Set up nvim-cmp.
  local cmp = require'cmp'

  cmp.setup({
    snippet = {
      -- REQUIRED - you must specify a snippet engine
      expand = function(args)
        vim.fn["vsnip#anonymous"](args.body) -- For `vsnip` users.
      end,
    },
    window = {
	  completion = cmp.config.window.bordered(),
      documentation = cmp.config.window.bordered(),
    },
    mapping = cmp.mapping.preset.insert({
      ['<C-b>'] = cmp.mapping.scroll_docs(-4),
      ['<C-f>'] = cmp.mapping.scroll_docs(4),
      ['<C-Space>'] = cmp.mapping.complete(),
      ['<C-e>'] = cmp.mapping.abort(),
      ['<CR>'] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
	  -- Tab to select items
	  ['<Tab>'] = cmp.mapping.select_next_item(),
	  ['<S-Tab>'] = cmp.mapping.select_prev_item(),
    }),
    sources = cmp.config.sources({
      { name = 'nvim_lsp' },
      { name = 'nvim_lsp_signature_help' },
      { name = 'nvim_lua' },
      { name = 'vsnip' }, -- For vsnip users.
    }, {
      { name = 'buffer' },
    })
  })

  -- Set configuration for specific filetype.
  cmp.setup.filetype('gitcommit', {
    sources = cmp.config.sources({
      { name = 'git' }, -- You can specify the `git` source if [you were installed it](https://github.com/petertriho/cmp-git).
    }, {
      { name = 'buffer' },
    })
  })

  -- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
  cmp.setup.cmdline({ '/', '?' }, {
    mapping = cmp.mapping.preset.cmdline(),
    sources = {
      { name = 'buffer' }
    }
  })

  -- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
  cmp.setup.cmdline(':', {
    mapping = cmp.mapping.preset.cmdline(),
    sources = cmp.config.sources({
      { name = 'path' }
    }, {
      { name = 'cmdline' }
    })
  })

EOF
