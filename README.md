# Neovim / LazyVim Windows 开发环境

把当前使用的 LazyVim 配置、语言工具、Windows 适配和安装流程放在同一个仓库。支持 C/C++、CMake、Python、HLSL/Slang、GLSL，保留自动补全、保存格式化、绝对行号、文件搜索、Git 面板和 C++/Python 断点调试。未启用 Copilot。

## 新电脑一键部署

适用 **Windows 10/11 x64**（Windows 10 至少 build 19041），使用当前登录用户运行。需要联网、WinGet（微软“应用安装程序”），安装系统依赖时可能出现 UAC 授权。首次需要下载 MSYS2、LLVM、插件及语言工具，请预留数 GB 空间。ARM64、32 位 Windows 和离线首次安装不在支持范围内。

1. 克隆仓库，或者下载 ZIP 并**先解压**到可写目录。
2. **双击 `install.cmd`**。也可以在 PowerShell 中执行：

   ```powershell
   .\install.cmd
   ```

3. 完成后完全关闭并重新打开终端，执行 `nvim`。

默认会安装或复用 Git、Node.js、原生 Python、VC++ Runtime、MSYS2 CLANG64、Neovim、Clang/clangd/clang-format、CMake/Ninja、搜索工具、lazygit、Tree-sitter CLI、Shader Language Server、Mason 语言服务与调试器、FiraCode Nerd Font Mono。随后恢复插件锁文件、等待语言工具和语法解析器安装完成，再运行检查；失败会返回非零退出码。

已有 VS C++ 工具通过 `vswhere` 自动检测。**要在没有 Visual Studio 的机器上开发 MSVC / Windows SDK / DirectX 项目**，运行：

```powershell
.\install.cmd -WithMSVC
```

该选项安装 VS 2022 Build Tools 的 C++ 工作负载及推荐组件，下载较大；若安装器要求重启，请重启后重跑同一命令。默认 CLANG64 能提供一般 C/C++ 编译与语法解析，不包含 Windows SDK。

## 常用命令

```powershell
# 只展示计划，不下载、不写配置
.\install.cmd -DryRun

# MSYS2 已安装在其他位置
.\install.cmd -MsysRoot D:\tools\msys64

# 保留终端字体与 shell 配置
.\install.cmd -SkipTerminalConfig

# 不安装字体
.\install.cmd -SkipFont

# 仅在已确认 MSYS2 完整更新后，跳过两轮全量更新
.\install.cmd -SkipMsysUpdate

# 只复制配置（已有完整依赖时使用，不生成机器路径、不修改 PATH）
.\install.cmd -ConfigOnly

# 部署后检查
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Doctor.ps1
```

`-ToolsRoot`、`-BinDir` 可定制工具和启动器目录，支持空格；MSYS2 路径须为不含空格的 ASCII 本地路径。`-ConfigDir` 仅用于 `-ConfigOnly`。完整部署使用标准 `%LOCALAPPDATA%\nvim`；若设置了 `NVIM_APPNAME` 或 XDG 路径变量，脚本会提示先清除，避免安装到错误位置。

完整安装时请先关闭 Neovim 和 MSYS2 终端。不建议用另一个管理员账户运行，否则用户级配置会装进另一个账户。通过当前用户启动，让 WinGet 在需要时自行请求 UAC。

## 配置放在哪里

| 内容 | 默认路径 |
| --- | --- |
| 配置 | `%LOCALAPPDATA%\nvim` |
| 插件、Mason 工具、解析器 | `%LOCALAPPDATA%\nvim-data` |
| 编辑器辅助工具 | `%LOCALAPPDATA%\nvim-tools` |
| PowerShell / CMD / Git Bash 启动器 | `%USERPROFILE%\.local\bin\nvim.cmd` 和 `nvim` |
| 编译工具链和 Neovim | `C:\msys64\clang64\bin` |
| 本机自动检测结果 | `%LOCALAPPDATA%\nvim\lazyvim.local.json` |
| 安装日志 / 下载缓存 | 仓库 `logs\` / `.cache\` |

仅把启动器目录加入用户 PATH；MSYS2 的工具和 Python/Node 路径在 Neovim 进程内设置，避免把整套 Unix 命令暴露到全局。Git Bash 的 `.bash_profile` 会加入带标记的 PATH 段；已有 Windows Terminal 设置和 `.minttyrc` 会备份后切换字体，其他设置值保留。Windows Terminal 的 JSONC 注释会在重写时移除，原文件保留在备份中。尚未运行过 Windows Terminal 的机器，首次启动后需在终端设置中选择 **FiraCode Nerd Font Mono**。

`lua/config/local.lua` 用于仅当前机器的 Lua 覆盖；`lazyvim.local.json` 由安装脚本生成。两者不会导出到 Git。环境变量 `MSYS2_ROOT`、`NVIM_TOOLS_ROOT`、`NVIM_PYTHON` 可临时覆盖自动检测结果。

## 重复部署和回退

重复运行安装命令即可。工具版本相同且文件校验匹配时会复用；配置每次先复制到 staging 目录，再将现有配置重命名为 `nvim.backup-日期-标识`，最后切换新配置。旧配置不删除，本机 Lua 覆盖会保留。配置目录是符号链接或 junction 时会停止，避免修改其他位置。

回退配置：关闭 Neovim，把当前 `%LOCALAPPDATA%\nvim` 改名留存，再把需要的 `nvim.backup-...` 改名为 `nvim`。字体和终端配置也有旁边的 `.backup-...` 原件。插件缓存、语言工具和通过包管理器安装的软件**不在配置备份中**；需要回到旧插件版本时，对旧配置运行 `:Lazy restore`。

## 把日常修改带回仓库

**先部署本仓库，再使用导出脚本**；不要用旧的、尚未移除硬编码路径的配置覆盖本仓库。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Export-Config.ps1
git diff
git add config/nvim
git commit -m "Update Neovim configuration"
git push
```

导出只包含配置文件和 Lua 源码，排除机器路径文件、缓存、会话、日志和 `lua/config/local.lua`；原仓库配置备份在 `.cache\export-...\`。新增自定义 Lua 中若写了绝对路径，仍需自行改成自动检测或放进本机覆盖文件。

本仓库已是本地 Git 仓库；远程地址由你选择。例如先在 GitHub 创建空仓库，再执行：

```powershell
git remote add origin <你的仓库地址>
git push -u origin main
```

## 版本如何固化

- `config/nvim/lazy-lock.json` 保存当前插件 commit；部署使用 restore，不执行更新到最新版的 sync。
- `dependencies.json` 固定辅助工具、Tree-sitter CLI 和 Mason 工具版本，来源是现有环境的版本记录。
- WinGet 系统依赖和 MSYS2 包使用可用的稳定发行版；MSYS2 是滚动发行，执行完整更新，因此**不是所有二进制都逐字节锁定**。
- 下载使用上游 HTTPS；GitHub API 提供 SHA256 digest 时校验，不提供时会明确输出提示。安装包校验由 WinGet / pacman 处理。
- 升级插件可使用 `:Lazy update`，验证后导出新的锁文件；升级工具则修改清单。首次安装依赖上游仓库中对应版本仍可下载。

## 检查与排障

```powershell
# 无网络、无注册表写入的脚本测试
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Test.ps1

# 附加 Lua 配置、路径选择和 DAP 适配测试
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Test.ps1 -Nvim C:\msys64\clang64\bin\nvim.exe
```

- 先读 `logs\install-*.log`；下载失败后可修复网络并重跑。GitHub、npm、PyPI、MSYS2 镜像均需可访问。代理使用现有系统/Git/npm 设置，本仓库不固化代理地址。
- 找不到 WinGet：安装或更新微软 [应用安装程序](https://learn.microsoft.com/windows/package-manager/winget/)，重新打开终端。
- Mason 错误：查看 `:MasonLog`；Tree-sitter 错误：查看 `:TSLog`，确认 `:echo $CC` 指向本仓库生成的编译器适配器。
- 图标方框：彻底重启终端，确认字体为 FiraCode Nerd Font Mono。
- 启动了另一版 Neovim：运行 `where.exe nvim`；检查旧系统 PATH、PowerShell alias 和 Git Bash alias 是否覆盖了用户启动器。
- C++ 头文件/宏识别错误：项目需要正确的 `compile_commands.json`、`.clangd` 和对应 SDK；参见 [项目说明](docs/project-setup.md)。
- GitHub API 限流：稍后重试，或在当前进程提供 `GITHUB_TOKEN`；脚本不会把它写入配置或日志。
- 官方最低要求和依赖说明见 [LazyVim](https://www.lazyvim.org/)；此仓库的现有插件快照要求 Neovim **0.12+**，以清单中的检查为准。

此次验证结果及边界见 [验证记录](docs/validation.md)。快捷键图见 [3440×1440 速查图](docs/keymaps-3440x1440.png)。
