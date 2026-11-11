local vim = assert(_G.vim)

vim.opt.runtimepath:prepend(assert(os.getenv("EDITOR_PAIRS_PLUGIN")))
dofile(assert(os.getenv("EDITOR_PAIRS_MODULE"))).setup()

local cases = {
	{ "Nix parentheses", "nix", "i(<Esc>", "()" },
	{ "Nix brackets", "nix", "i[<Esc>", "[]" },
	{ "Nix braces", "nix", "i{<Esc>", "{}" },
	{ "Lua nested pairs", "lua", "i({<Esc>", "({})" },
	{ "Rust parentheses", "rust", "i(<Esc>", "()" },
	{ "JavaScript braces", "javascript", "i{<Esc>", "{}" },
	{ "Python brackets", "python", "i[<Esc>", "[]" },
	{ "Markdown parentheses", "markdown", "i(<Esc>", "()" },
	{ "Plain text quotes", "text", 'i"<Esc>', '""' },
	{ "Single quotes", "python", "i'<Esc>", "''" },
	{ "Skip closing bracket", "nix", "i()<Esc>", "()" },
	{ "Skip closing brace", "rust", "i{}<Esc>", "{}" },
	{ "Delete empty pair", "nix", "i(<BS><Esc>", "" },
	{ "Delete empty quotes", "python", 'i"<BS><Esc>', "" },
	{ "Split Nix braces", "nix", "i{<CR><Esc>", "{\n\n}" },
	{ "Split JavaScript braces", "javascript", "i{<CR><Esc>", "{\n\n}" },
	{ "Split parentheses", "nix", "i(<CR><Esc>", "(\n\n)" },
	{ "No Nix semicolon after lone brace", "nix", "i{}<CR><Esc>", "{}\n" },
	{
		"No Nix semicolon after function parameter set",
		"nix",
		"A<CR><Esc>",
		"{ pkgs, ... }: pkgs\n",
		"{ pkgs, ... }: pkgs",
	},
	{
		"No semicolon after Nix import argument",
		"nix",
		"A<CR><Esc>",
		"import { pkgs = nixpkgs; }\n",
		"import { pkgs = nixpkgs; }",
	},
	{
		"No duplicate semicolon after nested Nix assignment",
		"nix",
		"A<CR><Esc>",
		"{ x = { y = 1; }; }\n",
		"{ x = { y = 1; }; }",
	},
	{ "No semicolon inserted in Python", "python", "i()<CR><Esc>", "()\n" },
	{ "No semicolon inserted in Markdown", "markdown", "i()<CR><Esc>", "()\n" },
	{ "Disable in picker inputs", "snacks_picker_input", "i(<Esc>", "(" },
}

local failures = {}
for _, case in ipairs(cases) do
	vim.cmd.enew({ bang = true })
	vim.bo.filetype = case[2]
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { case[5] or "" })
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	vim.fn.feedkeys(vim.api.nvim_replace_termcodes(case[3], true, false, true), "xt")
	local actual = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
	if actual ~= case[4] then
		failures[#failures + 1] = string.format("%s: expected %q, got %q", case[1], case[4], actual)
	end
end

if #failures > 0 then
	error(table.concat(failures, "\n"))
end
print(string.format("Passed %d Neovim pairing cases", #cases))
