local vim = assert(_G.vim)
local M = {}

local active = {
	keymap = "positional",
	selection = false,
}

local state_dir = vim.fn.stdpath("state")
local state_file = state_dir .. "/editor-profiles.json"

local function read_state()
	local stored = { keymap = "positional", selection = false }
	local file = io.open(state_file, "r")
	if not file then
		return stored
	end
	local contents = file:read("*a")
	file:close()
	local ok, decoded = pcall(vim.json.decode, contents)
	if not ok or type(decoded) ~= "table" then
		vim.notify("Invalid saved editor preferences; using defaults", vim.log.levels.WARN)
		return stored
	end
	if decoded.keymap == "native" or decoded.keymap == "positional" then
		stored.keymap = decoded.keymap
	end
	stored.selection = decoded.selection == true
	return stored
end

local function persist(field)
	local stored = read_state()
	stored[field] = active[field]
	local temporary = state_file .. "." .. vim.fn.getpid() .. ".tmp"
	local ok, err = pcall(function()
		vim.fn.mkdir(state_dir, "p")
		vim.fn.writefile({ vim.json.encode(stored) }, temporary)
		local renamed, reason = vim.uv.fs_rename(temporary, state_file)
		if not renamed then
			error(reason)
		end
	end)
	if not ok then
		vim.uv.fs_unlink(temporary)
		vim.notify("Unable to save editor preferences: " .. tostring(err), vim.log.levels.ERROR)
	end
end

local function select_motion(motion)
	return function()
		local count = vim.v.count > 0 and tostring(vim.v.count) or ""
		vim.cmd({ cmd = "normal", bang = true, args = { "v" .. count .. motion } })
	end
end

local function select_char_motion(motion)
	return function()
		local character = vim.fn.getcharstr()
		if character == "\027" then
			return
		end
		local count = vim.v.count > 0 and tostring(vim.v.count) or ""
		vim.cmd({ cmd = "normal", bang = true, args = { "v" .. count .. motion .. character } })
	end
end

local mappings = {
	positional = {
		z = { "u", "Undo" },
		x = { "<C-r>", "Redo" },
		H = { "^", "First non-blank character" },
		L = { "$", "End of line" },
		J = { "<C-d>", "Half-page down" },
		K = { "<C-u>", "Half-page up" },
		["<leader>ej"] = { "J", "Join lines" },
		["<leader>ek"] = { "K", "Keyword help" },
		["<leader>eh"] = { "H", "Top of screen" },
		["<leader>el"] = { "L", "Bottom of screen" },
		["<leader>ed"] = { "dd", "Delete line" },
		["<leader>ey"] = { "yy", "Yank line" },
		["<leader>ec"] = { "cc", "Change line" },
		["<leader>ep"] = { "p", "Paste after" },
		["<leader>eP"] = { "P", "Paste before" },
		["<leader>eo"] = { "o", "Open line below" },
		["<leader>eO"] = { "O", "Open line above" },
		["<leader>ea"] = { "A", "Append to end of line" },
		["<leader>ei"] = { "I", "Insert at first nonblank" },
		["<leader>ex"] = { "x", "Delete character" },
		["<leader>eX"] = { "X", "Delete character backwards" },
		["<leader>uc"] = { "zz", "Center current line" },
		["<leader>ut"] = { "zt", "Place current line at top" },
		["<leader>ub"] = { "zb", "Place current line at bottom" },
		["<leader>ua"] = { "za", "Toggle fold" },
		["<leader>uo"] = { "zo", "Open fold" },
		["<leader>uC"] = { "zc", "Close fold" },
	},
	selection = {
		s = { "v", "Select using a motion or text object" },
		S = { "V", "Select line" },
		w = { select_motion("aw"), "Select word" },
		W = { select_motion("aW"), "Select WORD" },
		b = { select_motion("b"), "Select to previous word" },
		B = { select_motion("B"), "Select to previous WORD" },
		e = { select_motion("e"), "Select to end of word" },
		E = { select_motion("E"), "Select to end of WORD" },
		["0"] = { select_motion("0"), "Select to beginning of line" },
		["^"] = { select_motion("^"), "Select to first non-blank" },
		["$"] = { select_motion("$"), "Select to end of line" },
		gg = { select_motion("gg"), "Select to start of file" },
		G = { select_motion("G"), "Select to end of file or line number" },
		["("] = { select_motion("("), "Select to previous sentence" },
		[")"] = { select_motion(")"), "Select to next sentence" },
		["{"] = { select_motion("{"), "Select to previous paragraph" },
		["}"] = { select_motion("}"), "Select to next paragraph" },
		f = { select_char_motion("f"), "Select until character" },
		F = { select_char_motion("F"), "Select backward until character" },
		t = { select_char_motion("t"), "Select before character" },
		T = { select_char_motion("T"), "Select backward before character" },
		n = { select_motion("n"), "Select next search match" },
		N = { select_motion("N"), "Select previous search match" },
	},
}
local function global_mapping(lhs)
	local expanded = lhs:gsub("^<leader>", vim.g.mapleader or "\\")
	local key = vim.api.nvim_replace_termcodes(expanded, true, true, true)
	for _, mapping in ipairs(vim.api.nvim_get_keymap("n")) do
		if vim.api.nvim_replace_termcodes(mapping.lhs, true, true, true) == key then
			return mapping
		end
	end
	return nil
end

local function apply(group, enabled)
	local items = mappings[group]
	if enabled then
		for lhs in pairs(items) do
			if global_mapping(lhs) ~= nil then
				error("Existing normal-mode mapping for " .. lhs .. " prevents enabling " .. group)
			end
		end
		for lhs, value in pairs(items) do
			vim.keymap.set("n", lhs, value[1], { desc = value[2], noremap = true })
		end
	else
		for lhs, value in pairs(items) do
			local mapping = global_mapping(lhs)
			local owned = mapping and mapping.desc == value[2]
			if owned and type(value[1]) == "function" then
				owned = mapping.callback == value[1]
			elseif owned then
				owned = mapping.rhs:lower() == value[1]:lower()
			end
			if not owned then
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
	persist("keymap")
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
	persist("selection")
	vim.cmd.redrawstatus()
	vim.notify("Selection-first: " .. (enabled and "on" or "off"))
end

function M.status()
	return active.keymap .. (active.selection and " · select" or "")
end

function M.setup()
	local stored = read_state()
	active.keymap = "native"
	active.selection = false
	if stored.keymap == "positional" then
		apply("positional", true)
		active.keymap = "positional"
	end
	if stored.selection then
		apply("selection", true)
		active.selection = true
	end

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
