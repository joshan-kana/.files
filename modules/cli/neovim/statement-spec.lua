local vim = assert(_G.vim)

vim.opt.runtimepath:prepend(assert(os.getenv("EDITOR_GRAMMARS")))
local statements = dofile(assert(os.getenv("EDITOR_STATEMENT_MODULE")))

local cases = {
	{ "Nix attribute binding", "nix", "{ foo = 1| }", true },
	{ "Nix nested binding", "nix", "{ foo = { x = 1; }| }", true },
	{ "Nix let binding", "nix", "let foo = 1| in foo", true },
	{ "Nix successive attributes", "nix", "{ foo = 1|\n bar = 2; }", true },
	{ "Nix nested set application", "nix", "lib: { foo = lib.mkIf true { x = 1; }|\n bar = 2; }", true },
	{ "Nix already terminated binding", "nix", "{ foo = 1;| }", false },
	{ "Nix already terminated nested binding", "nix", "{ foo = { x = 1; };| }", false },
	{ "Nix import function argument", "nix", "import { foo = 1; }|", false },
	{ "Nix lambda parameter pattern", "nix", "{ lib, ... }: lib|", false },
	{ "Nix set expression after lambda", "nix", "x: { a = 1; }|", false },
	{ "Nix trailing set in list", "nix", "[ { a = 1; }| ]", false },
	{ "Nix set union continuation", "nix", "{ foo = { a = 1; }|\n // { b = 2; }; }", false },
	{ "Nix arithmetic continuation", "nix", "{ foo = 1|\n + 2; }", false },
	{ "Nix boolean continuation", "nix", "{ foo = x|\n && y; }", false },
	{ "Nix function application continuation", "nix", "{ foo = lib|\n.mkIf true { x = 1; }; }", false },
	{ "Nix already has semicolon after comment", "nix", "{ foo = 1| /* note */ ; }", false },
	{ "Nix inherit with semicolon", "nix", "{ inherit foo;| }", false },
	{ "Nix incomplete other syntax", "nix", "{ foo = 1|\n bar = ; }", false },
	{ "Nix plain expression", "nix", "builtins.attrNames { x = 1; }|", false },
	{ "Nix complete function", "nix", "{ x }: x|", false },
	{ "Nix comment", "nix", "{ foo = 1 # comment| \n }", false },
	{ "Nix string", "nix", '{ foo = "hello"|; }', false },
	{ "JavaScript ASI", "javascript", "const a = 1|\nconst b = 2", false },
	{ "JavaScript ASI runtime ambiguity", "javascript", "const a = 1|\n(function() {})()", false },
	{ "JavaScript explicit semicolon", "javascript", "const a = 1;|", false },
	{ "TypeScript statement", "typescript", "const a: number = 1|", false },
	{ "Rust missing let terminator", "rust", "fn f() { let x = 1|\nlet y = 2; }", true },
	{ "Rust final expression", "rust", "fn f() -> i32 { 1| }", false },
	{ "Rust existing semicolon", "rust", "fn f() { let x = 1;| }", false },
	{ "C++ class definition", "cpp", "class Foo {}|", true },
	{ "C++ if statement", "cpp", "void f() { if (true) {}| }", false },
	{ "Go function body", "go", "package main\nfunc main() { f()| }", false },
	{ "Python expression", "python", "x = 1|", false },
	{ "Markdown prose", "markdown", "Some prose|", false },
}

local function fixture(text, filetype)
	local offset = assert(text:find("|", 1, true))
	local source = text:sub(1, offset - 1) .. text:sub(offset + 1)
	local before = text:sub(1, offset - 1)
	local row = select(2, before:gsub("\n", "")) + 1
	local col = #(before:match("([^\n]*)$") or "")
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_current_buf(bufnr)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(source, "\n", { plain = true }))
	vim.bo[bufnr].filetype = filetype
	vim.api.nvim_win_set_cursor(0, { row, math.max(0, col - 1) })
	return bufnr, row, col, source
end

local failures = {}
local tested = 0
for _, case in ipairs(cases) do
	local bufnr, row, col, source = fixture(case[3], case[2])
	local candidate = statements.propose(bufnr, row, col - 1)
	if (candidate ~= nil) ~= case[4] then
		failures[#failures + 1] = case[1] .. ": unexpected proposal state"
	end
	local unchanged = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
	if unchanged ~= source then
		failures[#failures + 1] = case[1] .. ": proposal changed the buffer"
	end
	if candidate then
		local ok = statements.apply(candidate)
		if not ok then
			failures[#failures + 1] = case[1] .. ": approved edit did not apply"
		else
			local edited = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]
			if edited ~= candidate.after then
				failures[#failures + 1] = case[1] .. ": approved edit differs from preview"
			end
		end
	end
	tested = tested + 1
	vim.api.nvim_buf_delete(bufnr, { force = true })
end

do
	local bufnr, row, col = fixture("{ foo = 1| }", "nix")
	local candidate = assert(statements.propose(bufnr, row, col - 1))
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "{ foo = 2 }" })
	if statements.apply(candidate) then
		failures[#failures + 1] = "Stale buffer proposal was applied"
	end
	vim.api.nvim_buf_delete(bufnr, { force = true })
	tested = tested + 1
end

do
	local bufnr, row, col = fixture("{ foo = 1| }", "nix")
	vim.bo[bufnr].readonly = true
	if statements.propose(bufnr, row, col - 1) then
		failures[#failures + 1] = "Readonly buffer offered an edit"
	end
	vim.api.nvim_buf_delete(bufnr, { force = true })
	tested = tested + 1
end

do
	local bufnr, row, col = fixture("{ foo = 1| }", "nix")
	if statements.propose(bufnr, row, col - 2) then
		failures[#failures + 1] = "Proposed repair away from line end"
	end
	vim.api.nvim_buf_delete(bufnr, { force = true })
	tested = tested + 1
end

do
	local bufnr, row, col, source = fixture("{ foo = 1| }", "nix")
	local old = vim.ui.select
	vim.ui.select = function(_, _, callback)
		callback(nil)
	end
	vim.api.nvim_win_set_cursor(0, { row, col - 1 })
	statements.finish()
	vim.ui.select = old
	if table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n") ~= source then
		failures[#failures + 1] = "Cancelled confirmation edited buffer"
	end
	vim.api.nvim_buf_delete(bufnr, { force = true })
	tested = tested + 1
end

do
	local bufnr, row, col, source = fixture("{ foo = 1| }", "nix")
	vim.bo[bufnr].undolevels = -1
	vim.bo[bufnr].undolevels = 1000
	local previous = vim.ui.select
	vim.ui.select = function(items, opts, callback)
		if not opts.prompt:find("Finish statement", 1, true) or not items[1]:find("foo = 1;", 1, true) then
			failures[#failures + 1] = "Confirmation lacks an accurate edit preview"
		end
		callback(items[1], 1)
	end
	vim.api.nvim_win_set_cursor(0, { row, col - 1 })
	statements.finish()
	vim.ui.select = previous
	if table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n") == source then
		failures[#failures + 1] = "Confirmed suggestion was not applied"
	end
	vim.cmd.undo()
	if table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n") ~= source then
		failures[#failures + 1] = "Semicolon change was not undoable"
	end
	vim.api.nvim_buf_delete(bufnr, { force = true })
	tested = tested + 1
end

do
	local bufnr, row, col = fixture("{ foo = 1| }", "nix")
	local previous = vim.ui.select
	vim.ui.select = function(items, _, callback)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "{ foo = 2 }" })
		callback(items[1], 1)
	end
	vim.api.nvim_win_set_cursor(0, { row, col - 1 })
	statements.finish()
	vim.ui.select = previous
	if vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1] ~= "{ foo = 2 }" then
		failures[#failures + 1] = "Confirmation applied a stale suggestion"
	end
	vim.api.nvim_buf_delete(bufnr, { force = true })
	tested = tested + 1
end

if #failures > 0 then
	error(table.concat(failures, "\n"))
end
print("Passed " .. tested .. " semicolon repair cases")
