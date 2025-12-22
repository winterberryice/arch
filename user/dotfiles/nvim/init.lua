-- my-distro neovim configuration
-- User dotfile template

-- Basic settings
vim.opt.number = true         -- Show line numbers
vim.opt.relativenumber = true -- Relative line numbers
vim.opt.expandtab = true      -- Use spaces instead of tabs
vim.opt.shiftwidth = 4        -- Indent by 4 spaces
vim.opt.tabstop = 4           -- Tab = 4 spaces
vim.opt.smartindent = true    -- Smart indenting
vim.opt.wrap = false          -- Don't wrap lines
vim.opt.ignorecase = true     -- Case insensitive search
vim.opt.smartcase = true      -- Unless uppercase in search
vim.opt.termguicolors = true  -- True color support

-- Leader key
vim.g.mapleader = ' '

-- Key mappings
vim.keymap.set('n', '<leader>w', ':w<CR>', { desc = 'Save file' })
vim.keymap.set('n', '<leader>q', ':q<CR>', { desc = 'Quit' })
vim.keymap.set('n', '<leader>h', ':noh<CR>', { desc = 'Clear highlights' })

-- TODO: Add your neovim customizations and plugins here
