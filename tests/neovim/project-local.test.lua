local vim = assert(_G.vim)
local scratch = vim.fn.tempname()
local project = scratch .. "/project"
local config = scratch .. "/config"
local state = scratch .. "/state"
local cache = scratch .. "/cache"
local data = scratch .. "/data"

vim.fn.mkdir(project .. "/.nvim/lsp", "p")
vim.fn.mkdir(project .. "/nested", "p")
vim.fn.mkdir(config .. "/nvim", "p")
vim.fn.writefile(vim.fn.readfile(".nvim.lua"), project .. "/.nvim.lua")
vim.fn.writefile(vim.fn.readfile(".nvim/lsp/nixd.lua"), project .. "/.nvim/lsp/nixd.lua")
vim.fn.writefile({ "vim.opt.exrc = true" }, config .. "/nvim/init.lua")

local probe = scratch .. "/probe.lua"
vim.fn.writefile({
	"local vim = assert(_G.vim)",
	"local root = vim.fs.dirname(vim.fs.dirname(vim.fn.getcwd()))",
	"local paths = vim.api.nvim_get_runtime_file('lsp/nixd.lua', true)",
	"if vim.env.PROJECT_EXRC_TEST == 'blocked' then",
	"  assert(#paths == 0, 'Untrusted project configuration was executed')",
	"  return",
	"end",
	"assert(#paths == 1 and paths[1] == root .. '/.nvim/lsp/nixd.lua')",
	"local config = vim.lsp.config.nixd",
	"local options = config and config.settings and config.settings.nixd.options",
	"assert(options and options.nixos and options['nixos-server'] and options['home-manager'])",
	"local prefix = 'builtins.getFlake ' .. vim.json.encode(root)",
	"local host = 'let f = ' .. prefix .. '; in f.lib.semanticScopeOptions.nixdHostOptions f.nixosConfigurations '",
	"assert(options.nixos.expr == host .. 'f.nixosConfigurations.nixos')",
	"assert(options['nixos-server'].expr == host .. 'f.nixosConfigurations.nixos-server')",
	"local hm = '(' .. prefix .. ').nixosConfigurations.nixos.options.home-manager.users.type.getSubOptions []'",
	"assert(options['home-manager'].expr == hm)",
}, probe)

local function run(allowed)
	local args = { vim.v.progpath, "--headless" }
	if allowed == "approve" then
		table.insert(args, "--cmd")
		table.insert(
			args,
			"lua assert(vim.secure.trust({action='allow',path=" .. vim.json.encode(project .. "/.nvim.lua") .. "}))"
		)
	end
	vim.list_extend(args, { "-c", "luafile " .. vim.fn.fnameescape(probe), "-c", "qa!" })
	local result = vim.system(args, {
		cwd = project .. "/nested",
		env = {
			XDG_CONFIG_HOME = config,
			XDG_STATE_HOME = state,
			XDG_CACHE_HOME = cache,
			XDG_DATA_HOME = data,
			PROJECT_EXRC_TEST = (allowed == "blocked" and "blocked" or "allowed"),
		},
		text = true,
	}):wait()
	assert(result.code == 0, (result.stderr or "") .. (result.stdout or ""))
end

local success, problem = pcall(function()
	run("blocked")
	run("approve")
	run("allowed")
	local path = project .. "/.nvim.lua"
	vim.fn.writefile({ "-- changed" }, path, "a")
	run("blocked")
	run("approve")
end)
vim.fn.delete(scratch, "rf")
assert(success, problem)
print("Project-local Neovim LSP configuration and trust checks passed")
