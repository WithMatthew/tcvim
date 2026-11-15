return {
  {
    "jay-babu/mason-nvim-dap.nvim",
    -- Language extras configure the adapters; Mason manages their installations.
    enabled = false,
  },
  {
    "mfussenegger/nvim-dap",
    opts = function()
      -- Use the executable directly: libuv cannot spawn Mason's .cmd shim.
      require("dap").adapters.codelldb = {
        type = "server",
        host = "127.0.0.1",
        port = "${port}",
        executable = {
          command = vim.fs.joinpath(
            vim.fn.stdpath("data"),
            "mason",
            "packages",
            "codelldb",
            "extension",
            "adapter",
            "codelldb.exe"
          ),
          args = { "--port", "${port}" },
        },
      }
    end,
  },
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      if not vim.tbl_contains(opts.ensure_installed, "debugpy") then
        table.insert(opts.ensure_installed, "debugpy")
      end
    end,
  },
  {
    "mfussenegger/nvim-dap-python",
    opts = {},
    config = function()
      local python_dap = require("dap-python")
      python_dap.setup(
        vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "packages", "debugpy", "venv", "Scripts", "python.exe")
      )
      -- A TCP adapter avoids Windows treating stdio shutdown as a failed Python process.
      local dap = require("dap")
      local default_adapter = dap.adapters.python
      dap.adapters.python = function(callback, config)
        if config.request == "attach" then
          return default_adapter(callback, config)
        end
        callback({
          type = "server",
          host = "127.0.0.1",
          port = "${port}",
          executable = {
            command = vim.fs.joinpath(
              vim.fn.stdpath("data"),
              "mason",
              "packages",
              "debugpy",
              "venv",
              "Scripts",
              "python.exe"
            ),
            args = { "-m", "debugpy.adapter", "--host", "127.0.0.1", "--port", "${port}" },
          },
        })
      end
      dap.adapters.debugpy = dap.adapters.python
      python_dap.resolve_python = function()
        for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0, name = "pyright" })) do
          local python = client.settings.python and client.settings.python.pythonPath
          if python and vim.fn.executable(python) == 1 then
            return python
          end
        end
        local root = LazyVim.root.get()
        return require("config.portable").python(root)
      end
    end,
  },
}
