#Requires -Version 5.1
[CmdletBinding()]
param()
. (Join-Path $PSScriptRoot 'Common.ps1')
$localConfig = Join-Path $env:LOCALAPPDATA 'nvim\lazyvim.local.json'
if (!(Test-Path -LiteralPath $localConfig)) { throw 'Run install.cmd first: lazyvim.local.json is missing.' }
$settings = Get-Content -Raw -LiteralPath $localConfig | ConvertFrom-Json
$nvim = Join-Path $settings.msysRoot 'clang64\bin\nvim.exe'
try {
    $env:NVIM_BOOTSTRAP = '1'
    $env:NVIM_BOOTSTRAP_STAGE = 'check'
    $env:NVIM_BOOTSTRAP_SCRIPT = Join-Path $PSScriptRoot 'health.lua'
    Invoke-Checked $nvim @('--headless','-i','NONE','-c','lua dofile(vim.env.NVIM_BOOTSTRAP_SCRIPT)')
} finally {
    foreach ($name in @('NVIM_BOOTSTRAP','NVIM_BOOTSTRAP_STAGE','NVIM_BOOTSTRAP_SCRIPT')) {
        [Environment]::SetEnvironmentVariable($name,$null,'Process')
    }
}
