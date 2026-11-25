local vim = assert(_G.vim)
local M = {}

-- Candidate generation never edits the user's buffer. A missing terminator is
-- offered only if the proposed edit makes the entire file parse.
local function syntax_errors(lines, language)
	local scratch = vim.api.nvim_create_buf(false, true)
	local ok, count = pcall(function()
		vim.api.nvim_buf_set_lines(scratch, 0, -1, false, lines)
		local parser = vim.treesitter.get_parser(scratch, language)
		local trees = parser:parse()
		local root = trees and trees[1] and trees[1]:root()
		if not root then
			error("No syntax tree")
		end

		local errors = 0
		local function visit(node)
			if node:type() == "ERROR" or node:missing() then
				errors = errors + 1
			end
			if node:has_error() then
				for child in node:iter_children() do
					visit(child)
				end
			end
		end
		visit(root)
		return errors
	end)
	vim.api.nvim_buf_delete(scratch, { force = true })
	return ok and count or nil
end

function M.propose(bufnr, row, cursor_col)
	if not vim.api.nvim_buf_is_valid(bufnr) or not vim.bo[bufnr].modifiable or vim.bo[bufnr].readonly then
		return nil
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	if #lines > 2000 or row < 1 or row > #lines then
		return nil
	end
	local line = lines[row]
	local col = cursor_col and cursor_col + 1 or line:match(".*()%S")
	if not col or col < 1 or col > #line then
		return nil
	end
	local suffix = line:sub(col + 1)
	-- The requested position must end a syntactic fragment. Do not split
	-- words or insert punctuation into arbitrary middle-of-line expressions.
	if
		not (suffix:match("^%s*$") or suffix:match("^%s*}") or suffix:match("^%s*%]") or suffix:match("^%s+in%s"))
		or line:sub(col, col):match("[%s;]")
	then
		return nil
	end

	local filetype = vim.bo[bufnr].filetype
	local language = vim.treesitter.language.get_lang(filetype)
	if not language then
		return nil
	end

	local corrected = line:sub(1, col) .. ";" .. suffix
	local before_errors = syntax_errors(lines, language)
	if not before_errors or before_errors == 0 then
		return nil
	end

	local updated = vim.deepcopy(lines)
	updated[row] = corrected
	if syntax_errors(updated, language) ~= 0 then
		return nil
	end

	return {
		bufnr = bufnr,
		row = row,
		col = col,
		before = line,
		after = corrected,
		filetype = filetype,
		changedtick = vim.api.nvim_buf_get_changedtick(bufnr),
	}
end

function M.apply(proposal)
	local bufnr = proposal.bufnr
	if
		not vim.api.nvim_buf_is_valid(bufnr)
		or not vim.bo[bufnr].modifiable
		or vim.bo[bufnr].readonly
		or vim.bo[bufnr].filetype ~= proposal.filetype
		or vim.api.nvim_buf_get_changedtick(bufnr) ~= proposal.changedtick
		or vim.api.nvim_buf_get_lines(bufnr, proposal.row - 1, proposal.row, false)[1] ~= proposal.before
	then
		return false
	end

	-- One undoable edit. Only apply the exact edit that was previewed.
	vim.api.nvim_buf_set_text(bufnr, proposal.row - 1, proposal.col, proposal.row - 1, proposal.col, { ";" })
	return true
end

function M.finish()
	local bufnr = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local proposal = M.propose(bufnr, cursor[1], cursor[2])
	if not proposal then
		vim.notify("No syntax-verified semicolon repair at the cursor", vim.log.levels.INFO)
		return
	end

	vim.ui.select({
		string.format("Insert: %s  →  %s", vim.trim(proposal.before), vim.trim(proposal.after)),
		"Cancel",
	}, { prompt = "Finish statement (syntax verified)" }, function(choice, index)
		if index ~= 1 or not choice then
			return
		end
		if not M.apply(proposal) then
			vim.notify("Buffer changed; semicolon suggestion cancelled", vim.log.levels.WARN)
		end
	end)
end

function M.setup()
	vim.api.nvim_create_user_command("StatementFinish", M.finish, {
		desc = "Preview a syntax-checked semicolon repair",
	})
end

return M
