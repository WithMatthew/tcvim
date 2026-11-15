#Requires -Version 5.1
[CmdletBinding()]
param([string]$Source = (Join-Path $env:LOCALAPPDATA 'nvim'))
. (Join-Path $PSScriptRoot 'Common.ps1')
$repo = Split-Path -Parent $PSScriptRoot
$dest = Join-Path $repo 'config\nvim'
if (!(Test-Path -LiteralPath (Join-Path $Source 'init.lua'))) { throw "Not a Neovim config: $Source" }
$Source = [IO.Path]::GetFullPath($Source).TrimEnd('\')
$destFull = [IO.Path]::GetFullPath($dest).TrimEnd('\')
if ($Source.Equals($destFull, [StringComparison]::OrdinalIgnoreCase) -or
    $Source.StartsWith($destFull + '\', [StringComparison]::OrdinalIgnoreCase) -or
    $destFull.StartsWith($Source + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Export source and destination must not overlap.'
}
$backup = Join-Path $repo ('.cache\export-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item -LiteralPath $dest -Destination (Join-Path $backup 'previous') -Recurse
$stage = Join-Path $backup 'staged'
New-Item -ItemType Directory -Path $stage -Force | Out-Null
# Export source files only. No plugin cache, machine paths, session state or credentials.
foreach ($name in @('init.lua','lazy-lock.json','lazyvim.json','.neoconf.json','stylua.toml','LICENSE')) {
    $file = Join-Path $Source $name
    if (Test-Path -LiteralPath $file) { Copy-Item -LiteralPath $file -Destination $stage }
}
$lua = Join-Path $Source 'lua'
if (Test-Path -LiteralPath $lua) {
    Get-ChildItem -LiteralPath $lua -Recurse -File -Filter '*.lua' | ForEach-Object {
        $relative = $_.FullName.Substring($Source.Length + 1)
        if ($relative -ne 'lua\config\local.lua') {
            $target = Join-Path $stage $relative
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
            Copy-Item -LiteralPath $_.FullName -Destination $target
        }
    }
}
# Use the same staged deployment logic; keep the old tree under the ignored cache.
$dest = Assert-ChildPath $dest (Join-Path $repo 'config')
$previous = Assert-ChildPath (Join-Path $backup 'replaced') (Join-Path $repo '.cache')
Move-Item -LiteralPath $dest -Destination $previous
try { Move-Item -LiteralPath $stage -Destination $dest }
catch {
    if (!(Test-Path -LiteralPath $dest)) { Move-Item -LiteralPath $previous -Destination $dest }
    throw
}
Write-Host "Exported to $dest"
Write-Host 'Review git diff before committing. Export does not rewrite custom paths in your own Lua code.'
