local vim = assert(_G.vim)
vim.env.XDG_STATE_HOME = vim.fn.tempname()
vim.g.mapleader = " "
vim.opt.swapfile = false
vim.opt.undofile = false
local profiles = dofile("modules/cli/neovim/profiles.lua")
local checks = 0
local function expect(condition, message)
	assert(condition, message)
	checks = checks + 1
end
local function buffer(text)
	local buf = vim.api.nvim_create_buf(true, false)
	vim.api.nvim_set_current_buf(buf)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text, "\n", { plain = true }))
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	vim.cmd("let &undolevels = &undolevels")
end
local function text()
	return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
end
local function cursor(row, col)
	vim.api.nvim_win_set_cursor(0, { row, col })
end
local function normal(keys)
	vim.cmd("normal " .. keys)
end
local function feed(keys)
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, true, true), "mx", false)
end
profiles.setup()
expect(profiles.status() == "positional", "Default positional profile")
for _, lhs in ipairs({
	"z",
	"x",
	"H",
	"J",
	"K",
	"L",
	"<leader>ej",
	"<leader>ek",
	"<leader>eh",
	"<leader>el",
	"<leader>ed",
	"<leader>ey",
	"<leader>ec",
	"<leader>ep",
	"<leader>eP",
	"<leader>eo",
	"<leader>eO",
	"<leader>ea",
	"<leader>ei",
	"<leader>ex",
	"<leader>eX",
	"<leader>uc",
	"<leader>ut",
	"<leader>ub",
	"<leader>ua",
	"<leader>uo",
	"<leader>uC",
}) do
	expect(vim.fn.maparg(lhs, "n") ~= "", "Missing positional mapping: " .. lhs)
end
buffer("  alpha beta gamma")
cursor(1, 9)
normal("H")
expect(vim.api.nvim_win_get_cursor(0)[2] == 2, "H goes to first nonblank")
normal("L")
expect(vim.api.nvim_win_get_cursor(0)[2] == 17, "L goes to line end")
buffer("one\ntwo\nthree")
feed("<Space>ed")
expect(text() == "two\nthree", "Positional delete line action")
normal("z")
expect(text() == "one\ntwo\nthree", "Positional z actually undoes")
normal("x")
expect(text() == "two\nthree", "Positional x actually redoes")
buffer("one\ntwo")
feed("<Space>ey")
expect(vim.fn.getreg('"') == "one\n", "Positional yank line action")
feed("<Space>ep")
expect(text() == "one\none\ntwo", "Positional paste after")
buffer("one\ntwo")
feed("<Space>ej")
expect(text() == "one two", "Positional access to native line join")
buffer("abc")
feed("<Space>ex")
expect(text() == "bc", "Positional delete character alternative")
buffer("abc")
cursor(1, 1)
feed("<Space>eX")
expect(text() == "bc", "Positional backspace character alternative")
buffer("alpha")
feed("<Space>eiX<Esc>")
expect(text() == "Xalpha", "Positional insert at first nonblank")
buffer("alpha")
feed("<Space>eaZ<Esc>")
expect(text() == "alphaZ", "Positional append at end")
buffer("one\ntwo")
feed("<Space>ecNEW<Esc>")
expect(text() == "NEW\ntwo", "Positional change line action")
buffer("one\ntwo")
feed("<Space>eoBELOW<Esc>")
expect(text() == "one\nBELOW\ntwo", "Positional open below")
buffer("one\ntwo")
feed("<Space>eOABOVE<Esc>")
expect(text() == "ABOVE\none\ntwo", "Positional open above")
buffer("one\ntwo")
vim.fn.setreg('"', "COPIED\n", "l")
feed("<Space>eP")
expect(text() == "COPIED\none\ntwo", "Positional paste before")
buffer("one\ntwo\nthree")
feed("<Space>uc")
expect(text() == "one\ntwo\nthree", "Positional viewport centre preserves contents")
expect(vim.fn.maparg("q", "n") == "", "Positional leaves Vim macro recording intact")
profiles.set_keymap("native")
for _, lhs in ipairs({
	"z",
	"x",
	"H",
	"J",
	"K",
	"L",
	"<leader>ej",
	"<leader>ek",
	"<leader>eh",
	"<leader>el",
	"<leader>ed",
	"<leader>ey",
	"<leader>ec",
	"<leader>ep",
	"<leader>eP",
	"<leader>eo",
	"<leader>eO",
	"<leader>ea",
	"<leader>ei",
	"<leader>ex",
	"<leader>eX",
	"<leader>uc",
	"<leader>ut",
	"<leader>ub",
	"<leader>ua",
	"<leader>uo",
	"<leader>uC",
}) do
	expect(vim.fn.maparg(lhs, "n") == "", "Native profile must restore: " .. lhs)
end
buffer("alpha\nbeta")
normal("J")
expect(text() == "alpha beta", "Native J still joins lines")
profiles.set_keymap("positional")
buffer("alpha beta")
vim.keymap.set("n", "e", "q", { buffer = 0 })
profiles.set_selection(true)
expect(vim.fn.maparg("e", "n") == "q", "Buffer-local mapping takes precedence without preventing global selection mode")
profiles.set_selection(false)
expect(vim.fn.maparg("e", "n") == "q", "Switching selection off preserves buffer-local mappings")
profiles.set_selection(true)
for _, lhs in ipairs({
	"s",
	"S",
	"w",
	"W",
	"b",
	"B",
	"e",
	"E",
	"0",
	"^",
	"$",
	"gg",
	"G",
	"(",
	")",
	"{",
	"}",
	"f",
	"F",
	"t",
	"T",
	"n",
	"N",
}) do
	expect(vim.fn.maparg(lhs, "n") ~= "", "Missing selection-first motion: " .. lhs)
	expect(vim.fn.maparg(lhs, "o") == "", "Selection-first changes operator pending: " .. lhs)
end
local motion_cases = {
	{ "w", "one two three", 1, 0 },
	{ "W", "one two three", 1, 0 },
	{ "b", "one two three", 1, 10 },
	{ "B", "one two three", 1, 10 },
	{ "e", "one two three", 1, 0 },
	{ "E", "one two three", 1, 0 },
	{ "0", "  one two three", 1, 8 },
	{ "^", "  one two three", 1, 8 },
	{ "$", "one two three", 1, 0 },
	{ "gg", "one\ntwo\nthree", 3, 0 },
	{ "G", "one\ntwo\nthree", 1, 0 },
	{ "(", "One. Two. Three.", 1, 10 },
	{ ")", "One. Two. Three.", 1, 0 },
	{ "{", "First paragraph.\n\nSecond paragraph.", 3, 4 },
	{ "}", "First paragraph.\n\nSecond paragraph.", 1, 4 },
	{ "fg", "one good guest", 1, 0 },
	{ "Fg", "one good guest", 1, 10 },
	{ "tg", "one good guest", 1, 0 },
	{ "Tg", "one good guest", 1, 10 },
	{ "n", "one two one three", 1, 0 },
	{ "N", "one two one three", 1, 15 },
}
for _, example in ipairs(motion_cases) do
	buffer(example[2])
	cursor(example[3], example[4])
	vim.fn.setreg("/", "one")
	normal(example[1])
	expect(vim.fn.mode() == "v", "Selection motion must enter Visual mode: " .. example[1])
	feed("<Esc>")
end
buffer("one two three")
normal("wd")
expect(text() == "two three", "Word selection then delete")
buffer("one two three")
normal("WcREPLACED\027")
expect(text():find("REPLACED", 1, true) ~= nil, "WORD selection then change")
buffer("one two three")
normal("wy")
expect(vim.fn.getreg('"'):find("one", 1, true) ~= nil, "Word selection then yank")
buffer("one two three")
cursor(1, 6)
normal("siwd")
expect(text() == "one  three", "Inner-word text object")
buffer("(one two) three")
cursor(1, 3)
normal("si(d")
expect(text() == "() three", "Inner delimiter text object")
buffer("(one two) three")
cursor(1, 3)
normal("sa(d")
expect(text() == " three", "Around delimiter text object")
buffer("(one two) three")
normal("s%d")
expect(text() ~= "(one two) three", "Matching-delimiter selection via native matchit")
buffer("First paragraph.\n\nSecond paragraph.")
normal("sipd")
expect(text() ~= "First paragraph.\n\nSecond paragraph.", "Inner paragraph selection")
buffer('"one two" three')
cursor(1, 3)
normal('sa"d')
expect(text() == "three", "Around quote text object")
buffer("one\ntwo\nthree")
cursor(2, 0)
normal("Sd")
expect(text() == "one\nthree", "Whole line selection")
buffer("alpha beta gamma")
cursor(1, 10)
normal("bd")
expect(text():find("gamma", 1, true) ~= nil, "Backward-word motion")
buffer("alpha beta gamma")
normal("$d")
expect(text() ~= "alpha beta gamma", "Select to end of line")
buffer("alpha beta gamma")
cursor(1, 0)
normal("fgd")
expect(text():find("alpha", 1, true) == nil, "Find-character selection")
buffer("abc|def|ghi")
feed("f|d")
expect(text() == "def|ghi", "Find-character selection handles pipe")
buffer("abc\\def\\ghi")
feed("f\\d")
expect(text() == "def\\ghi", "Find-character selection handles backslash")
buffer("one two three four")
normal("2wd")
expect(text() == "three four", "Counted selection of two words")
buffer("ONE two three")
normal("wu")
expect(text() == "one two three", "Selection-first lowercase action")
buffer("one two three")
normal("wgU")
expect(text() == "ONE two three", "Selection-first uppercase action")
buffer("one two three")
normal("wrZ")
expect(text():match("^Z+"), "Selection-first replace action")
buffer("one two three")
normal("wy")
buffer("left right")
normal("wp")
expect(text():find("one", 1, true) ~= nil, "Selection-first paste replaces selection")
buffer("one\ntwo\nthree")
normal("S>")
expect(text():find("one", 1, true) ~= nil, "Linewise selection supports indentation")
buffer("one good guest gopher")
normal("2fgd")
expect(text() == "uest gopher", "Counted find-character selection")
buffer("one good guest gopher")
cursor(1, 19)
normal("2Fgd")
expect(text() ~= "one good guest gopher", "Counted backward find-character selection")
buffer("alpha beta gamma")
normal("d3w")
expect(text() == "", "Native count plus operator remains intact")
buffer("alpha beta gamma")
normal("e")
expect(vim.fn.mode() == "v", "End-of-word starts visual selection")
feed("<Esc>")
buffer("alpha beta gamma")
normal("s")
expect(vim.fn.mode() == "v", "Selection prefix enters Visual mode")
feed("<Esc>")
profiles.set_keymap("native")
buffer("alpha beta gamma")
normal("ciwHI\027")
expect(text():find("HI", 1, true) ~= nil, "Native operator grammar remains intact beneath overlay")
profiles.set_selection(false)
for _, lhs in ipairs({
	"s",
	"S",
	"w",
	"W",
	"b",
	"B",
	"e",
	"E",
	"0",
	"^",
	"$",
	"gg",
	"G",
	"(",
	")",
	"{",
	"}",
	"f",
	"F",
	"t",
	"T",
	"n",
	"N",
}) do
	expect(vim.fn.maparg(lhs, "n") == "", "Disabled selection mapping leaked: " .. lhs)
end
buffer("alpha beta")
normal("sZ\027")
expect(text() == "Zlpha beta", "Native substitute restored")
profiles.set_keymap("positional")
buffer("one\ntwo\nthree")
normal("J")
expect(vim.api.nvim_win_get_cursor(0)[1] > 1, "Positional J half-page navigation")
normal("K")
expect(vim.api.nvim_win_get_cursor(0)[1] == 1, "Positional K half-page navigation")
vim.fn.delete(vim.env.XDG_STATE_HOME, "rf")
print(checks .. " positional/selection interaction checks passed")
