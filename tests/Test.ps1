#Requires -Version 5.1
param([string]$Nvim)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $repo 'scripts\Common.ps1')
$work = Join-Path $repo ('.test-work\ps-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null
function Assert-True($Condition, [string]$Message) {
    if (!$Condition) { throw "FAIL: $Message" }
    Write-Host "PASS: $Message"
}
$errors = @()
Get-ChildItem -LiteralPath $repo -Recurse -Filter '*.ps1' | Where-Object { $_.FullName -notmatch '\\\.test-work\\' } | ForEach-Object {
    $tokens = $null
    $parseErrors = $null
    $null = [Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$parseErrors)
    $errors += $parseErrors
}
Assert-True ($errors.Count -eq 0) ('PowerShell syntax (' + ($errors -join ', ') + ')')
$source = Join-Path $repo 'config\nvim'
$destination = Join-Path $work 'profile with spaces\nvim'
$null = Install-Config $source $destination
Write-Utf8 (Join-Path $destination 'old.txt') 'previous user content'
Write-Utf8 (Join-Path $destination 'lua\config\local.lua') '-- local override'
$backup = Install-Config $source $destination
Assert-True (Test-Path -LiteralPath (Join-Path $backup 'old.txt')) 'existing config is fully backed up'
Assert-True (!(Test-Path -LiteralPath (Join-Path $destination 'old.txt'))) 'stale config does not leak into new deployment'
Assert-True ((Get-Content -Raw -LiteralPath (Join-Path $destination 'lua\config\local.lua')) -eq '-- local override') 'machine override survives redeployment'
Assert-True ((Get-FileHash -LiteralPath (Join-Path $source 'lazy-lock.json')).Hash -eq (Get-FileHash -LiteralPath (Join-Path $destination 'lazy-lock.json')).Hash) 'plugin lockfile is copied exactly'
$rejected = $false
try { $null = Install-Config $source $source } catch { $rejected = $true }
Assert-True $rejected 'overlapping deployment paths are rejected'
$rejected = $false
try { $null = Assert-ChildPath (Join-Path $work '..\outside') $work } catch { $rejected = $true }
Assert-True $rejected 'path traversal outside intended root is rejected'
$tools = Join-Path $work 'tools with spaces'
$bin = Join-Path $work 'bin with spaces'
Write-Launchers 'D:\custom-msys' $tools $bin 'D:\VS With Spaces\vcvars64.bat'
$shim = Get-Content -Raw -LiteralPath (Join-Path $tools 'bin\clangd-msvc.cmd')
Assert-True ($shim.Contains('call "D:\VS With Spaces\vcvars64.bat"')) 'VS path with spaces is quoted'
Assert-True ($shim.Contains('"D:\custom-msys\clang64\bin\clangd.exe" %*')) 'custom MSYS2 path is used'
$gitBash = Get-Content -Raw -LiteralPath (Join-Path $bin 'nvim')
Assert-True ($gitBash.Contains('"$@"') -and !$gitBash.Contains([char]13)) 'Git Bash launcher preserves arguments and LF'
Write-Launchers 'D:\custom-msys' $tools $bin ''
Assert-True (!(Get-Content -Raw -LiteralPath (Join-Path $tools 'bin\clangd-msvc.cmd')).Contains('vcvars64')) 'MSVC is optional'
$failed = $false
try { Invoke-Checked $env:ComSpec @('/d','/c','exit 7') } catch { $failed = $true }
Assert-True $failed 'external command failure propagates'
. (Join-Path $PSScriptRoot 'downloads.ps1')
$python = Find-NativePython
if ($python) { Assert-True (Test-Path -LiteralPath $python) 'native Python detection returns a real executable' }
Invoke-Checked 'powershell.exe' @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $repo 'scripts\Install.ps1'),'-ConfigOnly','-ConfigDir',(Join-Path $work 'public-entry\nvim'))
Assert-True (Test-Path -LiteralPath (Join-Path $work 'public-entry\nvim\init.lua')) 'public ConfigOnly entry point works'
# Exercise export in a disposable repository, including removal of obsolete files.
$exportRepo = Join-Path $work 'export-repo'
New-Item -ItemType Directory -Path (Join-Path $exportRepo 'scripts'),(Join-Path $exportRepo 'config') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $repo 'scripts\Common.ps1'),(Join-Path $repo 'scripts\Export-Config.ps1') -Destination (Join-Path $exportRepo 'scripts')
Copy-Item -LiteralPath $source -Destination (Join-Path $exportRepo 'config\nvim') -Recurse
Write-Utf8 (Join-Path $exportRepo 'config\nvim\lua\obsolete.lua') '-- remove on export'
Write-Utf8 (Join-Path $destination 'lazyvim.local.json') '{"python":"private-machine-path"}'
Invoke-Checked 'powershell.exe' @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $exportRepo 'scripts\Export-Config.ps1'),'-Source',$destination)
Assert-True (!(Test-Path -LiteralPath (Join-Path $exportRepo 'config\nvim\lazyvim.local.json'))) 'export excludes machine path metadata'
Assert-True (!(Test-Path -LiteralPath (Join-Path $exportRepo 'config\nvim\lua\config\local.lua'))) 'export excludes machine Lua overrides'
Assert-True (!(Test-Path -LiteralPath (Join-Path $exportRepo 'config\nvim\lua\obsolete.lua'))) 'export removes obsolete source files'
$node = Find-Application 'node.exe'
if ($node) { Invoke-Checked $node @('--test',(Join-Path $PSScriptRoot 'terminal.test.cjs')) }
if ($Nvim) {
    $env:NVIM_SETUP_REPO = $repo
    $env:NVIM_TEST_WORK = $work
    Invoke-Checked $Nvim @('--headless','-u','NONE','-i','NONE','-l',(Join-Path $PSScriptRoot 'smoke.lua'))
}
Write-Host 'All offline tests passed. Test artifacts remain under .test-work/.'
