# 项目设置

全局安装负责编辑器和工具，工程自身的编译参数和运行配置仍放在项目仓库。

## C/C++、CMake

clangd 使用项目的 `compile_commands.json`。CMake + Ninja 可在项目根目录执行：

```powershell
cmake -S . -B build -G Ninja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build build
```

将以下内容放进项目 `.clangd`，使 clangd 找到构建目录：

```yaml
CompileFlags:
  CompilationDatabase: build
```

MSVC 项目应在 VS Developer PowerShell/Command Prompt 中生成编译数据库。本仓库的 clangd 启动器会在检测到 VS 时调用对应 `vcvars64.bat`，帮助找到标准库和 Windows SDK，但不会替项目猜测所有宏和 include 路径。

默认安装把 CMake/Ninja/Clang 暴露给 Neovim 内部终端；外部终端如果没有这些命令，可使用 MSYS2 CLANG64 终端或可执行文件完整路径。此仓库不改动全局 MSYS2 PATH。

C++ 调试使用 CodeLLDB。一般 MinGW/Clang 调试建议使用 Debug 构建和 DWARF 调试信息；MSVC PDB 的能力取决于 LLDB 和项目，不能据此保证所有 Visual Studio 工程的调试行为。

## Python

优先级为项目 `.venv` → 项目 `venv` → `VIRTUAL_ENV` → 部署时检测到的原生 Python。Pyright 与 DAP 尽量使用同一解释器。

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

依赖属于项目虚拟环境，debugpy 安装在 Mason 自己的虚拟环境。切换项目解释器后可重启 LSP。

## HLSL / Slang / GLSL

- HLSL/Slang 使用 slangd，按项目设置 include、宏和目标；`slangdconfig.json` 放进项目仓库。
- GLSL 使用 Shader Language Server，启用 GLSL 校验，保留 DXC DLL 等上游随包依赖。
- 着色器编译错误是否能被完整检查，仍取决于项目入口、stage、宏和 include。真实编译以项目 DXC/glslang 命令为准。

## 常用入口

`Space` 是 leader，完整键位参考附带速查图以及 Neovim 的 which-key 提示。

| 按键 | 用途 |
| --- | --- |
| `Space ff` / `Space sg` | 找文件 / 项目搜索 |
| `gd` / `gr` / `K` | 定义 / 引用 / 悬浮说明 |
| `Space cr` / `Space ca` | 重命名 / 代码动作 |
| `Space cf` | 格式化（同时保留保存自动格式化） |
| `Space db` / `Space dc` | 断点 / 开始或继续调试 |
| `Space di` / `Space dO` / `Space do` | 步入 / 步过 / 步出 |
| `Space du` | 调试界面 |
| `Space gg` | lazygit |
