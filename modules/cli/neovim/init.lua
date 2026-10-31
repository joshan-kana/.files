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
vim.opt.smartindent = true
vim.opt.undofile = true
vim.opt.confirm = true
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
	pattern = { "markdown", "gitcommit" },
	callback = function()
		vim.opt_local.wrap = true
		vim.opt_local.linebreak = true
		vim.opt_local.breakindent = true
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
	dashboard = {
		enabled = true,
		preset = {
			header = "Neovim",
			keys = {
				{ icon = "󰱼 ", key = "f", desc = "Find files", action = ":lua Snacks.picker.files()" },
				{ icon = "󰊄 ", key = "g", desc = "Search project", action = ":lua Snacks.picker.grep()" },
				{ icon = "󰋚 ", key = "r", desc = "Recent files", action = ":lua Snacks.picker.recent()" },
				{ icon = "󰙅 ", key = "e", desc = "File explorer", action = ":lua Snacks.explorer.open()" },
				{ icon = "󰗼 ", key = "q", desc = "Quit", action = ":qa" },
			},
		},
		sections = {
			{ section = "header", padding = 2 },
			{ section = "keys", gap = 1, padding = 1 },
			{ title = "Recent files", padding = 1 },
			{ section = "recent_files", limit = 6 },
			{ section = "startup" },
		},
	},
	explorer = { enabled = true },
	indent = { enabled = true, animate = { enabled = false } },
	input = { enabled = true },
	notifier = { enabled = true },
	picker = { enabled = true },
	quickfile = { enabled = true },
	scope = { enabled = true },
	scroll = { enabled = false },
	terminal = { enabled = true },
	words = { enabled = true },
	zen = { enabled = true },
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
	{ "<leader>c", group = "Code" },
	{ "<leader>e", group = "Editor" },
	{ "<leader>f", group = "Find" },
	{ "<leader>g", group = "Version control" },
	{ "<leader>t", group = "Terminal" },
	{ "<leader>u", group = "View" },
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

local servers = {
	nixd = "nixd",
	lua_ls = "lua-language-server",
	basedpyright = "basedpyright-langserver",
	bashls = "bash-language-server",
	jsonls = "vscode-json-language-server",
	yamlls = "yaml-language-server",
}
for name, command in pairs(servers) do
	if vim.fn.executable(command) == 1 then
		vim.lsp.enable(name)
	end
end

local key = vim.keymap.set
local picker = snacks.picker
key("n", "<leader>ff", picker.files, { desc = "Find files" })
key("n", "<leader>fg", picker.grep, { desc = "Search project" })
key("n", "<leader>fw", picker.grep_word, { desc = "Find word under cursor" })
key("x", "<leader>fw", picker.grep_word, { desc = "Find selected text" })
key("n", "<leader>fr", picker.recent, { desc = "Recent files" })
key("n", "<leader>fb", picker.buffers, { desc = "Switch buffers" })
key("n", "<leader>fc", picker.commands, { desc = "Find commands" })
key("n", "<leader>fe", snacks.explorer.open, { desc = "File explorer" })

key("n", "<leader>cs", picker.lsp_symbols, { desc = "Symbols in file" })
key("n", "<leader>cS", picker.lsp_workspace_symbols, { desc = "Workspace symbols" })
key("n", "<leader>cg", picker.lsp_definitions, { desc = "Go to definition" })
key("n", "<leader>cR", picker.lsp_references, { desc = "Find references" })
key("n", "<leader>ci", picker.lsp_implementations, { desc = "Find implementations" })
key("n", "<leader>ch", vim.lsp.buf.hover, { desc = "Hover documentation" })
key("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code actions" })
key("n", "<leader>cr", vim.lsp.buf.rename, { desc = "Rename symbol" })
key("n", "<leader>cf", function()
	vim.lsp.buf.format({ async = true })
end, { desc = "Format with attached language server" })
key("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Line diagnostics" })
key("n", "<leader>cD", picker.diagnostics, { desc = "All diagnostics" })
key("n", "]d", function()
	vim.diagnostic.jump({ count = 1, float = true })
end, { desc = "Next diagnostic" })
key("n", "[d", function()
	vim.diagnostic.jump({ count = -1, float = true })
end, { desc = "Previous diagnostic" })

key("n", "<leader>gs", picker.git_status, { desc = "Git status" })
key("n", "<leader>gd", picker.git_diff, { desc = "Git diff" })
key("n", "<leader>gl", picker.git_log, { desc = "Git log" })
key("n", "<leader>gj", function()
	local root = vim.fs.root(0, { ".jj" })
	if not root then
		vim.notify("Not inside a Jujutsu repository", vim.log.levels.WARN)
		return
	end
	snacks.terminal.toggle("jjui", { cwd = root })
end, { desc = "Jujutsu workbench" })

key("n", "<leader>tt", function()
	snacks.terminal.toggle()
end, { desc = "Toggle terminal" })
key("n", "<leader>uz", function()
	snacks.zen.zen()
end, { desc = "Toggle focus mode" })
key("n", "<leader>uw", function()
	vim.wo.wrap = not vim.wo.wrap
end, { desc = "Toggle line wrapping" })
key("n", "<leader>en", picker.keymaps, { desc = "Find keybindings" })
key("n", "<leader>eu", picker.undo, { desc = "Undo history" })
key("n", "<leader>?", function()
	which_key.show({ global = false })
end, { desc = "Show keybindings" })
