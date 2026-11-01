local vim = assert(_G.vim)
local root = vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))

-- The Nix development shell supplies optional parsers and the embedded LSP bridge.
for runtime in (vim.env.NVIM_PROJECT_RUNTIMEPATH or ""):gmatch("[^,]+") do
	if vim.uv.fs_stat(runtime) then
		vim.opt.runtimepath:append(runtime)
	end
end
vim.opt.runtimepath:append(root .. "/.nvim")

-- Project overrides must win even when the global editor already loaded a server.
for _, path in ipairs(vim.fn.glob(root .. "/.nvim/lsp/*.lua", false, true)) do
	local name = vim.fn.fnamemodify(path, ":t:r")
	vim.lsp.config(name, assert(loadfile(path))())
end

local function project_module(name)
	return assert(loadfile(root .. "/.nvim/" .. name .. ".lua"))()
end

project_module("lsp").setup()
project_module("embedded").setup()
project_module("commands").setup(root)
