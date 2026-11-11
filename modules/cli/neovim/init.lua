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
vim.opt.exrc = true
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
			header = "get. to. work.",
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
		},
	},
	explorer = { enabled = true },
	indent = { enabled = true, animate = { enabled = false } },
	input = { enabled = true },
	notifier = { enabled = true },
	picker = {
		enabled = true,
		win = { input = { keys = { ["<Esc>"] = { "close", mode = { "n", "i" } } } } },
	},
	quickfile = { enabled = true },
	scope = { enabled = true },
	scroll = { enabled = false },
	terminal = { enabled = true },
	words = { enabled = true },
	zen = { enabled = true },
})

require("editor.pairs").setup()

require("blink.cmp").setup({
	keymap = {
		preset = "enter",
		["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
		["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
		["<Esc>"] = { "cancel", "fallback" },
	},
	cmdline = {
		keymap = {
			preset = "cmdline",
			["<Tab>"] = { "select_next", "fallback" },
			["<S-Tab>"] = { "select_prev", "fallback" },
			["<CR>"] = { "accept", "fallback" },
			["<Esc>"] = { "cancel", "fallback" },
			["<Up>"] = { "insert_prev", "fallback" },
			["<Down>"] = { "insert_next", "fallback" },
			["<Right>"] = false,
		},
		completion = { menu = { auto_show = true } },
	},
	completion = { documentation = { auto_show = true } },
	fuzzy = { implementation = "rust", prebuilt_binaries = { download = false } },
	sources = {
		-- Blink uses buffer words only when its LSP and path sources fall back.
		default = { "lsp", "path", "snippets", "buffer" },
		transform_items = function(_, items)
			local seen, unique = {}, {}
			for _, item in ipairs(items) do
				if item.source_id == "lsp" then
					local name = item.filterText or item.label
					local insertion = item.textEdit and item.textEdit.newText or item.insertText
					-- An option-name completion should not insert the language server's
					-- full sample assignment. Explicit snippet completions are unaffected.
					if
						item.insertTextFormat == 2
						and type(name) == "string"
						and type(insertion) == "string"
						and insertion:sub(1, #name + 3) == name .. " = "
					then
						if item.textEdit then
							item.textEdit.newText = name
						end
						item.insertText = name
						item.insertTextFormat = 1
					end
				end
				local replacement = item.textEdit and item.textEdit.newText or item.insertText or item.label
				local key = table.concat({ item.label, item.detail or "", replacement, tostring(item.kind) }, "\0")
				if not seen[key] then
					seen[key] = true
					table.insert(unique, item)
				end
			end
			return unique
		end,
	},
})

vim.api.nvim_create_user_command("Format", function()
	if vim.fn.exists(":ProjectFormat") == 2 then
		vim.cmd.ProjectFormat()
	elseif #vim.lsp.get_clients({ bufnr = 0, method = "textDocument/formatting" }) > 0 then
		vim.lsp.buf.format({ async = true })
	else
		vim.notify("No formatter is available for this file", vim.log.levels.WARN)
	end
end, { desc = "Format the project or current file" })

require("editor.embedded").setup()

local which_key = require("which-key")
which_key.setup({ preset = "modern", delay = 0 })
which_key.add({
	{ "<leader>c", group = "Code" },
	{ "<leader>e", group = "Editor" },
	{ "<leader>f", group = "Find" },
	{ "<leader>g", group = "Version control" },
	{ "<leader>t", group = "Terminal" },
	{ "<leader>u", group = "View" },
	{ "<leader>w", group = "Windows" },
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
		lualine_x = {
			function()
				return vim.b.nix_context and ("Nix: " .. vim.b.nix_context) or ""
			end,
			profiles.status,
			"diagnostics",
			"filetype",
		},
		lualine_y = { "progress" },
		lualine_z = { "location" },
	},
})

require("editor.lsp").setup()

local key = vim.keymap.set
local picker = snacks.picker
for _, direction in ipairs({
	{ "h", "Left", "left" },
	{ "j", "Down", "below" },
	{ "k", "Up", "above" },
	{ "l", "Right", "right" },
}) do
	local action = "<C-w>" .. direction[1]
	local description = "Focus split " .. direction[3]
	key("n", "<leader>w" .. direction[1], action, { desc = description })
	key("n", "<leader>w<" .. direction[2] .. ">", action, { desc = description })
end
key("n", "<leader>ww", "<C-w>w", { desc = "Cycle splits" })
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
key("n", "<leader>co", function()
	if vim.fn.exists(":NixContext") == 2 then
		vim.cmd.NixContext()
	else
		vim.notify("No Nix configuration picker in this project", vim.log.levels.INFO)
	end
end, { desc = "Select Nix configuration" })
key("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code actions" })
key("n", "<leader>cr", vim.lsp.buf.rename, { desc = "Rename symbol" })
key("n", "<leader>cf", "<cmd>Format<cr>", { desc = "Format project" })
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
	snacks.terminal.toggle(vim.g.editorJjui, { cwd = root })
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
key("n", "<leader>?", require("editor.guide").open, { desc = "Keyboard reference" })
