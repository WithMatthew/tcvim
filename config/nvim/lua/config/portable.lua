local M = {}

function M.settings()
  if M._settings then
    return M._settings
  end
  local path = vim.fs.joinpath(vim.fn.stdpath("config"), "lazyvim.local.json")
  M._settings = vim.fn.filereadable(path) == 1 and vim.json.decode(table.concat(vim.fn.readfile(path), "\n")) or {}
  return M._settings
end

function M.tools(...)
  return vim.fs.joinpath(vim.env.NVIM_TOOLS_ROOT or M.settings().toolsRoot or (vim.env.LOCALAPPDATA .. "/nvim-tools"), ...)
end

function M.msys(...)
  return vim.fs.joinpath(vim.env.MSYS2_ROOT or M.settings().msysRoot or "C:/msys64", "clang64", "bin", ...)
end

function M.python(root)
  local candidates = {
    vim.fs.joinpath(root, ".venv", "Scripts", "python.exe"),
    vim.fs.joinpath(root, "venv", "Scripts", "python.exe"),
    vim.env.VIRTUAL_ENV and vim.fs.joinpath(vim.env.VIRTUAL_ENV, "Scripts", "python.exe") or "",
    vim.env.NVIM_PYTHON or M.settings().python or "",
    "python",
  }
  for _, path in ipairs(candidates) do
    if path ~= "" and vim.fn.executable(path) == 1 then
      return path
    end
  end
  return "python"
end

function M.setup()
  if vim.fn.has("win32") == 0 then
    return
  end
  local paths = { M.tools("npm"), M.msys() }
  -- Native runtimes must come before MSYS2's Python in the editor process.
  for _, name in ipairs({ "python", "node", "git" }) do
    local executable = M.settings()[name]
    if executable then
      table.insert(paths, 1, vim.fs.dirname(executable))
    end
  end
  table.insert(paths, 1, M.tools("bin"))
  vim.env.PATH = table.concat(paths, ";") .. ";" .. (vim.env.PATH or "")
  local compiler = M.tools("treesitter", "clang.cmd")
  if vim.fn.executable(compiler) == 1 then
    vim.env.CC = compiler
  end
end

return M
