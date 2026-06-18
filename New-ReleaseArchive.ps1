$ErrorActionPreference = "Stop"

# Compute an uppercase SHA256 hex digest via .NET so the build does not depend on
# Get-FileHash, which is not always available in stripped-down PowerShell 5.1 hosts.
function Get-Sha256Hex {
    param([Parameter(Mandatory = $true)][string]$Path)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Path))
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '')
    } finally {
        $sha.Dispose()
    }
}

$versionFile = Join-Path $PSScriptRoot "VERSION"
$version = if (Test-Path $versionFile) { (Get-Content $versionFile).Trim() } else { "Unknown" }
$releaseDir = "Win11-25H2-CalmMode-Release"
$zipFile = "Win11-25H2-CalmMode-v$version.zip"

Write-Host "Creating clean release archive for v$version..."

# 1. Clean up old build folder if exists
if (Test-Path $releaseDir) {
    Remove-Item -Path $releaseDir -Recurse -Force
}

# 2. Create fresh build folder
New-Item -ItemType Directory -Path $releaseDir | Out-Null

# 3. Copy only necessary files
$filesToInclude = @(
    "README.md",
    "CHANGELOG_EN.md",
    "CHANGELOG_UA.md",
    "LICENSE",
    "VERSION",
    "Win11-25H2-CalmMode.ps1",
    "Win11-25H2-CalmMode.Tests.ps1"
)

foreach ($pattern in $filesToInclude) {
    if (Test-Path $pattern) {
        Copy-Item -Path $pattern -Destination $releaseDir
    }
}

$checksumsFile = "checksums.txt"
if (Test-Path $checksumsFile) { Remove-Item $checksumsFile -Force }

# 4. Generate file SHA256 hashes
Write-Host "Generating SHA256 checksums..."
Get-ChildItem -Path $releaseDir -File | ForEach-Object {
    $hash = Get-Sha256Hex -Path $_.FullName
    "$hash  $($_.Name)" | Add-Content -Path $checksumsFile
}

# 5. Create ZIP Archive
Write-Host "Compressing to $zipFile..."
if (Test-Path $zipFile) {
    Remove-Item -Path $zipFile -Force
}
Compress-Archive -Path "$releaseDir\*" -DestinationPath $zipFile

# 6. Generate ZIP SHA256
$zipHash = Get-Sha256Hex -Path $zipFile
"$zipHash  $zipFile" | Add-Content -Path $checksumsFile
"$zipHash  $zipFile" | Set-Content -Path "$zipFile.sha256"
Write-Host "Zip Hash: $zipHash"

# 7. Clean up build folder
Remove-Item -Path $releaseDir -Recurse -Force

Write-Host "Done! Release archive created: $zipFile"
Write-Host "Checksums are available in $checksumsFile and $zipFile.sha256 (also printed above)."
