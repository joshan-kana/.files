local vim = assert(_G.vim)
local M = {}

function M.setup(root)
	local contexts = {}
	for name, kind in vim.fs.dir(root .. "/hosts") do
		if kind == "directory" and vim.uv.fs_stat(root .. "/hosts/" .. name .. "/default.nix") then
			table.insert(contexts, name)
		end
	end
	table.sort(contexts)

	local available = {}
	for _, host in ipairs(contexts) do
		available[host] = true
	end

	local active = vim.env.FLK_PROFILE or vim.fn.hostname()
	if not available[active] then
		active = available[vim.fn.hostname()] and vim.fn.hostname() or contexts[1]
	end
	local overrides = {}

	local function context_for(bufnr)
		local path = vim.api.nvim_buf_get_name(bufnr)
		local relative = vim.fs.relpath(root, path)
		if not relative then
			return nil
		end
		local host = relative:match("^hosts/([^/]+)/")
		return overrides[bufnr] or (available[host] and host) or active
	end

	-- Keep the global nixd server available for unrelated projects, but do not
	-- let it race with the context-aware server inside this flake.
	local base = vim.lsp.config.nixd
	local markers = base.root_markers or { "flake.nix", ".git" }
	vim.lsp.config("nixd", {
		root_dir = function(bufnr, on_dir)
			local path = vim.api.nvim_buf_get_name(bufnr)
			if vim.fs.relpath(root, path) then
				on_dir(nil)
			else
				on_dir(vim.fs.root(bufnr, markers))
			end
		end,
	})
	local function detach_client(bufnr, client)
		vim.lsp.buf_detach_client(bufnr, client.id)
		if not next(client.attached_buffers) then
			client:stop()
		end
	end

	local function detach_default(bufnr, client)
		if client.name ~= "nixd" or not vim.fs.relpath(root, vim.api.nvim_buf_get_name(bufnr)) then
			return
		end
		vim.schedule(function()
			if vim.api.nvim_buf_is_valid(bufnr) and vim.lsp.buf_is_attached(bufnr, client.id) then
				detach_client(bufnr, client)
			end
		end)
	end

	vim.api.nvim_create_autocmd("LspAttach", {
		callback = function(args)
			local client = vim.lsp.get_client_by_id(args.data.client_id)
			if client then
				detach_default(args.buf, client)
			end
		end,
	})
	for _, client in ipairs(vim.lsp.get_clients({ name = "nixd" })) do
		for bufnr in pairs(client.attached_buffers) do
			detach_default(bufnr, client)
		end
	end

	local flake = "builtins.getFlake " .. vim.json.encode(root)
	local function options_for(host)
		local prelude = "let f = "
			.. flake
			.. "; name = "
			.. vim.json.encode(host)
			.. "; configurations = if builtins.hasAttr name f.nixosConfigurations then "
			.. "f.nixosConfigurations else f.darwinConfigurations; "
			.. "host = builtins.getAttr name configurations; in "
		-- nixd merges user-provided options with its built-in NixOS set. Suppress
		-- the unrelated default before selecting the evaluated host schema.
		local options = {
			nixos = { expr = "{ }" },
			["home-manager"] = {
				expr = prelude .. "host.options.home-manager.users.type.getSubOptions []",
			},
		}
		options[host] = {
			expr = prelude .. "f.lib.semanticScopeOptions.nixdHostOptions configurations host",
		}
		return options, prelude .. "host.pkgs"
	end

	local function attach(bufnr)
		if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].filetype ~= "nix" then
			return
		end
		local host = context_for(bufnr)
		if not host then
			return
		end

		vim.b[bufnr].nix_context = host
		local name = "nixd:" .. host
		local attached = false
		for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
			if client.name == name then
				attached = true
			elseif client.name:match("^nixd:") then
				detach_client(bufnr, client)
			end
		end
		if attached then
			return
		end

		local config = vim.deepcopy(vim.lsp.config.nixd)
		local options, packages = options_for(host)
		config.name = name
		config.root_dir = root
		config.settings = vim.tbl_deep_extend("force", config.settings or {}, {
			nixd = {
				nixpkgs = { expr = packages },
				options = options,
			},
		})
		vim.lsp.start(config, {
			bufnr = bufnr,
			reuse_client = function(client, candidate)
				return client.name == candidate.name and client.config.root_dir == candidate.root_dir
			end,
		})
	end

	local function select_context(bufnr, host)
		if host ~= "auto" and not available[host] then
			vim.notify("Unknown Nix configuration: " .. host, vim.log.levels.ERROR)
			return
		end
		if host == "auto" then
			overrides[bufnr] = nil
		else
			overrides[bufnr] = host
		end
		attach(bufnr)
	end

	vim.api.nvim_create_user_command("NixContext", function(args)
		local bufnr = vim.api.nvim_get_current_buf()
		if vim.bo[bufnr].filetype ~= "nix" or not context_for(bufnr) then
			vim.notify("Open a Nix file in this repository first", vim.log.levels.WARN)
			return
		end
		if args.args ~= "" then
			select_context(bufnr, args.args)
			return
		end
		local choices = { "auto" }
		vim.list_extend(choices, contexts)
		vim.ui.select(choices, {
			prompt = "Nix configuration (current: " .. context_for(bufnr) .. ")",
		}, function(choice)
			if choice then
				select_context(bufnr, choice)
			end
		end)
	end, {
		nargs = "?",
		complete = function()
			local names = { "auto" }
			vim.list_extend(names, contexts)
			return names
		end,
	})

	vim.api.nvim_create_autocmd({ "FileType", "BufEnter", "BufWinEnter" }, {
		pattern = "*",
		callback = function(args)
			attach(args.buf)
		end,
	})
	vim.api.nvim_create_autocmd("BufWipeout", {
		callback = function(args)
			overrides[args.buf] = nil
		end,
	})
	attach(vim.api.nvim_get_current_buf())
end

return M
