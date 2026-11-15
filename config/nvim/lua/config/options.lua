-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.autoformat = true
vim.g.lazyvim_python_lsp = "pyright"
vim.g.lazyvim_python_ruff = "ruff"

-- Use stable absolute line numbers in editing windows.
vim.opt.number = true
vim.opt.relativenumber = false

vim.filetype.add({
  extension = {
    hlsl = "hlsl",
    hlsli = "hlsl",
    fx = "hlsl",
    fxh = "hlsl",
    slang = "shaderslang",
    glsl = "glsl",
    vert = "glsl",
    frag = "glsl",
    geom = "glsl",
    tesc = "glsl",
    tese = "glsl",
    comp = "glsl",
  },
})

require("config.portable").setup()

-- Optional overrides belong only to this machine and are not exported.
local local_config = vim.fs.joinpath(vim.fn.stdpath("config"), "lua", "config", "local.lua")
if vim.fn.filereadable(local_config) == 1 then
  dofile(local_config)
end
