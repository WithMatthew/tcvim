-- Disable background installation only while the deployment script manages it.
if vim.env.NVIM_BOOTSTRAP ~= "1" then
  return {}
end
return {
  {
    "mason-org/mason.nvim",
    config = function(_, opts)
      require("mason").setup(opts)
    end,
  },
  {
    "mason-org/mason-lspconfig.nvim",
    opts = function(_, opts)
      opts.ensure_installed = {}
      opts.automatic_enable = false
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    build = function() end,
    config = function(_, opts)
      require("nvim-treesitter").setup(opts)
    end,
  },
}
