#requires -Version 5.1
<#
Sign-CalmMode.ps1 - sign the Calm Mode scripts with an Authenticode certificate.

This repo ships NO certificate. Signing is optional and only meaningful with a
code-signing certificate YOU provide (a self-signed cert gives no third-party trust;
it only helps on machines that explicitly trust it). SHA256 checksums
(see New-ReleaseArchive.ps1) remain the primary integrity mechanism.

Usage:
    # Using a cert already in your certificate store (Cert:\CurrentUser\My):
    .\Sign-CalmMode.ps1 -Thumbprint <CERT_THUMBPRINT>

    # Using a PFX file:
    .\Sign-CalmMode.ps1 -PfxPath .\codesign.pfx -PfxPassword (Read-Host -AsSecureString)

Verify afterwards:
    Get-AuthenticodeSignature .\Win11-25H2-CalmMode.ps1 | Format-List Status, SignerCertificate
#>
[CmdletBinding(DefaultParameterSetName = "Thumbprint")]
param(
    [Parameter(ParameterSetName = "Thumbprint", Mandatory = $true)]
    [string]$Thumbprint,

    [Parameter(ParameterSetName = "Pfx", Mandatory = $true)]
    [string]$PfxPath,

    [Parameter(ParameterSetName = "Pfx")]
    [System.Security.SecureString]$PfxPassword,

    [string]$TimestampServer = "http://timestamp.digicert.com"
)

$ErrorActionPreference = "Stop"

# Files to sign (skip any that are absent).
$targets = @("Win11-25H2-CalmMode.ps1", "Win11-25H2-CalmMode-GUI.ps1") |
    ForEach-Object { Join-Path $PSScriptRoot $_ } |
    Where-Object { Test-Path -LiteralPath $_ }

if (-not $targets) {
    Write-Host "ERROR: No scripts found to sign next to this file." -ForegroundColor Red
    exit 1
}

# Resolve the signing certificate.
if ($PSCmdlet.ParameterSetName -eq "Pfx") {
    if (-not (Test-Path -LiteralPath $PfxPath)) {
        Write-Host "ERROR: PFX not found: $PfxPath" -ForegroundColor Red
        exit 1
    }
    $cert = if ($PfxPassword) {
        New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList (Resolve-Path -LiteralPath $PfxPath).Path, $PfxPassword
    } else {
        New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList (Resolve-Path -LiteralPath $PfxPath).Path
    }
} else {
    $cert = Get-ChildItem -Path "Cert:\CurrentUser\My\$Thumbprint" -ErrorAction SilentlyContinue
    if (-not $cert) { $cert = Get-ChildItem -Path "Cert:\LocalMachine\My\$Thumbprint" -ErrorAction SilentlyContinue }
    if (-not $cert) {
        Write-Host "ERROR: No certificate with thumbprint '$Thumbprint' in CurrentUser\My or LocalMachine\My." -ForegroundColor Red
        exit 1
    }
}

$failed = 0
foreach ($file in $targets) {
    $sig = Set-AuthenticodeSignature -FilePath $file -Certificate $cert -TimestampServer $TimestampServer -HashAlgorithm SHA256
    $color = if ($sig.Status -eq "Valid") { "Green" } else { "Yellow" }
    Write-Host ("{0}: {1}" -f (Split-Path -Leaf $file), $sig.Status) -ForegroundColor $color
    if ($sig.Status -ne "Valid") { $failed++ }
}

if ($failed -gt 0) {
    Write-Host "$failed file(s) did not end up with a Valid signature. Check the certificate and trust chain." -ForegroundColor Yellow
    exit 2
}
Write-Host "Done. Verify with: Get-AuthenticodeSignature <file> | Format-List Status, SignerCertificate" -ForegroundColor Cyan
exit 0
