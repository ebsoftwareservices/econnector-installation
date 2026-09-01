# Compatible zip extract for Windows PowerShell 4+ (Server 2012 R2) and 5+.
# Prefers tar.exe (Windows 10 1803+ / Server 2019+), then Expand-Archive (PS 5),
# then Shell.Application CopyHere (PS 2+).
param(
    [Parameter(Mandatory = $true)][string]$ZipPath,
    [Parameter(Mandatory = $true)][string]$Destination
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ZipPath)) {
    throw "Zip not found: $ZipPath"
}
if (-not (Test-Path -LiteralPath $Destination)) {
    New-Item -ItemType Directory -Path $Destination | Out-Null
}

$zipFull = (Resolve-Path -LiteralPath $ZipPath).Path
$destFull = (Resolve-Path -LiteralPath $Destination).Path

$tar = Get-Command tar.exe -ErrorAction SilentlyContinue
if ($tar) {
    & $tar.Source -xf $zipFull -C $destFull
    if ($LASTEXITCODE -ne 0) {
        throw "tar.exe failed to extract $zipFull"
    }
    exit 0
}

if (Get-Command Expand-Archive -ErrorAction SilentlyContinue) {
    Expand-Archive -Force -Path $zipFull -DestinationPath $destFull
    exit 0
}

$shell = New-Object -ComObject Shell.Application
$zipNs = $shell.NameSpace($zipFull)
$destNs = $shell.NameSpace($destFull)
if (-not $zipNs) { throw "Cannot open zip: $zipFull" }
if (-not $destNs) { throw "Cannot open destination: $destFull" }

$itemCount = $zipNs.Items().Count
# 4 = no progress UI, 16 = yes to all
$destNs.CopyHere($zipNs.Items(), 20)

$deadline = (Get-Date).AddMinutes(15)
do {
    Start-Sleep -Seconds 1
} while (($destNs.Items().Count -lt $itemCount) -and ((Get-Date) -lt $deadline))

if ($destNs.Items().Count -lt $itemCount) {
    throw "Timed out extracting $zipFull"
}
