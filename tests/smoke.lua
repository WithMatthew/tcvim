local repo = assert(vim.env.NVIM_SETUP_REPO)
local work = vim.fs.normalize(assert(vim.env.NVIM_TEST_WORK))
for _, directory in ipairs({ "/config/nvim", "/scripts", "/tests" }) do
  for _, file in ipairs(vim.fn.glob(repo .. directory .. "/**/*.lua", false, true)) do
    assert(loadfile(file), "Invalid Lua: " .. file)
  end
end
vim.opt.rtp:prepend(repo .. "/config/nvim")
local portable = require("config.portable")
portable._settings = {
  msysRoot = "D:/Custom Msys",
  toolsRoot = work .. "/tools with spaces",
  python = vim.fn.exepath("python"),
}
assert(portable.msys("clang.exe"):find("Custom Msys/clang64/bin/clang.exe", 1, true))
assert(portable.tools("bin"):find("tools with spaces/bin", 1, true))
local original = portable.python(work)
assert(original == portable._settings.python)
local venv = work .. "/.venv/Scripts/python.exe"
vim.fn.mkdir(vim.fs.dirname(venv), "p")
vim.fn.writefile({}, venv)
assert(portable.python(work) == venv, "project .venv must override the system Python")
dofile(repo .. "/config/nvim/lua/config/options.lua")
assert(vim.o.number and not vim.o.relativenumber)
for extension, ft in pairs({ hlsl="hlsl", hlsli="hlsl", slang="shaderslang", vert="glsl", frag="glsl", comp="glsl" }) do
  assert(vim.filetype.match({ filename="demo." .. extension }) == ft)
end
local languages = dofile(repo .. "/config/nvim/lua/plugins/languages.lua")
local python_config = { root_dir = work }
languages[1].opts.servers.pyright.before_init({}, python_config)
assert(python_config.settings.python.pythonPath == venv)
local dap = { adapters = { python = function() end } }
package.loaded.dap = dap
package.loaded["dap-python"] = { setup = function() end }
local debugging = dofile(repo .. "/config/nvim/lua/plugins/debugging.lua")
debugging[2].opts()
debugging[4].config()
assert(dap.adapters.codelldb.executable.command:find("codelldb.exe", 1, true))
local adapter
dap.adapters.python(function(value) adapter = value end, { request = "launch" })
assert(adapter.type == "server" and adapter.executable.args[2] == "debugpy.adapter")
assert(dap.adapters.debugpy == dap.adapters.python)
print("PASS: Lua syntax, custom paths, virtualenv precedence, shader filetypes and Windows DAP adapters")
