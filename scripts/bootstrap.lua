local function run()
  local repo = assert(vim.env.NVIM_SETUP_REPO, "NVIM_SETUP_REPO is missing")
  local function json(path)
    return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
  end
  local manifest = json(repo .. "/dependencies.json")
  local expected = json(repo .. "/config/nvim/lazy-lock.json")
  if vim.env.NVIM_BOOTSTRAP_STAGE == "plugins" then
    -- Startup installs missing plugins using lockfile=true; restore handles existing plugins.
    vim.fn.writefile(vim.fn.readfile(repo .. "/config/nvim/lazy-lock.json"), vim.fn.stdpath("config") .. "/lazy-lock.json")
    require("lazy.manage.lock")._loaded = false
    require("lazy").restore({ wait = true, show = false })
    local config = require("lazy.core.config")
    for name, plugin in pairs(config.plugins) do
      assert(plugin._.installed, "Plugin missing: " .. name)
      assert(not require("lazy.core.plugin").has_errors(plugin), "Plugin install failed: " .. name)
    end
    for name, lock in pairs(expected) do
      local path = config.options.root .. "/" .. name
      -- Disabled plugins may remain in the historical lockfile.
      if config.plugins[name] then
        local commit = vim.fn.system({ "git", "-C", path, "rev-parse", "HEAD" }):gsub("%s+$", "")
        assert(commit == lock.commit, "Plugin revision mismatch: " .. name .. " (" .. commit .. ")")
      end
    end
    -- Keep the original lockfile, including previously disabled plugins.
    vim.fn.writefile(vim.fn.readfile(repo .. "/config/nvim/lazy-lock.json"), vim.fn.stdpath("config") .. "/lazy-lock.json")
    print("Plugin revisions verified.")
    return
  end

  require("lazy").load({ plugins = { "mason.nvim", "nvim-treesitter" } })
  local registry = require("mason-registry")
  local refreshed, refresh_ok = false, false
  registry.refresh(function(ok)
    refresh_ok, refreshed = ok, true
  end)
  assert(vim.wait(120000, function() return refreshed end, 100), "Mason registry refresh timed out")
  assert(refresh_ok, "Mason registry refresh failed; see :MasonLog")
  local names = vim.tbl_keys(manifest.mason)
  table.sort(names)
  for _, name in ipairs(names) do
    local version = manifest.mason[name]
    local package = registry.get_package(name)
    local receipt_path = vim.fn.stdpath("data") .. "/mason/packages/" .. name .. "/mason-receipt.json"
    local installed_version
    if vim.fn.filereadable(receipt_path) == 1 then
      installed_version = (json(receipt_path).source.id:match("@([^?]+)"))
    end
    if not package:is_installed() or installed_version ~= version then
      print("Installing " .. name .. "@" .. version)
      local done, success, failure = false, false, nil
      package:install({ version = version }, function(ok, err)
        success, failure, done = ok, err, true
      end)
      assert(vim.wait(900000, function() return done end, 100), "Mason timed out: " .. name)
      assert(success, "Mason failed: " .. name .. " " .. vim.inspect(failure))
    end
    assert(package:is_installed(), "Mason package missing: " .. name)
  end

  local plugin = require("lazy.core.config").plugins["nvim-treesitter"]
  local opts = require("lazy.core.plugin").values(plugin, "opts", false)
  local parsers = opts.ensure_installed or {}
  local ts = require("nvim-treesitter")
  ts.install(parsers, { summary = true }):wait(900000)
  local installed = ts.get_installed("parsers")
  for _, lang in ipairs(parsers) do
    assert(vim.tbl_contains(installed, lang), "Parser missing: " .. lang)
    assert(pcall(vim.treesitter.language.add, lang), "Parser cannot load: " .. lang)
  end
  print("Mason tools and " .. #parsers .. " parsers verified.")
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
