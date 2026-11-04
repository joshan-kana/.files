local vim = assert(_G.vim)
local M = {}

-- The pinned nvim-lspconfig definitions own commands, filetypes and roots.
-- Enable only servers whose executables are available in this environment.
function M.setup()
	if vim.g.editorLspDiscoveryActive then
		return
	end
	vim.g.editorLspDiscoveryActive = true

	vim.lsp.config("clangd", { cmd = { "clangd", "--function-arg-placeholders=0" } })

	local allowed = vim.env.NVIM_PROJECT_LSP_PATH or vim.g.editorLspPath or ""
	local function provided_by_project(command)
		for directory in allowed:gmatch("[^:]+") do
			if vim.fn.executable(directory .. "/" .. command) == 1 then
				return true
			end
		end
		return false
	end

	local cache_path = vim.fn.stdpath("cache") .. "/project-lsp-discovery.json"
	local cache_key = vim.fn.sha256("v2\n" .. allowed .. "\n" .. vim.o.runtimepath)
	local cached_ok, cached = pcall(function()
		return vim.json.decode(table.concat(vim.fn.readfile(cache_path), "\n"))
	end)
	local servers
	if cached_ok and type(cached) == "table" and cached.key == cache_key then
		servers = cached.servers
	end
	if type(servers) ~= "table" then
		servers = {}
		local seen = {}
		for _, path in ipairs(vim.api.nvim_get_runtime_file("lsp/*.lua", true)) do
			local name = vim.fn.fnamemodify(path, ":t:r")
			if not seen[name] then
				seen[name] = true
				local ok, config = pcall(function()
					return vim.lsp.config[name]
				end)
				if ok and config then
					local command = type(config.cmd) == "table" and config.cmd[1] or nil
					if type(config.cmd) == "function" then
						-- Some upstream configs wrap their executable in a launcher function.
						local source = table.concat(vim.fn.readfile(path), "\n")
						command = source:match("local%s+cmd%s*=%s*['\"]([%w_.%-]+)['\"]")
							or source:match("vim%.lsp%.rpc%.start%s*%(%s*{%s*['\"]([%w_.%-]+)['\"]")
					end
					if type(command) == "string" and provided_by_project(command) then
						-- nixd is preferred over nil when both are installed.
						if name ~= "nil_ls" or not provided_by_project("nixd") then
							table.insert(servers, name)
						end
					end
				end
			end
		end
		vim.fn.mkdir(vim.fn.stdpath("cache"), "p")
		pcall(vim.fn.writefile, { vim.json.encode({ key = cache_key, servers = servers }) }, cache_path)
	end
	for _, name in ipairs(servers) do
		vim.lsp.enable(name)
	end
end

return M
