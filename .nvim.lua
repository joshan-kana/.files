local vim = assert(_G.vim)
local path = debug.getinfo(1, "S").source:sub(2)
local root = vim.fs.dirname(path)
vim.opt.runtimepath:append(root .. "/.nvim")
