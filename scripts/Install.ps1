#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$MsysRoot = 'C:\msys64',
    [string]$ToolsRoot = (Join-Path $env:LOCALAPPDATA 'nvim-tools'),
    [string]$ConfigDir = (Join-Path $env:LOCALAPPDATA 'nvim'),
    [string]$BinDir = (Join-Path $env:USERPROFILE '.local\bin'),
    [switch]$WithMSVC,
    [switch]$SkipMsysUpdate,
    [switch]$SkipFont,
    [switch]$SkipTerminalConfig,
    [switch]$ConfigOnly,
    [switch]$DryRun
)
. (Join-Path $PSScriptRoot 'Common.ps1')
$repo = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content -Raw -LiteralPath (Join-Path $repo 'dependencies.json') | ConvertFrom-Json
$source = Join-Path $repo 'config\nvim'
$ConfigDir = [IO.Path]::GetFullPath($ConfigDir)
$ToolsRoot = [IO.Path]::GetFullPath($ToolsRoot)
$MsysRoot = [IO.Path]::GetFullPath($MsysRoot).TrimEnd('\')
$BinDir = [IO.Path]::GetFullPath($BinDir)
if ($DryRun) {
    Write-Host "Config: $source -> $ConfigDir (existing config gets a timestamped backup)"
    Write-Host "Tools: $ToolsRoot | MSYS2: $MsysRoot | Launchers: $BinDir"
    Write-Host "ConfigOnly=$ConfigOnly WithMSVC=$WithMSVC SkipMsysUpdate=$SkipMsysUpdate"
    Write-Host ('WinGet IDs: ' + ($manifest.winget.PSObject.Properties.Value -join ', '))
    Write-Host ('MSYS2 packages: ' + ($manifest.msys2Packages -join ', '))
    Write-Host 'Full install: dependencies, font, config, launchers, locked plugins, Mason, parsers, health check.'
    return
}
$transcript = $false
try {
    if ($ConfigOnly) {
        $backup = Install-Config $source $ConfigDir
        Write-Host "Config deployed to $ConfigDir"
        Write-Host 'Dependencies, runtime paths, PATH and terminal settings were not configured.'
        return
    }
    $architecture = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
    if ($architecture -ne 'AMD64' -or ![Environment]::Is64BitProcess) {
        throw 'Use 64-bit Windows PowerShell on Windows x64. ARM64 and 32-bit Windows are not supported by this manifest.'
    }
    if ([Environment]::OSVersion.Version.Build -lt 19041) { throw 'Windows 10 build 19041 or later is required.' }
    if ($MsysRoot -notmatch '^[A-Za-z]:\\[A-Za-z0-9_\\-]+$') { throw 'MSYS2 needs a short ASCII path without spaces, such as C:\msys64 or D:\tools\msys64.' }
    foreach ($path in @($ConfigDir,$ToolsRoot,$BinDir)) {
        if ($path -match '["%!\r\n]') { throw "Unsupported characters in path: $path" }
    }
    if ($ConfigDir -ne [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'nvim'))) {
        throw 'A custom ConfigDir is supported only with -ConfigOnly; full install uses LOCALAPPDATA\nvim.'
    }
    foreach ($name in @('NVIM_APPNAME','XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_STATE_HOME','XDG_CACHE_HOME')) {
        if ([Environment]::GetEnvironmentVariable($name)) { throw "Unset $name before full deployment so the installed config and Neovim use the same paths." }
    }
    if (Get-Process -Name nvim -ErrorAction SilentlyContinue) { throw 'Close running Neovim processes before deploying.' }
    $null = Assert-ChildPath $ToolsRoot (Split-Path -Parent $ToolsRoot)
    $null = Assert-ChildPath $BinDir (Split-Path -Parent $BinDir)
    New-Item -ItemType Directory -Path (Join-Path $repo 'logs'),$ToolsRoot -Force | Out-Null
    Start-Transcript -Path (Join-Path $repo ('logs\install-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')) | Out-Null
    $transcript = $true
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = 'SilentlyContinue'

    Write-Host '[1/7] Runtime dependencies'
    if (!(Find-Application 'git.exe')) { Install-WingetPackage $manifest.winget.git }
    $node = Find-Application 'node.exe'
    if (!$node -or [int]((& $node -p "process.versions.node.split('.')[0]") | Select-Object -First 1) -lt 20) {
        Install-WingetPackage $manifest.winget.node -Upgrade
    }
    $python = Find-NativePython
    if (!$python) {
        Install-WingetPackage $manifest.winget.python @('--scope','user')
        $python = Find-NativePython
    }
    if (!$python) { throw 'Native Python >=3.10 with pip was not found after installation.' }
    $node = Find-Application 'node.exe'
    $git = Find-Application 'git.exe'
    if (!$node -or !$git) { throw 'Git/Node are missing from PATH after installation. Open a new terminal and rerun.' }
    Install-WingetPackage $manifest.winget.vcRuntime
    $vcvars = Get-VcVars
    if ($WithMSVC -and !$vcvars) {
        Install-WingetPackage $manifest.winget.buildTools @('--override','--wait --passive --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended')
        $vcvars = Get-VcVars
        if (!$vcvars) { throw 'MSVC was not detected. Reboot if requested by Visual Studio, then rerun with -WithMSVC.' }
    }
    if (!$vcvars) { Write-Host 'MSVC not installed: using the CLANG64 toolchain. Use -WithMSVC for Windows SDK/MSVC projects.' }

    Write-Host '[2/7] MSYS2 CLANG64 toolchain'
    $bash = Join-Path $MsysRoot 'usr\bin\bash.exe'
    if (!(Test-Path -LiteralPath $bash)) {
        Install-WingetPackage $manifest.winget.msys2 @('--location',$MsysRoot)
    }
    if (!(Test-Path -LiteralPath $bash)) { throw "MSYS2 not found at $MsysRoot. Rerun with -MsysRoot pointing to its actual location." }
    $env:MSYSTEM = 'CLANG64'
    $env:CHERE_INVOKING = '1'
    if (!$SkipMsysUpdate) {
        # A core runtime update can terminate the first login shell; the second must succeed.
        Invoke-Checked $bash @('-lc','pacman --noconfirm -Syu') @(0,1)
        Invoke-Checked $bash @('-lc','pacman --noconfirm -Syu')
    }
    Invoke-Checked $bash @('-lc',('pacman --noconfirm -S --needed ' + ($manifest.msys2Packages -join ' ')))
    $nvim = Join-Path $MsysRoot 'clang64\bin\nvim.exe'
    $versionText = (& $nvim --version | Select-Object -First 1)
    if ($versionText -notmatch 'v(\d+\.\d+\.\d+)' -or [version]$Matches[1] -lt [version]$manifest.minimumNeovim) {
        throw "This plugin lockfile needs Neovim >=$($manifest.minimumNeovim). Installed: $versionText"
    }

    Write-Host '[3/7] Search, Git, shader tools and font'
    foreach ($spec in $manifest.archives) {
        if ($SkipFont -and $spec.name -eq 'font') { continue }
        $file = Install-GitHubArchive $spec $ToolsRoot (Join-Path $repo '.cache')
        if ($spec.name -eq 'font') { Install-Font $file }
    }
    $npm = Join-Path (Split-Path -Parent $node) 'npm.cmd'
    if (!(Test-Path -LiteralPath $npm)) { $npm = Find-Application 'npm.cmd' }
    if (!$npm) { throw 'npm.cmd was not found.' }
    Invoke-Checked $npm @('install','--global','--prefix',(Join-Path $ToolsRoot 'npm'),('tree-sitter-cli@' + $manifest.treeSitterCli))
    Write-Launchers $MsysRoot $ToolsRoot $BinDir $vcvars

    Write-Host '[4/7] Configuration and shell integration'
    $backup = Install-Config $source $ConfigDir
    $settings = @{
        msysRoot=$MsysRoot; toolsRoot=$ToolsRoot; python=$python; node=$node; git=$git
    }
    Write-Utf8 (Join-Path $ConfigDir 'lazyvim.local.json') ($settings | ConvertTo-Json)
    Add-UserPath $BinDir
    $env:Path = (Join-Path $ToolsRoot 'bin') + ';' + (Join-Path $ToolsRoot 'npm') + ';' + (Split-Path -Parent $python) + ';' + (Split-Path -Parent $node) + ';' + (Join-Path $MsysRoot 'clang64\bin') + ';' + $env:Path
    if (!$SkipTerminalConfig) {
        $terminalArgs = @((Join-Path $PSScriptRoot 'Configure-Terminals.cjs'),$BinDir)
        if ($SkipFont) { $terminalArgs += '--skip-font' }
        Invoke-Checked $node $terminalArgs
    }

    Write-Host '[5/7] Restore the plugin lockfile'
    $env:NVIM_BOOTSTRAP = '1'
    $env:NVIM_SETUP_REPO = $repo
    $env:NVIM_BOOTSTRAP_STAGE = 'plugins'
    $env:NVIM_BOOTSTRAP_SCRIPT = Join-Path $PSScriptRoot 'bootstrap.lua'
    Invoke-Checked $nvim @('--headless','-i','NONE','-c','lua dofile(vim.env.NVIM_BOOTSTRAP_SCRIPT)')

    Write-Host '[6/7] Install pinned language tools and syntax parsers'
    $env:NVIM_BOOTSTRAP_STAGE = 'tools'
    Invoke-Checked $nvim @('--headless','-i','NONE','-c','lua dofile(vim.env.NVIM_BOOTSTRAP_SCRIPT)')

    Write-Host '[7/7] Verify'
    $env:NVIM_BOOTSTRAP_SCRIPT = Join-Path $PSScriptRoot 'health.lua'
    Invoke-Checked $nvim @('--headless','-i','NONE','-c','lua dofile(vim.env.NVIM_BOOTSTRAP_SCRIPT)')
    Write-Host ''
    Write-Host 'Installation complete. Restart Windows Terminal/Git Bash/PowerShell, then run nvim.'
    Write-Host "Config: $ConfigDir"
    if ($backup) { Write-Host "Previous config: $backup" }
} catch {
    Write-Host ('ERROR: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host 'Fix the reported issue and rerun the same command. Download/install logs are in logs/.'
    exit 1
} finally {
    if ($transcript) { Stop-Transcript | Out-Null }
    foreach ($name in @('NVIM_BOOTSTRAP','NVIM_SETUP_REPO','NVIM_BOOTSTRAP_STAGE','NVIM_BOOTSTRAP_SCRIPT')) {
        [Environment]::SetEnvironmentVariable($name,$null,'Process')
    }
}
