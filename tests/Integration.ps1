#Requires -Version 5.1
param(
    [Parameter(Mandatory=$true)][string]$ExistingData,
    [Parameter(Mandatory=$true)][string]$ExistingTools,
    [string]$MsysRoot = 'C:\msys64'
)
# Reuse downloaded tools in a COPY. Never point the tested editor at live user data.
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts\Common.ps1')
$repo = Split-Path -Parent $PSScriptRoot
$work = Join-Path $repo ('.test-work\integration-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null
$python = Find-NativePython
$node = Find-Application 'node.exe'
$git = Find-Application 'git.exe'
foreach ($directory in @('lazy','mason','site')) {
    Invoke-Checked 'robocopy.exe' @((Join-Path $ExistingData $directory),(Join-Path $work ('nvim-data\' + $directory)),'/E','/XD','.git','/NFL','/NDL','/NJH','/NJS','/NP','/R:0','/W:0') @(0,1,2,3,4,5,6,7)
}
$tools = Join-Path $work 'nvim-tools'
Invoke-Checked 'robocopy.exe' @($ExistingTools,$tools,'/E','/NFL','/NDL','/NJH','/NJS','/NP','/R:0','/W:0') @(0,1,2,3,4,5,6,7)
$null = Install-Config (Join-Path $repo 'config\nvim') (Join-Path $work 'nvim')
Write-Utf8 (Join-Path $work 'nvim\lazyvim.local.json') (@{
    msysRoot=$MsysRoot; toolsRoot=$tools; python=$python; node=$node; git=$git
} | ConvertTo-Json)
Write-Launchers $MsysRoot $tools (Join-Path $work 'bin with spaces') (Get-VcVars)
$env:LOCALAPPDATA = $work
$env:XDG_CACHE_HOME = Join-Path $work 'cache'
$env:NVIM_APPNAME = $null
$env:XDG_CONFIG_HOME = $null
$env:XDG_DATA_HOME = $null
$env:XDG_STATE_HOME = $null
$env:NVIM_BOOTSTRAP = '1'
$env:NVIM_BOOTSTRAP_STAGE = 'check'
$env:NVIM_BOOTSTRAP_SCRIPT = Join-Path $repo 'scripts\health.lua'
$nvim = Join-Path $MsysRoot 'clang64\bin\nvim.exe'
Invoke-Checked $nvim @('--headless','-i','NONE','-c','lua dofile(vim.env.NVIM_BOOTSTRAP_SCRIPT)')
Write-Host "Integration passed in isolated copy: $work"
