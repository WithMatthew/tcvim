Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Utf8 {
    param([string]$Path, [string]$Text)
    $parent = Split-Path -Parent $Path
    if (!(Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding($false)))
}

function Assert-ChildPath {
    param([string]$Path, [string]$Parent)
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\','/')
    $base = [IO.Path]::GetFullPath($Parent).TrimEnd('\','/')
    if (!$full.StartsWith($base + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw ('Path must be inside {0}: {1}' -f $base,$full)
    }
    $cursor = $full
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Refusing to modify a symlink/junction: $cursor"
            }
        }
        $cursor = Split-Path -Parent $cursor
    }
    return $full
}

function Backup-Path {
    param([string]$Path)
    if (!(Test-Path -LiteralPath $Path)) { return $null }
    $parent = Split-Path -Parent ([IO.Path]::GetFullPath($Path))
    $source = Assert-ChildPath $Path $parent
    $backup = Assert-ChildPath ($source + '.backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + [guid]::NewGuid().ToString('N').Substring(0,6)) $parent
    Copy-Item -LiteralPath $source -Destination $backup -Recurse -Force
    Write-Host "Backup: $backup"
    return $backup
}

function Install-Config {
    param([string]$Source, [string]$Destination)
    $parent = Split-Path -Parent ([IO.Path]::GetFullPath($Destination))
    if (!(Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $dest = Assert-ChildPath $Destination $parent
    $sourceFull = [IO.Path]::GetFullPath($Source).TrimEnd('\')
    if ($dest.Equals($sourceFull, [StringComparison]::OrdinalIgnoreCase) -or
        $dest.StartsWith($sourceFull + '\', [StringComparison]::OrdinalIgnoreCase) -or
        $sourceFull.StartsWith($dest + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Source and destination configuration paths must not overlap.'
    }
    $stamp = (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + [guid]::NewGuid().ToString('N').Substring(0,6)
    $stage = Assert-ChildPath ($dest + '.stage-' + $stamp) $parent
    Copy-Item -LiteralPath $sourceFull -Destination $stage -Recurse -Force
    if (!(Test-Path -LiteralPath (Join-Path $stage 'init.lua'))) { throw "Invalid staged config: $stage" }
    foreach ($name in @('lazyvim.local.json','lua\config\local.lua')) {
        $local = Join-Path $dest $name
        if (Test-Path -LiteralPath $local) {
            $target = Join-Path $stage $name
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
            Copy-Item -LiteralPath $local -Destination $target -Force
        }
    }
    $backup = $null
    if (Test-Path -LiteralPath $dest) {
        $backup = Assert-ChildPath ($dest + '.backup-' + $stamp) $parent
        Move-Item -LiteralPath $dest -Destination $backup
        Write-Host "Backup: $backup"
    }
    try { Move-Item -LiteralPath $stage -Destination $dest }
    catch {
        if ($backup -and !(Test-Path -LiteralPath $dest)) { Move-Item -LiteralPath $backup -Destination $dest }
        throw
    }
    return $backup
}

function Invoke-Checked {
    param([string]$File, [string[]]$Arguments, [int[]]$SuccessCodes = @(0))
    Write-Host ('> ' + $File + ' ' + ($Arguments -join ' '))
    & $File @Arguments | Out-Host
    $code = $LASTEXITCODE
    if ($code -notin $SuccessCodes) { throw "$File failed (exit $code)." }
}

function Refresh-ProcessPath {
    $paths = @(
        [Environment]::GetEnvironmentVariable('Path','User'),
        [Environment]::GetEnvironmentVariable('Path','Machine'),
        $env:Path
    )
    $env:Path = (($paths -join ';').Split(';') | Where-Object { $_ } | Select-Object -Unique) -join ';'
}

function Find-Application {
    param([string]$Name)
    $command = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command.Source }
    return $null
}

function Find-NativePython {
    $candidates = @()
    $found = Find-Application 'python.exe'
    if ($found -and $found -notmatch '\\WindowsApps\\') { $candidates += $found }
    foreach ($base in @("$env:LOCALAPPDATA\Programs\Python", "$env:ProgramFiles\Python")) {
        if (Test-Path -LiteralPath $base) {
            $candidates += @(Get-ChildItem -LiteralPath $base -Filter python.exe -Recurse -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -ExpandProperty FullName)
        }
    }
    foreach ($python in $candidates) {
        if ($python -match '\\msys[^\\]*\\') { continue }
        $result = & $python -c "import sys; print(sys.executable if sys.version_info >= (3,10) else '')" 2>$null
        if ($LASTEXITCODE -eq 0 -and $result) {
            & $python -m pip --version *> $null
            if ($LASTEXITCODE -eq 0) { return [string]$result }
        }
    }
    return $null
}

function Install-WingetPackage {
    param([string]$Id, [string[]]$Extra = @(), [switch]$Upgrade)
    $winget = Find-Application 'winget.exe'
    if (!$winget) { throw 'WinGet is required. Install/update Microsoft App Installer, then rerun install.cmd. See README.md.' }
    $policy = if ($Upgrade) { @() } else { @('--no-upgrade') }
    Invoke-Checked $winget (@('install','--id',$Id,'--exact','--source','winget','--silent','--accept-package-agreements','--accept-source-agreements','--disable-interactivity') + $policy + $Extra) @(0, -1978335189, 3010)
    Refresh-ProcessPath
}

function Get-VcVars {
    $programFilesX86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    $vswhere = Join-Path $programFilesX86 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (!(Test-Path -LiteralPath $vswhere)) { return $null }
    $vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($LASTEXITCODE -eq 0 -and $vs) {
        $vcvars = Join-Path ([string]$vs) 'VC\Auxiliary\Build\vcvars64.bat'
        if (Test-Path -LiteralPath $vcvars) { return $vcvars }
    }
    return $null
}

function Install-GitHubArchive {
    param($Spec, [string]$ToolsRoot, [string]$CacheRoot)
    $destination = Join-Path $ToolsRoot $Spec.target
    $marker = Join-Path $ToolsRoot ('versions\' + $Spec.name + '.json')
    $installed = Join-Path $destination $Spec.exe
    if ((Test-Path -LiteralPath $marker) -and (Test-Path -LiteralPath $installed)) {
        $previous = Get-Content -Raw -LiteralPath $marker | ConvertFrom-Json
        if ($previous.tag -eq $Spec.tag -and $previous.sha256 -eq (Get-FileHash -LiteralPath $installed -Algorithm SHA256).Hash) {
            Write-Host "$($Spec.name) $($Spec.tag): already installed"
            return $installed
        }
    }
    $assetName = [IO.Path]::GetFileName(([uri]$Spec.url).AbsolutePath)
    $asset = [pscustomobject]@{name=$assetName; browser_download_url=$Spec.url}
    $expected = [string]$Spec.sha256
    if (!$expected -and $Spec.PSObject.Properties['checksumUrl']) {
        $checksums = (Invoke-WebRequest -UseBasicParsing -Uri $Spec.checksumUrl -TimeoutSec 60).Content
        if ($checksums -is [byte[]]) { $checksums = [Text.Encoding]::UTF8.GetString($checksums) }
        $pattern = '(?im)^([a-f0-9]{64})\s+\*?(?:\./)?' + [regex]::Escape($assetName) + '\s*$'
        if ($checksums -notmatch $pattern) { throw "No checksum for $assetName in the upstream checksum file." }
        $expected = $Matches[1]
    }
    if ($expected -notmatch '^[a-fA-F0-9]{64}$') { throw "Missing SHA256 for $assetName" }
    $archive = Join-Path $CacheRoot ($Spec.name + '-' + $Spec.tag + '.zip')
    New-Item -ItemType Directory -Path $CacheRoot -Force | Out-Null
    $verified = $false
    $digest = 'sha256:' + $expected
    if ((Test-Path -LiteralPath $archive) -and $digest -match '^sha256:(.+)$') {
        $verified = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -eq $Matches[1]
    }
    if (!$verified) {
        Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile ($archive + '.partial') -TimeoutSec 600
        if ($digest -match '^sha256:(.+)$') {
            if ((Get-FileHash -LiteralPath ($archive + '.partial') -Algorithm SHA256).Hash -ne $Matches[1]) {
                throw "SHA256 mismatch: $($asset.name)"
            }
        }
        Move-Item -LiteralPath ($archive + '.partial') -Destination $archive -Force
    }
    $extract = Join-Path $CacheRoot ($Spec.name + '-' + [guid]::NewGuid().ToString('N'))
    Expand-Archive -LiteralPath $archive -DestinationPath $extract
    $matches = @(Get-ChildItem -LiteralPath $extract -Recurse -File -Filter $Spec.exe)
    if ($matches.Count -ne 1) { throw "Expected exactly one $($Spec.exe) in $archive." }
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    if ($Spec.name -eq 'shader-language-server') {
        Get-ChildItem -LiteralPath $matches[0].Directory.FullName -Force | Copy-Item -Destination $destination -Recurse -Force
    } else {
        Copy-Item -LiteralPath $matches[0].FullName -Destination $installed -Force
    }
    Write-Utf8 $marker (@{ tag = $Spec.tag; sha256 = (Get-FileHash -LiteralPath $installed -Algorithm SHA256).Hash } | ConvertTo-Json)
    return $installed
}

function Write-Launchers {
    param([string]$MsysRoot, [string]$ToolsRoot, [string]$BinDir, [string]$VcVars)
    foreach ($path in @($MsysRoot,$ToolsRoot,$BinDir,$VcVars)) {
        if ($path -match '["%!\r\n]') { throw "Unsupported characters in launcher path: $path" }
    }
    $nl = [Environment]::NewLine
    $clangBin = Join-Path $MsysRoot 'clang64\bin'
    $toolBin = Join-Path $ToolsRoot 'bin'
    $shim = '@echo off' + $nl + 'setlocal' + $nl
    if ($VcVars) { $shim += ('call "{0}" >nul' -f $VcVars) + $nl + 'if errorlevel 1 exit /b 1' + $nl }
    $shim += ('"{0}\clangd.exe" %*' -f $clangBin) + $nl + 'exit /b %ERRORLEVEL%' + $nl
    Write-Utf8 (Join-Path $toolBin 'clangd-msvc.cmd') $shim
    foreach ($exe in @('curl','ninja','cmake','clang-format')) {
        Write-Utf8 (Join-Path $toolBin ($exe + '.cmd')) ('@echo off' + $nl + ('"{0}\{1}.exe" %*' -f $clangBin,$exe) + $nl + 'exit /b %ERRORLEVEL%' + $nl)
    }
    Write-Utf8 (Join-Path $ToolsRoot 'treesitter\clang.cmd') ('@echo off' + $nl + ('"{0}\clang.exe" %* --target=x86_64-w64-windows-gnu' -f $clangBin) + $nl + 'exit /b %ERRORLEVEL%' + $nl)
    foreach ($name in @('nvim.cmd','nvim')) {
        if (Test-Path -LiteralPath (Join-Path $BinDir $name)) { $null = Backup-Path (Join-Path $BinDir $name) }
    }
    Write-Utf8 (Join-Path $BinDir 'nvim.cmd') ('@echo off' + $nl + ('"{0}\nvim.exe" %*' -f $clangBin) + $nl + 'exit /b %ERRORLEVEL%' + $nl)
    $posix = ($clangBin + '\nvim.exe').Replace('\','/').Replace("'", "'\''")
    Write-Utf8 (Join-Path $BinDir 'nvim') ('#!/usr/bin/env bash' + [char]10 + "exec '" + $posix + "' " + '"$@"' + [char]10)
}

function Add-UserPath {
    param([string]$Directory)
    $current = [Environment]::GetEnvironmentVariable('Path','User')
    $parts = @($current -split ';' | Where-Object { $_ -and $_.TrimEnd('\') -ne $Directory.TrimEnd('\') })
    [Environment]::SetEnvironmentVariable('Path', ((@($Directory) + $parts) -join ';'), 'User')
    $env:Path = $Directory + ';' + $env:Path
    if (!('NvimEnvironmentNative' -as [type])) {
        Add-Type 'using System; using System.Runtime.InteropServices; public static class NvimEnvironmentNative { [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessageTimeout(IntPtr hwnd, uint msg, IntPtr w, string l, uint flags, uint timeout, out IntPtr result); }'
    }
    $result = [IntPtr]::Zero
    [void][NvimEnvironmentNative]::SendMessageTimeout([IntPtr]0xffff,0x001a,[IntPtr]::Zero,'Environment',2,1000,[ref]$result)
}

function Install-Font {
    param([string]$File)
    $directory = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $destination = Join-Path $directory (Split-Path -Leaf $File)
    if (!(Test-Path -LiteralPath $destination) -or (Get-FileHash -LiteralPath $File).Hash -ne (Get-FileHash -LiteralPath $destination).Hash) {
        Copy-Item -LiteralPath $File -Destination $destination -Force
    }
    $key = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    New-Item -Path $key -Force | Out-Null
    New-ItemProperty -Path $key -Name 'FiraCode Nerd Font Mono Regular (TrueType)' -Value $destination -PropertyType String -Force | Out-Null
    if (!('NvimFontNative' -as [type])) {
        Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class NvimFontNative {
    [DllImport("gdi32.dll", CharSet=CharSet.Unicode)] public static extern int AddFontResourceEx(string file, uint flags, IntPtr reserved);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessageTimeout(IntPtr hwnd, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
}
'@
    }
    [void][NvimFontNative]::AddFontResourceEx($destination,0,[IntPtr]::Zero)
    $result = [IntPtr]::Zero
    [void][NvimFontNative]::SendMessageTimeout([IntPtr]0xffff,0x001d,[IntPtr]::Zero,[IntPtr]::Zero,2,1000,[ref]$result)
}
