local vim = assert(_G.vim)
local M = {}

-- Native Vim commands have no keymap entries. Keep a small learning reference
-- for those built-ins, then resolve overrides against the active mappings.
local reference = {
	Movement = {
		{ "h", "Left" },
		{ "j", "Down" },
		{ "k", "Up" },
		{ "l", "Right" },
		{ "w", "Next word" },
		{ "W", "Next WORD" },
		{ "b", "Previous word" },
		{ "B", "Previous WORD" },
		{ "e", "End of word" },
		{ "E", "End of WORD" },
		{ "0", "Start of line" },
		{ "^", "First non-blank" },
		{ "$", "End of line" },
		{ "gg", "First line" },
		{ "G", "Last line (or line number with a count)" },
		{ "H", "Top of screen" },
		{ "M", "Middle of screen" },
		{ "L", "Bottom of screen" },
		{ "<C-d>", "Half-page down" },
		{ "<C-u>", "Half-page up" },
		{ "<C-f>", "Page down" },
		{ "<C-b>", "Page up" },
		{ "%", "Matching bracket" },
		{ "f{char}", "Find character forwards", "f" },
		{ "F{char}", "Find character backwards", "F" },
		{ "t{char}", "Move before character forwards", "t" },
		{ "T{char}", "Move before character backwards", "T" },
		{ ";", "Repeat character find" },
		{ ",", "Reverse character find" },
	},
	Editing = {
		{ "i", "Insert before cursor" },
		{ "I", "Insert at first non-blank" },
		{ "a", "Append after cursor" },
		{ "A", "Append at end of line" },
		{ "o", "Open line below" },
		{ "O", "Open line above" },
		{ "x", "Delete character" },
		{ "X", "Delete previous character" },
		{ "s", "Substitute character" },
		{ "S", "Substitute line" },
		{ "r{char}", "Replace character", "r" },
		{ "R", "Replace mode" },
		{ "dd", "Delete line" },
		{ "D", "Delete to end of line" },
		{ "cc", "Change line" },
		{ "C", "Change to end of line" },
		{ "yy", "Yank line" },
		{ "p", "Paste after" },
		{ "P", "Paste before" },
		{ "u", "Undo" },
		{ "<C-r>", "Redo" },
		{ ".", "Repeat last change" },
		{ "J", "Join lines" },
	},
	Operators = {
		{ "d{motion}", "Delete through motion", false },
		{ "c{motion}", "Change through motion", false },
		{ "y{motion}", "Yank through motion", false },
		{ "diw", "Delete inner word", false },
		{ 'ci"', "Change inside quotes", false },
		{ "da(", "Delete around parentheses", false },
		{ "3w", "Move three words", false },
		{ "3dd", "Delete three lines", false },
	},
	Selection = {
		{ "v", "Start characterwise Visual mode" },
		{ "V", "Start linewise Visual mode" },
		{ "<C-v>", "Start blockwise Visual mode" },
		{ "gv", "Reselect previous Visual area" },
	},
	Search = {
		{ "/{pattern}", "Search forwards", false },
		{ "?{pattern}", "Search backwards", false },
		{ "n", "Next search match" },
		{ "N", "Previous search match" },
		{ "*", "Search word under cursor forwards" },
		{ "#", "Search word under cursor backwards" },
	},
	View = {
		{ "z", "Fold and viewport command prefix" },
		{ "zz", "Center current line" },
		{ "zt", "Move current line to top" },
		{ "zb", "Move current line to bottom" },
		{ "za", "Toggle fold" },
		{ "zo", "Open fold" },
		{ "zc", "Close fold" },
		{ "zR", "Open all folds" },
		{ "zM", "Close all folds" },
		{ "<C-o>", "Jump backward" },
		{ "<C-i>", "Jump forward" },
	},
	Registers = {
		{ "qa", "Record macro into register a", false },
		{ "q", "Stop recording macro" },
		{ "@a", "Play macro a", false },
		{ "@@", "Repeat last macro", false },
		{ '"ayy', "Yank line into register a", false },
	},
	Commands = {
		{ ":w", "Save file", false },
		{ ":q", "Quit", false },
		{ ":wq", "Save and quit", false },
		{ ":help {topic}", "Open built-in Vim documentation", false },
		{ "<Esc>", "Return to Normal mode", false },
	},
}

local order = { "Movement", "Editing", "Operators", "Selection", "Search", "View", "Registers", "Commands" }

local function effective(key, description, lookup)
	if lookup == false then
		return description
	end
	lookup = lookup or key
	-- A mapped prefix consumes the key sequence; e.g. positional z replaces zz.
	if #lookup > 1 and not lookup:find("<", 1, true) then
		for i = 1, #lookup - 1 do
			local prefix = vim.fn.maparg(lookup:sub(1, i), "n", false, true)
			if not vim.tbl_isempty(prefix) then
				return nil
			end
		end
	end
	local mapping = vim.fn.maparg(lookup, "n", false, true)
	if not vim.tbl_isempty(mapping) then
		return mapping.desc or "Custom mapping"
	end
	return description
end

function M.entries()
	local items, seen = {}, {}
	for _, group in ipairs(order) do
		for _, command in ipairs(reference[group]) do
			local key, description = command[1], effective(command[1], command[2], command[3])
			if description then
				items[#items + 1] = { group = group, key = key, description = description }
				seen[key] = true
			end
		end
	end
	-- Use actual registered mappings for profile overrides and app shortcuts.
	for _, mapping in ipairs(vim.api.nvim_get_keymap("n")) do
		if mapping.desc and not seen[mapping.lhs] then
			items[#items + 1] = { group = "Shortcuts", key = mapping.lhs, description = mapping.desc }
		end
	end
	for _, item in ipairs(items) do
		item.text = string.format("%-14s %-11s %s", item.key, item.group, item.description)
	end
	return items
end

function M.open()
	require("snacks").picker({
		title = "Keyboard reference · " .. require("editor.profiles").status(),
		items = M.entries(),
		format = "text",
		preview = "none",
		matcher = { sort_empty = false },
		layout = { preset = "vertical", preview = false },
		confirm = function(picker)
			picker:close()
		end,
	})
end

return M
