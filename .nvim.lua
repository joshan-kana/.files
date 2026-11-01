local vim = assert(_G.vim)
local root = vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))

-- The Nix development shell supplies optional parsers and the embedded LSP bridge.
for runtime in (vim.env.NVIM_PROJECT_RUNTIMEPATH or ""):gmatch("[^,]+") do
	if vim.uv.fs_stat(runtime) then
		vim.opt.runtimepath:append(runtime)
	end
end
vim.opt.runtimepath:append(root .. "/.nvim")

require("project.lsp").setup()
require("project.embedded").setup()
require("project.treefmt").setup(root)
