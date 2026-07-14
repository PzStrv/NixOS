-- ============================================
--             _
--  _ ____   _(_)_ __ ___
-- | '_ \ \ / / | '_ ` _ \
-- | | | \ V /| | | | | | |
-- |_| |_|\_/ |_|_| |_| |_|
--
-- ============================================

-- ============================================
-- NVIM Configuration File (init.lua)
-- ============================================


-- ===========================================================
-- Leader Key and Keybindings
-- ===========================================================

vim.g.mapleader = ' '
vim.api.nvim_set_keymap('n', '<leader>e', ':e ~/.config/nvim/init.lua<CR>', { noremap = true, silent = true })    -- Example of a basic keymap: Open init.lua file

-- ===========================================================
-- packer.nvim
-- ===========================================================

-- Automatically install packer if not installed
local fn = vim.fn

local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
if fn.empty(fn.glob(install_path)) > 0 then
	PACKER_BOOTSTRAP = fn.system({
		'git', 'clone', '--depth', '1',
		'https://github.com/wbthomason/packer.nvim', install_path
	})
	print('Installing packer, close and reopen Neovim...')
	vim.cmd [[packadd packer.nvim]]
end

-- ===========================================================
-- Used Plugins
-- ===========================================================

require('packer').startup(function()
	use 'wbthomason/packer.nvim'

	-- Autopairs plugin
	use {
		'windwp/nvim-autopairs',
		config = function()
		require('nvim-autopairs').setup{
			check_ts = true,
			fast_wrap = {},
		}
	end
	}

	-- Colorizer
	use 'catgoose/nvim-colorizer.lua'

	-- VimTeX
	use 'lervag/vimtex'

	-- Completion engine
	use 'hrsh7th/nvim-cmp'

	-- Completion sources
	use 'hrsh7th/cmp-nvim-lsp'
	use 'hrsh7th/cmp-buffer'
	use 'hrsh7th/cmp-path'
	use 'hrsh7th/cmp-cmdline'

	-- Snippets
	use 'L3MON4D3/LuaSnip'
	use 'saadparwaiz1/cmp_luasnip'
	use 'rafamadriz/friendly-snippets'

	-- DAP (Debugger)
	use 'mfussenegger/nvim-dap'
	use 'mfussenegger/nvim-dap-python'
	use 'rcarriga/nvim-dap-ui'
	use 'nvim-neotest/nvim-nio'
	use 'theHamsta/nvim-dap-virtual-text'

	-- Colorscheme
	use 'sainnhe/gruvbox-material'

end)

-- ===========================================================
-- Appearance and Interface Settings
-- ===========================================================

-- Set background color (optional, depending on your terminal theme)
vim.opt.background = "dark"  -- Options: "dark" or "light"

-- Disable true color support (optional, if you prefer terminal palette)
vim.opt.termguicolors = true
vim.g.gruvbox_material_background = "hard"
vim.g.gruvbox_material_foreground = "material"
vim.g.gruvbox_material_enable_italic = 1
vim.g.gruvbox_material_better_performance = 1
vim.g.gruvbox_material_colors_override = {
  bg0 = { "#232628", "234" },
  bg1 = { "#1d1d21", "235" },
  bg2 = { "#28282e", "236" },
}
vim.cmd("colorscheme gruvbox-material")


vim.opt.number = true
vim.opt.relativenumber = true

-- Enable syntax highlighting
vim.opt.syntax = "on"
vim.opt.showmatch = true
vim.opt.title = true

-- ===========================================================
-- Colorizer Configuration
-- ===========================================================

require('colorizer').setup({
    filetypes = { '*' },
    buftypes = {},
    user_commands = true,
    user_default_options = {
    	names = false,
    	RRGGBBAA = true,
    	AARRGGBB = true,
    	rgb_fn = true,
    	hsl_fn = true,
    	oklch_fn = true,
    	css = true,
    	css_fn = true, -- Enable all CSS *functions*: rgb_fn, hsl_fn, oklch_fn
      	tailwind = true, -- Enable tailwind colors
      	sass = { enable = true, parsers = { 'css' } },
    	xterm = true,
      	always_update = true,
	},
})

-- ===========================================================
-- VimTeX Configuration
-- ===========================================================

vim.g.vimtex_compiler_method = 'latexmk'
vim.g.vimtex_view_method = 'zathura'
vim.g.vimtex_quickfix_mode = 0
vim.g.vimtex_compiler_autostart = 1
vim.g.vimtex_compiler_latexmk = {
	continuous = 1,
}

-- Compile automatically on every save
vim.api.nvim_create_autocmd('BufWritePost', {
	pattern = '*.tex',
	callback = function()
		vim.cmd('VimtexCompile')
	end,
})

-- ===========================================================
-- Autocomplete Configuration
-- ===========================================================

local cmp = require('cmp')
local luasnip = require('luasnip')

require('luasnip.loaders.from_vscode').lazy_load()

cmp.setup({
	snippet = {
		expand = function(args)
			luasnip.lsp_expand(args.body)
		end,
	},

	mapping = cmp.mapping.preset.insert({
		['<C-Space>'] = cmp.mapping.complete(),
		['<CR>'] = cmp.mapping.confirm({ select = true }),
		['<Tab>'] = cmp.mapping(function(fallback)
			if cmp.visible() then
				cmp.select_next_item()
			elseif luasnip.expand_or_jumpable() then
				luasnip.expand_or_jump()
			else
				fallback()
			end
		end, { 'i', 's' }),

		['<S-Tab>'] = cmp.mapping(function(fallback)
			if cmp.visible() then
				cmp.select_prev_item()
			elseif luasnip.jumpable(-1) then
				luasnip.jump(-1)
			else
				fallback()
			end
		end, { 'i', 's' }),
	}),

	sources = cmp.config.sources({
		{ name = 'nvim_lsp' },
		{ name = 'luasnip' },
		{ name = 'path' },
		{ name = 'buffer' },
	}),
})

cmp.setup.cmdline(':', {
	mapping = cmp.mapping.preset.cmdline(),
	sources = {
		{ name = 'path' },
		{ name = 'cmdline' },
	}
})

-- ===========================================================
-- DAP (Debugger) Configuration
-- ===========================================================

local dap = require('dap')
local dapui = require('dapui')

-- Virtual text: shows variable values inline while debugging
require('nvim-dap-virtual-text').setup({
	enabled = true,
	commented = false,
})

-- dap-ui layout
dapui.setup({
	layouts = {
		{
			elements = {
				{ id = 'scopes',      size = 0.40 },
				{ id = 'breakpoints', size = 0.20 },
				{ id = 'stacks',      size = 0.20 },
				{ id = 'watches',     size = 0.20 },
			},
			size = 40,
			position = 'left',
		},
		{
			elements = {
				{ id = 'repl',    size = 0.5 },
				{ id = 'console', size = 0.5 },
			},
			size = 12,
			position = 'bottom',
		},
	},
})

-- Auto open/close UI with debug session
dap.listeners.after.event_initialized['dapui_config'] = function() dapui.open() end
dap.listeners.before.event_terminated['dapui_config'] = function() dapui.close() end
dap.listeners.before.event_exited['dapui_config']     = function() dapui.close() end

-- Python adapter
-- Run once to set up the debugpy virtualenv:
--   mkdir -p ~/.virtualenvs
--   python -m venv ~/.virtualenvs/debugpy
--   ~/.virtualenvs/debugpy/bin/pip install debugpy
require('dap-python').setup('~/.virtualenvs/debugpy/bin/python')
require('dap-python').test_runner = 'pytest'

-- Breakpoint signs
vim.fn.sign_define('DapBreakpoint',          { text = '●', texthl = 'DapBreakpoint',     linehl = '', numhl = '' })
vim.fn.sign_define('DapBreakpointCondition', { text = '◆', texthl = 'DapBreakpointCond', linehl = '', numhl = '' })
vim.fn.sign_define('DapBreakpointRejected',  { text = '✗', texthl = 'DapBreakpointRej',  linehl = '', numhl = '' })
vim.fn.sign_define('DapLogPoint',            { text = '◎', texthl = 'DapLogPoint',        linehl = '', numhl = '' })
vim.fn.sign_define('DapStopped',             { text = '▶', texthl = 'DapStopped',         linehl = 'DapStoppedLine', numhl = '' })

vim.api.nvim_set_hl(0, 'DapBreakpoint',  { fg = '#e06c75' })
vim.api.nvim_set_hl(0, 'DapStopped',     { fg = '#98c379' })
vim.api.nvim_set_hl(0, 'DapStoppedLine', { bg = '#2e4034' })

-- DAP keymaps (<leader>d prefix)
local map = function(key, action, desc)
	vim.keymap.set('n', key, action, { desc = desc, noremap = true, silent = true })
end

-- Session control
map('<leader>dc', dap.continue,          'DAP: Continue / Start')
map('<leader>dt', dap.terminate,         'DAP: Terminate')
map('<leader>dr', dap.restart,           'DAP: Restart')

-- Stepping
map('<leader>do', dap.step_over,         'DAP: Step Over')
map('<leader>di', dap.step_into,         'DAP: Step Into')
map('<leader>dO', dap.step_out,          'DAP: Step Out')
map('<leader>dR', dap.run_to_cursor,     'DAP: Run to Cursor')

-- Breakpoints
map('<leader>db', dap.toggle_breakpoint, 'DAP: Toggle Breakpoint')
map('<leader>dB', function()
	dap.set_breakpoint(vim.fn.input('Condition: '))
end, 'DAP: Conditional Breakpoint')
map('<leader>dl', function()
	dap.set_breakpoint(nil, nil, vim.fn.input('Log message: '))
end, 'DAP: Log Point')
map('<leader>dL', dap.list_breakpoints,  'DAP: List Breakpoints')
map('<leader>dX', dap.clear_breakpoints, 'DAP: Clear All Breakpoints')

-- UI
map('<leader>du', dapui.toggle,          'DAP: Toggle UI')
map('<leader>de', dapui.eval,            'DAP: Eval Expression')

-- Python-specific
map('<leader>dpm', require('dap-python').test_method, 'DAP: Python Test Method')
map('<leader>dpc', require('dap-python').test_class,  'DAP: Python Test Class')

-- REPL
map('<leader>dq', dap.repl.open,         'DAP: Open REPL')

-- ===========================================================
-- Search and Search Behavior
-- ===========================================================

vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.wrapscan = true

-- ===========================================================
-- Indentation and Formatting Settings
-- ===========================================================

vim.opt.tabstop = 4    -- Set the number of spaces a tab character represents
vim.opt.shiftwidth = 4    -- Set the number of spaces for each level of indentation
vim.opt.smartindent = true
vim.opt.wrap = true
vim.opt.linebreak = true

-- ===========================================================
-- File and Encoding Settings
-- ===========================================================

vim.opt.fileencoding = 'utf-8'
vim.opt.fileformat = 'unix'
vim.opt.autoread = true

-- ===========================================================
-- File Management and Undo
-- ===========================================================

vim.opt.undofile = true
vim.opt.hidden = true

-- ===========================================================
-- Folding Settings
-- ===========================================================

vim.opt.foldmethod = 'indent'    -- (options: manual, indent, syntax, expr, marker)
vim.opt.foldlevelstart = 99

-- ===========================================================
-- Miscellaneous Settings
-- ===========================================================

vim.opt.list = true

