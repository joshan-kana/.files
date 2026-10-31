local vim = assert(_G.vim)
local source = debug.getinfo(1, "S").source:sub(2)
local root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(source)))
local flake = "builtins.getFlake " .. vim.json.encode(root)
local hostOptions = "let f = " .. flake .. "; in f.lib.semanticScopeOptions.nixdHostOptions f.nixosConfigurations "

return {
	settings = {
		nixd = {
			options = {
				nixos = {
					expr = hostOptions .. "f.nixosConfigurations.nixos",
				},
				["nixos-server"] = {
					expr = hostOptions .. "f.nixosConfigurations.nixos-server",
				},
				["home-manager"] = {
					expr = "("
						.. flake
						.. ").nixosConfigurations.nixos.options.home-manager.users.type.getSubOptions []",
				},
			},
		},
	},
}
