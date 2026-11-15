local function run()
  local portable = require("config.portable")
  for _, command in ipairs({ "git", "node", "python", "rg", "fd", "lazygit", "tree-sitter", "clang-format", "cmake", "ninja", "curl", "clangd-msvc.cmd" }) do
    assert(vim.fn.executable(command) == 1, "Command missing: " .. command)
  end
  for _, exe in ipairs({
    portable.msys("clang.exe"),
    portable.tools("treesitter", "clang.cmd"),
    portable.tools("shader-language-server", "shader-language-server.exe"),
    vim.fn.stdpath("data") .. "/mason/packages/codelldb/extension/adapter/codelldb.exe",
    vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/Scripts/python.exe",
  }) do
    assert(vim.fn.executable(exe) == 1, "Executable missing: " .. exe)
  end
  require("lazy").load({ plugins = { "mason.nvim", "nvim-treesitter", "nvim-dap", "nvim-dap-python", "nvim-lspconfig", "conform.nvim", "blink.cmp" } })
  assert(vim.o.number and not vim.o.relativenumber, "Absolute line numbers are not enabled")
  assert(vim.g.autoformat == true, "Autoformat is not enabled")
  for extension, ft in pairs({ cpp = "cpp", py = "python", hlsl = "hlsl", slang = "shaderslang", frag = "glsl" }) do
    assert(vim.filetype.match({ filename = "example." .. extension }) == ft, "Filetype mismatch: " .. extension)
  end
  for _, lang in ipairs({ "c", "cpp", "python", "hlsl", "glsl", "lua", "cmake" }) do
    assert(pcall(vim.treesitter.language.add, lang), "Parser cannot load: " .. lang)
  end
  local dap = require("dap")
  assert(dap.adapters.codelldb.executable.command:match("codelldb.exe$"), "CodeLLDB adapter is not configured")
  assert(type(dap.adapters.python) == "function", "Python DAP is not configured")
  local lsp = require("lazy.core.plugin").values(require("lazy.core.config").plugins["nvim-lspconfig"], "opts", false)
  for _, server in ipairs({ "clangd", "pyright", "slangd", "shader_language_server" }) do
    assert(lsp.servers[server], "Language server config missing: " .. server)
  end
  print("PASS: commands, adapters, filetypes, language config and parser loading.")
end
local ok, err = xpcall(run, debug.traceback)
if ok then
  vim.cmd("qa!")
else
  vim.api.nvim_err_writeln(err)
  vim.cmd("cquit 1")
end
