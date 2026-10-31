local vim = assert(_G.vim)
local M = {}

local active = {
	keymap = "positional",
	selection = false,
}

local mappings = {
	positional = {
		z = { "u", "Undo" },
		x = { "<C-r>", "Redo" },
	},
	selection = {
		w = { "vaw", "Select word" },
		W = { "vaW", "Select WORD" },
		S = { "V", "Select line" },
	},
}

local function apply(group, enabled)
	local items = mappings[group]
	if enabled then
		for lhs in pairs(items) do
			if vim.fn.maparg(lhs, "n") ~= "" then
				error("Existing normal-mode mapping for " .. lhs .. " prevents enabling " .. group)
			end
		end
		for lhs, value in pairs(items) do
			vim.keymap.set("n", lhs, value[1], { desc = value[2], noremap = true })
		end
	else
		for lhs, value in pairs(items) do
			if vim.fn.maparg(lhs, "n"):lower() ~= value[1]:lower() then
				error("Mapping for " .. lhs .. " changed while " .. group .. " was active")
			end
		end
		for lhs in pairs(items) do
			vim.keymap.del("n", lhs)
		end
	end
end

function M.set_keymap(name)
	if name ~= "native" and name ~= "positional" then
		error("Unknown keymap: " .. name)
	end
	if active.keymap == name then
		return
	end

	apply("positional", name == "positional")
	active.keymap = name
	vim.cmd.redrawstatus()
	vim.notify("Editing keymap: " .. name)
end

function M.set_selection(enabled)
	enabled = not not enabled
	if active.selection == enabled then
		return
	end

	apply("selection", enabled)
	active.selection = enabled
	vim.cmd.redrawstatus()
	vim.notify("Selection-first: " .. (enabled and "on" or "off"))
end

function M.status()
	return active.keymap .. (active.selection and " · select" or "")
end

function M.setup()
	active.keymap = "native"
	apply("positional", true)
	active.keymap = "positional"

	vim.api.nvim_create_user_command("EditorKeymap", function(opts)
		M.set_keymap(opts.args)
	end, {
		nargs = 1,
		complete = function()
			return { "native", "positional" }
		end,
		desc = "Choose native Vim or positional editing",
	})

	vim.api.nvim_create_user_command("EditorSelection", function(opts)
		local value = opts.args
		if value == "toggle" then
			M.set_selection(not active.selection)
		elseif value == "on" or value == "off" then
			M.set_selection(value == "on")
		else
			error("Expected on, off or toggle")
		end
	end, {
		nargs = 1,
		complete = function()
			return { "on", "off", "toggle" }
		end,
		desc = "Enable or disable selection-first editing",
	})

	vim.keymap.set("n", "<leader>em", function()
		M.set_keymap(active.keymap == "positional" and "native" or "positional")
	end, { desc = "Toggle Vim / positional keymap" })
	vim.keymap.set("n", "<leader>es", "<cmd>EditorSelection toggle<cr>", { desc = "Toggle selection-first overlay" })
end

return M
