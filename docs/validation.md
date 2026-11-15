# 验证记录

验证日期：2026-11-15。来源环境为 Windows x64、Neovim 0.12.4、MSYS2 CLANG64。

## 已执行

- Windows PowerShell 5.1 语法检查和公开 `-DryRun` / `-ConfigOnly` 入口。
- 旧配置完整备份、重复部署、本机覆盖保留、旧文件清除、锁文件原样复制、重叠目录和越界路径拒绝。
- MSYS2 自定义路径、含空格的 VS 路径、Git Bash 参数转发，以及无 MSVC 时的启动器生成。
- 原生 Python 解释器探测、外部命令错误码传递。
- 下载逻辑使用本地 ZIP 模拟网络：下载复用、SHA256 错误拒绝、失败不覆盖已安装程序。
- Node.js 测试：JSONC 注释/尾逗号解析、保留 URL/字符串转义、终端配置备份、重复执行、保留原有配置项。
- Neovim 无插件测试：所有 Lua 文件语法、自定义工具路径、项目虚拟环境优先级、着色器文件类型、Windows DAP 配置。
- **隔离启动检查**：将现有插件、Mason 工具、解析器和辅助程序复制到仓库 `.test-work\`，设置独立配置/数据/缓存目录，然后实际启动 Neovim。命令查找、解析器加载、语言配置、补全/格式化插件加载和调试适配器检查通过。源配置与源插件数据没有被替换。
- GitHub 连接器只读核验 fd、ripgrep、lazygit、Shader Language Server 和 Nerd Fonts 的 release 资产名；辅助程序 SHA256 来自对应 release 元数据。

## 尚未完成的外部验收

当前执行环境不能直接连接下载服务器，也没有空白 Windows 虚拟机，因此**未执行全新机器上的完整联网安装**，未实际安装/升级 WinGet 系统依赖、MSYS2 或 VS Build Tools。

已测试的是安装逻辑、配置和已有依赖下的真实加载，不代表全新安装的下载、UAC、系统重启、镜像可用性或所有 Windows 终端版本均已实机验收。后续在新电脑运行 `install.cmd` 后，脚本本身会等待插件、Mason 与解析器完成并执行 `health.lua`；失败会返回错误，日志可用于定位。

真实项目的补全准确性、编译选项和端到端断点行为仍需使用项目自己的编译数据库/虚拟环境验收。

## 重现隔离检查

已有完整安装时：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Integration.ps1 -ExistingData "$env:LOCALAPPDATA\nvim-data" -ExistingTools "$env:LOCALAPPDATA\nvim-tools" -MsysRoot C:\msys64
```

它复制已有依赖后测试，可能占用约 1 GB 临时空间。所有结果位于 `.test-work\`，不提交到 Git。

???????????????????? `nvim-validation-artifacts` ???Git ?????????????
