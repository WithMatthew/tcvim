local portable = require("config.portable")

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        clangd = {
          mason = false,
          root_markers = {
            ".clangd",
            "compile_commands.json",
            "compile_flags.txt",
            "CMakePresets.json",
            "CMakeLists.txt",
            ".git",
          },
          cmd = {
            "clangd-msvc.cmd",
            "--log=error",
            "--background-index",
            "--clang-tidy",
            "--header-insertion=iwyu",
            "--completion-style=detailed",
            "--function-arg-placeholders",
            "--fallback-style=Google",
            -- Allow clangd to discover the installed MinGW toolchain when a project uses it.
            "--query-driver=" .. portable.msys("clang.exe") .. "," .. portable.msys("clang++.exe"),
          },
        },
        pyright = {
          before_init = function(_, config)
            local root = config.root_dir or vim.uv.cwd()
            config.settings = config.settings or {}
            config.settings.python = config.settings.python or {}
            config.settings.python.pythonPath = portable.python(root)
          end,
          settings = {
            pyright = { disableOrganizeImports = true },
            python = {
              analysis = {
                autoImportCompletions = true,
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
                diagnosticMode = "openFilesOnly",
                typeCheckingMode = "basic",
              },
            },
          },
        },
        slangd = {
          filetypes = { "hlsl", "shaderslang" },
          root_markers = { "slangdconfig.json", "CMakePresets.json", "CMakeLists.txt", ".git" },
          settings = {
            slang = {
              inlayHints = { deducedTypes = true, parameterNames = true },
            },
          },
        },
        glsl_analyzer = {
          enabled = false,
        },
        shader_language_server = {
          mason = false,
          cmd = {
            portable.tools("shader-language-server", "shader-language-server.exe"),
            "--stdio",
            "--glsl",
            "--config",
            vim.json.encode({ glsl = { targetClient = "None", spirvVersion = "None" } }),
          },
          filetypes = { "glsl" },
          root_markers = { "CMakePresets.json", "CMakeLists.txt", ".git" },
        },
      },
    },
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        c = { "clang-format" },
        cpp = { "clang-format" },
        hlsl = { "clang-format" },
        shaderslang = { "clang-format" },
        glsl = { "clang-format" },
        python = { "ruff_format" },
        cmake = { "cmake_format" },
      },
      formatters = {
        ["clang-format"] = {
          command = portable.msys("clang-format.exe"),
          prepend_args = { "--style=file", "--fallback-style=Google" },
        },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "hlsl", "glsl" } },
  },
  {
    "saghen/blink.cmp",
    opts = {
      signature = { enabled = true },
      completion = {
        documentation = { auto_show = true, auto_show_delay_ms = 250 },
      },
    },
  },
}
