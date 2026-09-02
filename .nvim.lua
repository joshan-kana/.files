vim.lsp.config("nix_embedded", {
  cmd = { "nix-embedded-lsp" },
  filetypes = { "nix" },
  root_markers = { "kakehashi.toml", "flake.nix", ".git" },
  on_attach = function(_, bufnr)
    -- Kakehashi supplies Tree-sitter-backed semantic tokens for both Nix and
    -- injected languages, so stop a second editor-side highlighter once those
    -- tokens arrive.
    vim.api.nvim_create_autocmd("LspTokenUpdate", {
      buffer = bufnr,
      once = true,
      callback = function()
        vim.opt_local.syntax = "OFF"
        pcall(vim.treesitter.stop, bufnr)
      end,
    })
  end,
})

vim.lsp.enable("nix_embedded")

vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.nix",
  callback = function(args)
    vim.lsp.buf.format({ bufnr = args.buf, name = "nix_embedded" })
  end,
})
