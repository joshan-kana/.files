local vim = assert(_G.vim)
local source = vim.fs.joinpath(vim.fn.getcwd(), ".nvim/lsp/nixd.lua")
local options = dofile(source).settings.nixd.options

local function evaluate(expression)
	local result = vim.system({ "nix", "eval", "--impure", "--json", "--expr", expression }, { text = true })
		:wait(45000)
	assert(result and result.code == 0, result and result.stderr or "Nix evaluation timed out")
	return vim.json.decode(result.stdout)
end

for _, name in ipairs({ "nixos", "nixos-server" }) do
	local expression = "let options = ("
		.. options[name].expr
		.. "); scopes = options.dotfiles.scopes.type.getSubOptions []; in { "
		.. 'neovim = builtins.hasAttr "neovim" (scopes.cli.type.getSubOptions []); '
		.. 'edits = builtins.hasAttr "neovim" options.scopeEdits.cli; '
		.. 'services = builtins.hasAttr "services" options; }'
	local values = evaluate(expression)
	assert(values.neovim and values.edits and values.services, "Nixd semantic options unavailable for " .. name)
end

local expression = "let options = ("
	.. options["home-manager"].expr
	.. "); in { "
	.. 'home = builtins.hasAttr "home" options; '
	.. 'programs = builtins.hasAttr "programs" options; '
	.. 'xdg = builtins.hasAttr "xdg" options; }'
local home = evaluate(expression)
assert(home.home and home.programs and home.xdg, "Nixd Home Manager options unavailable")

print("Nixd semantic scopes and Home Manager option expressions evaluated for both NixOS hosts")
