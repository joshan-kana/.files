local vim = assert(_G.vim)
local path = debug.getinfo(1, "S").source:sub(2)
local root = vim.fs.dirname(path)
vim.opt.runtimepath:append(root .. "/.nvim")

local servers = {
	nixd = "nixd",
	lua_ls = "lua-language-server",
	basedpyright = "basedpyright-langserver",
	bashls = "bash-language-server",
	jsonls = "vscode-json-language-server",
	yamlls = "yaml-language-server",
	marksman = "marksman",
	ts_ls = "typescript-language-server",
	csharp_ls = "csharp-ls",
	cssls = "vscode-css-language-server",
	taplo = "taplo",
	lemminx = "lemminx",
}
for name, command in pairs(servers) do
	if vim.fn.executable(command) == 1 then
		vim.lsp.enable(name)
	end
end
