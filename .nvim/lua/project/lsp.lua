local vim = assert(_G.vim)
local M = {}

-- Commands and filetypes live in the project, independent of nvim-lspconfig.
local servers = {
	nixd = { { "nixd" }, { "nix" } },
	lua_ls = { { "lua-language-server" }, { "lua" } },
	basedpyright = { { "basedpyright-langserver", "--stdio" }, { "python" } },
	bashls = { { "bash-language-server", "start" }, { "sh", "bash" } },
	jsonls = { { "vscode-json-language-server", "--stdio" }, { "json", "jsonc" } },
	yamlls = { { "yaml-language-server", "--stdio" }, { "yaml" } },
	marksman = { { "marksman", "server" }, { "markdown" } },
	ts_ls = {
		{ "typescript-language-server", "--stdio" },
		{ "typescript", "typescriptreact", "javascript", "javascriptreact" },
	},
	csharp_ls = { { "csharp-ls" }, { "cs" } },
	cssls = { { "vscode-css-language-server", "--stdio" }, { "css", "scss", "less" } },
	taplo = { { "taplo", "lsp", "stdio" }, { "toml" } },
	lemminx = { { "lemminx" }, { "xml", "xsd", "xsl", "xslt", "svg" } },
}

function M.setup()
	for name, spec in pairs(servers) do
		if vim.fn.executable(spec[1][1]) == 1 then
			vim.lsp.config(name, { cmd = spec[1], filetypes = spec[2], root_markers = { ".git" } })
			vim.lsp.enable(name)
		end
	end
end

return M
