local vim = assert(_G.vim)
vim.env.XDG_STATE_HOME = vim.fn.tempname()
local profiles = dofile("modules/cli/neovim/profiles.lua")

vim.g.mapleader = " "
vim.opt.swapfile = false
vim.opt.undofile = false

local checked = 0
local function expect(value, message)
	assert(value, message)
	checked = checked + 1
end

local function buffer(text)
	local buf = vim.api.nvim_create_buf(true, false)
	vim.api.nvim_set_current_buf(buf)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { text })
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
end

local function line()
	return vim.api.nvim_get_current_line()
end

profiles.setup()
expect(profiles.status() == "positional", "Positional profile is active at startup")
expect(vim.fn.maparg("z", "n") == "u", "Positional undo is available")
expect(vim.fn.maparg("x", "n"):lower() == "<c-r>", "Positional redo is available")
expect(vim.fn.maparg("h", "n") == "" and vim.fn.maparg("j", "n") == "", "Native hjkl remain unchanged")
profiles.set_selection(true)
expect(profiles.status() == "positional · select", "Selection is independent of positional profile")
buffer("one two three")
vim.cmd("normal wd")
expect(line() == "two three", "Selection-first wd works with positional keymap")
buffer("one two three")
vim.cmd("normal dw")
expect(line() == "two three", "Native operator-pending dw still works with selection enabled")
profiles.set_keymap("native")
expect(profiles.status() == "native · select", "Selection remains enabled on native Vim")
buffer("one two three")
vim.cmd("normal wd")
expect(line() == "two three", "Selection-first wd works with native Vim")
buffer("one two three")
vim.cmd("normal dw")
expect(line() == "two three", "Operator-first dw works with native Vim")
buffer("alpha-beta gamma")
vim.cmd("normal Wd")
expect(line() == "gamma", "Selection-first WORD deletion")
profiles.set_selection(false)
expect(vim.fn.maparg("w", "n") == "" and vim.fn.maparg("W", "n") == "", "Selection shortcuts fully removed")
buffer("one two three")
vim.cmd("normal x")
expect(line() == "ne two three", "Native delete-character is restored")
buffer("one two three four")
vim.cmd("normal d3w")
expect(line() == "four", "Native count and operator motion remain intact")
buffer("one two three")
vim.cmd([[normal "ayw]])
expect(vim.fn.getreg("a"):find("one", 1, true) ~= nil, "Native named-register yank")
vim.fn.setreg("q", "dw")
buffer("one two three")
vim.cmd("normal @q")
expect(line() == "two three", "Recorded-command macro playback")
buffer("alpha beta gamma")
vim.cmd([[execute "normal ciwZZZ\<Esc>"]])
expect(line() == "ZZZ beta gamma", "Native change inner word remains intact")
vim.cmd("normal w.")
expect(line() == "ZZZ ZZZ gamma", "Native dot-repeat remains intact")
profiles.set_keymap("positional")
expect(vim.fn.maparg("z", "n") == "u", "Positional mappings can be re-enabled")
profiles.set_keymap("native")
expect(vim.fn.maparg("z", "n") == "" and vim.fn.maparg("x", "n") == "", "Native mappings have no residual overlays")
vim.keymap.set("n", "z", "q")
local state_file = vim.fn.stdpath("state") .. "/editor-profiles.json"
local saved_before = table.concat(vim.fn.readfile(state_file), "\n")
local okay = pcall(profiles.set_keymap, "positional")
expect(
	not okay and vim.fn.maparg("x", "n") == "" and profiles.status() == "native",
	"Collision fails without a partial profile switch"
)
expect(table.concat(vim.fn.readfile(state_file), "\n") == saved_before, "Collision leaves saved preferences unchanged")
vim.keymap.del("n", "z")
profiles.set_keymap("positional")
expect(profiles.status() == "positional", "Profile works after collision has been resolved")
vim.keymap.set("n", "x", "q")
saved_before = table.concat(vim.fn.readfile(state_file), "\n")
local removed = pcall(profiles.set_keymap, "native")
expect(
	not removed and vim.fn.maparg("x", "n") == "q" and profiles.status() == "positional",
	"A changed active mapping is never removed"
)
expect(
	table.concat(vim.fn.readfile(state_file), "\n") == saved_before,
	"Failed switch does not update saved preferences"
)
vim.keymap.del("n", "x")
vim.keymap.set("n", "x", "<C-r>", { desc = "Redo", noremap = true })
profiles.set_keymap("native")
expect(profiles.status() == "native", "Switching succeeds when the active map is restored")
vim.fn.delete(vim.env.XDG_STATE_HOME, "rf")
print(checked .. " editing-profile checks passed")
