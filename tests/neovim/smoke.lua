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
assert(type(require("lualine").get_config) == "function")
assert(type(require("conform").format) == "function")
assert(vim.fn.exists(":Format") == 2)
assert(vim.fn.executable("jj") == 1)
assert(vim.fn.executable("jjui") == 1)
assert(vim.fn.executable("nixd") == 1)
assert(vim.fn.executable("nixfmt") == 1)
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

print("Editor integration smoke passed: plugins, commands, tools, profiles and Nix formatting")
vim.cmd("qa!")
