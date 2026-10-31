local vim = assert(_G.vim)
local profiles = require("editor.profiles")
local snacks = require("snacks")

local pickers = {
	"files",
	"grep",
	"grep_word",
	"recent",
	"buffers",
	"commands",
	"lsp_symbols",
	"lsp_workspace_symbols",
	"lsp_definitions",
	"lsp_references",
	"lsp_implementations",
	"diagnostics",
	"git_status",
	"git_diff",
	"git_log",
	"keymaps",
	"undo",
}

for _, picker in ipairs(pickers) do
	assert(type(snacks.picker[picker]) == "function", "Missing picker: " .. picker)
end

assert(type(snacks.terminal.toggle) == "function")
assert(type(snacks.zen.zen) == "function")
assert(type(snacks.explorer.open) == "function")
assert(type(require("which-key").show) == "function")
assert(type(require("blink.cmp").get_lsp_capabilities) == "function")
local cmdline_keymap = require("blink.cmp.config").cmdline.keymap
assert(cmdline_keymap.preset == "cmdline")
assert(vim.deep_equal(cmdline_keymap["<Tab>"], { "accept", "fallback" }))
assert(vim.deep_equal(cmdline_keymap["<Up>"], { "insert_prev", "fallback" }))
assert(vim.deep_equal(cmdline_keymap["<Down>"], { "insert_next", "fallback" }))
assert(cmdline_keymap["<Right>"] == false)
assert(require("blink.cmp.config").cmdline.completion.menu.auto_show == true)
assert(type(require("lualine").get_config) == "function")
assert(type(require("conform").format) == "function")
assert(vim.fn.exists(":Format") == 2)
assert(vim.fn.executable("jj") == 1)
assert(vim.fn.executable("jjui") == 1)
assert(vim.fn.executable("nixd") == 1)
assert(vim.fn.executable("nixfmt") == 1)
assert(vim.fn.executable("git") == 1)
assert(vim.fn.executable("stylua") == 1)
assert(vim.fn.executable("ruff") == 1)
assert(vim.fn.executable("shfmt") == 1)
assert(vim.fn.executable("prettier") == 1)
assert(vim.bo.filetype == "nix")
assert(profiles.status() == "positional")
assert(vim.fn.maparg("h", "n") == "" and vim.fn.maparg("j", "n") == "")

vim.cmd("EditorSelection on")
vim.cmd("EditorKeymap native")
assert(profiles.status() == "native · select")
vim.cmd("EditorSelection off")
assert(profiles.status() == "native")

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "{ foo=1; }" })
vim.cmd("Format")
local formatted = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
assert(formatted:find("foo = 1;", 1, true), "Nix formatter did not run: " .. formatted)

local examples = {
	{ ft = "lua", before = "local answer=1", after = "local answer = 1" },
	{ ft = "python", before = "answer=1", after = "answer = 1" },
	{ ft = "sh", before = "echo    hello", after = "echo hello" },
	{ ft = "json", before = '{"answer":1}', after = '"answer": 1' },
	{ ft = "yaml", before = "answer:   1", after = "answer: 1" },
	{ ft = "markdown", before = "#  Heading", after = "# Heading" },
}
for _, example in ipairs(examples) do
	local buffer = vim.api.nvim_create_buf(true, false)
	vim.api.nvim_set_current_buf(buffer)
	vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { example.before })
	vim.bo.filetype = example.ft
	vim.cmd("Format")
	local result = table.concat(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), "\n")
	assert(result:find(example.after, 1, true), example.ft .. " formatter did not run: " .. result)
end

print("Editor integration smoke passed: plugins, commands, tools, profiles and seven formatter workflows")
vim.cmd("qa!")
