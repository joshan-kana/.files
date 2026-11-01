local vim = assert(_G.vim)
local M = {}

local hosts =
	{ nix = true, markdown = true, lua = true, python = true, html = true, typescript = true, javascript = true }

function M.setup()
	local ok, otter = pcall(require, "otter")
	if not ok then
		return
	end
	if not otter.did_setup then
		otter.setup({
			lsp = { diagnostic_update_events = { "BufWritePost", "InsertLeave" } },
			verbose = { no_code_found = false },
		})
	end

	local group = vim.api.nvim_create_augroup("EmbeddedLanguageIntelligence", { clear = true })
	local activated = {}
	local checked = {}
	local function try_activate(buffer)
		if activated[buffer] or not vim.api.nvim_buf_is_valid(buffer) or not hosts[vim.bo[buffer].filetype] then
			return
		end
		if vim.api.nvim_buf_line_count(buffer) > 12000 then
			return
		end
		local tick = vim.api.nvim_buf_get_changedtick(buffer)
		if checked[buffer] == tick then
			return
		end
		local parsed, parser = pcall(vim.treesitter.get_parser, buffer)
		if not parsed then
			return
		end
		parser:parse(true)
		checked[buffer] = tick
		if not next(parser:children()) then
			return
		end
		vim.api.nvim_buf_call(buffer, otter.activate)
		activated[buffer] = require("otter.keeper").has_raft(buffer)
	end
	vim.api.nvim_create_autocmd({ "FileType", "BufEnter", "BufWritePost" }, {
		group = group,
		callback = function(args)
			vim.schedule(function()
				try_activate(args.buf)
			end)
		end,
	})
	vim.api.nvim_create_autocmd("BufWipeout", {
		group = group,
		callback = function(args)
			activated[args.buf] = nil
			checked[args.buf] = nil
		end,
	})
	try_activate(vim.api.nvim_get_current_buf())
end

return M
