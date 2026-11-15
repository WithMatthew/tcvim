# Dot-sourced by Test.ps1 after Common.ps1. Replace only the network boundary.
$archiveSource = Join-Path $work 'download-source'
New-Item -ItemType Directory -Path $archiveSource -Force | Out-Null
Write-Utf8 (Join-Path $archiveSource 'tool.exe') 'test executable bytes'
$script:FixtureZip = Join-Path $work 'fixture.zip'
Compress-Archive -LiteralPath (Join-Path $archiveSource 'tool.exe') -DestinationPath $script:FixtureZip
$script:DownloadCount = 0
function Invoke-WebRequest {
    param([switch]$UseBasicParsing, [string]$Uri, [string]$OutFile, [int]$TimeoutSec)
    $script:DownloadCount++
    Copy-Item -LiteralPath $script:FixtureZip -Destination $OutFile
}
$spec = [pscustomobject]@{
    name='test';tag='v1';exe='tool.exe';target='bin';url='https://example.invalid/tool.zip'
    sha256=(Get-FileHash -LiteralPath $script:FixtureZip -Algorithm SHA256).Hash
}
$downloadTools = Join-Path $work 'download-tools'
$downloadCache = Join-Path $work 'download-cache'
$installed = Install-GitHubArchive $spec $downloadTools $downloadCache
$again = Install-GitHubArchive $spec $downloadTools $downloadCache
Assert-True ($script:DownloadCount -eq 1 -and $installed -eq $again) 'verified downloads are reused on rerun'
$spec.tag = 'v2'
$spec.sha256 = '0' * 64
$rejected = $false
try { $null = Install-GitHubArchive $spec $downloadTools $downloadCache } catch { $rejected = $true }
Assert-True $rejected 'incorrect download checksum is rejected'
Assert-True ((Get-Content -Raw -LiteralPath $installed) -eq 'test executable bytes') 'failed download leaves installed tool intact'
Remove-Item -LiteralPath Function:\Invoke-WebRequest
