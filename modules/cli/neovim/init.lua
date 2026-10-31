local vim = assert(_G.vim)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = "yes"
vim.opt.cursorline = true
vim.opt.scrolloff = 6
vim.opt.sidescrolloff = 6
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.undofile = true
vim.opt.updatetime = 250
vim.opt.timeoutlen = 400
vim.opt.termguicolors = true
vim.opt.winborder = "rounded"

vim.api.nvim_create_autocmd("BufReadPost", {
	callback = function(args)
		if vim.bo[args.buf].filetype:match("commit") or vim.bo[args.buf].filetype == "gitrebase" then
			return
		end
		local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
		if mark[1] > 1 and mark[1] <= vim.api.nvim_buf_line_count(args.buf) then
			pcall(vim.api.nvim_win_set_cursor, 0, mark)
		end
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	pattern = { "bash", "json", "lua", "markdown", "nix", "python", "sh", "vim", "vimdoc", "yaml" },
	callback = function(args)
		pcall(vim.treesitter.start, args.buf)
	end,
})

vim.diagnostic.config({
	severity_sort = true,
	virtual_text = { spacing = 3, prefix = "●" },
	float = { border = "rounded" },
})

local snacks = require("snacks")
snacks.setup({
	bigfile = { enabled = true },
	dashboard = { enabled = true },
	explorer = { enabled = true },
	indent = { enabled = true, animate = { enabled = false } },
	input = { enabled = true },
	notifier = { enabled = true },
	picker = { enabled = true },
	quickfile = { enabled = true },
	scope = { enabled = true },
	scroll = { enabled = false },
	words = { enabled = true },
})

require("blink.cmp").setup({
	keymap = { preset = "default" },
	completion = { documentation = { auto_show = true } },
	fuzzy = { implementation = "lua" },
	sources = { default = { "lsp", "path", "snippets", "buffer" } },
})

local which_key = require("which-key")
which_key.setup({ preset = "modern", delay = 250 })
which_key.add({
	{ "<leader>e", group = "Editor" },
	{ "<leader>f", group = "Find" },
	{ "<leader>c", group = "Code" },
})

local profiles = require("editor.profiles")
profiles.setup()

require("lualine").setup({
	options = {
		theme = "auto",
		globalstatus = true,
		section_separators = "",
		component_separators = "",
	},
	sections = {
		lualine_a = { "mode" },
		lualine_b = { "branch" },
		lualine_c = { { "filename", path = 1 } },
		lualine_x = { profiles.status, "diagnostics", "filetype" },
		lualine_y = { "progress" },
		lualine_z = { "location" },
	},
})

for _, server in ipairs({ "nixd", "lua_ls", "basedpyright", "bashls", "jsonls", "yamlls" }) do
	local commands = {
		lua_ls = "lua-language-server",
		basedpyright = "basedpyright-langserver",
		bashls = "bash-language-server",
		jsonls = "vscode-json-language-server",
		yamlls = "yaml-language-server",
	}
	if vim.fn.executable(commands[server] or server) == 1 then
		vim.lsp.enable(server)
	end
end

local picker = snacks.picker
vim.keymap.set("n", "<leader>ff", picker.files, { desc = "Find files" })
vim.keymap.set("n", "<leader>fg", picker.grep, { desc = "Search project" })
vim.keymap.set("n", "<leader>fb", picker.buffers, { desc = "Find buffers" })
vim.keymap.set("n", "<leader>fc", picker.commands, { desc = "Find commands" })
vim.keymap.set("n", "<leader>fe", snacks.explorer.open, { desc = "Explore files" })

vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code actions" })
vim.keymap.set("n", "<leader>cr", vim.lsp.buf.rename, { desc = "Rename symbol" })
vim.keymap.set("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Line diagnostics" })
vim.keymap.set("n", "]d", function()
	vim.diagnostic.jump({ count = 1, float = true })
end, { desc = "Next diagnostic" })
vim.keymap.set("n", "[d", function()
	vim.diagnostic.jump({ count = -1, float = true })
end, { desc = "Previous diagnostic" })

vim.keymap.set("n", "<leader>?", function()
	require("which-key").show({ global = false })
end, { desc = "Show keybindings" })
