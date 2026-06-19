#requires -Version 5.1
#requires -PSEdition Desktop

<#
Win11-25H2-CalmMode.ps1

Modes:
  Audit  - reads current settings and shows what would change. Does NOT modify Windows.
  Apply  - applies only missing/different settings, verifies writes, exports registry backup, creates reports.
  Verify - checks whether desired state is present. Does NOT modify Windows.

Design goals:
  - No aggressive debloating.
  - Does NOT disable Defender, Firewall, Windows Update service, Microsoft Store, WebView2, .NET, certificates, or core services.
  - Uses registry-backed Windows/Edge policies where possible.
  - Clearly marks best-effort/deprecated/maybe-ignored settings in the report.

Recommended:
  Run in Windows PowerShell 5.1 as Administrator.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "Medium")]
param(
    [ValidateSet("Audit", "Apply", "Verify")]
    [string]$Mode = "Audit",

    [string]$TargetReleaseVersionInfo = "25H2",

    [ValidateRange(0,365)]
    [int]$FeatureUpdateDeferralDays = 90,

    [ValidateRange(0,30)]
    [int]$QualityUpdateDeferralDays = 7,

    [ValidateRange(0,23)]
    [int]$ActiveHoursStart = 10,

    [ValidateRange(0,23)]
    [int]$ActiveHoursEnd = 2,

    [ValidateSet("Hidden", "Icon", "Box")]
    [string]$SearchMode = "Icon",

    # Diagnostic data level for AllowTelemetry policy.
    # 0 = Security/Off (honored only on Enterprise/Education/IoT; ignored on Home/Pro)
    # 1 = Required (the minimum that Home/Pro actually honor)
    [ValidateRange(0,3)]
    [int]$TelemetryLevel = 1,

    [bool]$SetTaskbarLeft = $true,

    [switch]$SkipRestorePoint,
    [switch]$NoAppCleanup,
    [switch]$NoRestartExplorer
)

# ============================================================
# MODULE TOGGLES
# ============================================================

$EnableWindowsAIBlock       = $true
$EnableWidgetsBlock         = $true
$EnableCloudContentBlock    = $true
$EnablePrivacyBlock         = $true
$EnableSearchBlock          = $true
$EnableStartTaskbarBlock    = $true
$EnableWindowsUpdateBlock   = $true
$EnableDeliveryOptimization = $true
$EnableManualWindowsUpdateMode = $false

# Target Release Version pinning is OFF by default. Pinning the feature version
# (for example 25H2) can block future feature and security servicing once that
# release reaches end of service. Enable only if you understand the long-term
# update implications.
$EnableTargetReleaseVersionPin = $false
$EnableEdgeQuietMode        = $true
# SECURITY TRADE-OFF: Sideloading and Developer Mode expand the attack surface. Use only if needed for development.
$EnableDeveloperMode        = $false
$EnableLongPaths            = $true
$DisableFastStartup         = $true
$EnableGamingTweaks         = $true

# App cleanup defaults. These are best-effort and can be skipped with -NoAppCleanup.
$RemoveCopilotApp           = $false
$RemoveTeamsPersonal        = $false
$RemoveXboxApps             = $false
$RemoveOneDrive             = $false

# ============================================================
# GLOBALS / PRE-FLIGHT
# ============================================================

$activeHoursDiff = if ($ActiveHoursEnd -gt $ActiveHoursStart) { $ActiveHoursEnd - $ActiveHoursStart } else { 24 - $ActiveHoursStart + $ActiveHoursEnd }
if ($activeHoursDiff -gt 18) {
    Write-Host "ERROR: Active hours difference cannot exceed 18 hours (Current diff: $activeHoursDiff hours)." -ForegroundColor Red
    exit 1
}

$script:Results = New-Object 'System.Collections.Generic.List[object]'
$script:RegistrySettings = New-Object 'System.Collections.Generic.List[object]'
$script:RollbackEntries = New-Object 'System.Collections.Generic.List[object]'

$script:CurrentUserIsAdmin = $false
$script:CurrentIdentityName = ""
try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $script:CurrentIdentityName = $identity.Name
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $script:CurrentUserIsAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch { Write-Verbose "Ignored non-critical error: $($_.Exception.Message)" }

# Interactive console user. When the script runs under a different (for example, a
# separate elevated) account, HKCU points at THAT account's hive, so per-user policies
# would never reach the signed-in user's profile. Detect this so preflight can warn
# instead of silently writing per-user tweaks to the wrong hive.
$script:InteractiveUser = ""
try {
    $script:InteractiveUser = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).UserName
} catch {
    $script:InteractiveUser = ""
}

if ($Mode -eq "Apply" -and -not $script:CurrentUserIsAdmin) {
    Write-Host "ERROR: Apply mode requires Administrator. Re-run Windows PowerShell as Administrator." -ForegroundColor Red
    exit 1
}

if ($Mode -ne "Apply" -and -not $script:CurrentUserIsAdmin) {
    Write-Host "WARNING: You are not running as Administrator. Audit/Verify can continue, but some HKLM/Appx checks may be incomplete." -ForegroundColor Yellow
}

$script:CV = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue
$script:ProductName = $script:CV.ProductName
$script:DisplayVersion = $script:CV.DisplayVersion
$script:BuildNumber = 0
$script:UBR = 0
$script:EditionId = $script:CV.EditionID

try { $script:BuildNumber = [int]$script:CV.CurrentBuild } catch { $script:BuildNumber = 0 }
try { $script:UBR = [int]$script:CV.UBR } catch { $script:UBR = 0 }

function Get-EditionGroup {
    param([string]$EditionId)

    if ([string]::IsNullOrWhiteSpace($EditionId)) { return "Unknown" }

    if ($EditionId -like "Core*") { return "Home" }
    if ($EditionId -like "ProfessionalEducation*") { return "Education" }
    if ($EditionId -like "ProfessionalWorkstation*") { return "Pro" }
    if ($EditionId -like "Professional*") { return "Pro" }
    if ($EditionId -like "Enterprise*") { return "Enterprise" }
    if ($EditionId -like "Education*") { return "Education" }
    if ($EditionId -like "IoTEnterprise*") { return "IoTEnterprise" }

    return $EditionId
}

$script:EditionGroup = Get-EditionGroup $script:EditionId

# Single source of truth for version/branding, used in folder, file, and report names.
$versionFile = Join-Path $PSScriptRoot "VERSION"
$script:ScriptVersion = if (Test-Path $versionFile) { (Get-Content $versionFile).Trim() } else { "Unknown" }
$script:ScriptName     = "Win11-25H2-CalmMode-v$script:ScriptVersion"
$script:ScriptTitle    = "Win11 25H2 Calm Mode v$script:ScriptVersion"

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$desktopPath = [Environment]::GetFolderPath("Desktop")
if ([string]::IsNullOrWhiteSpace($desktopPath)) { $desktopPath = $env:TEMP }

$script:ReportDir = Join-Path $desktopPath "$script:ScriptName-$Mode-$timestamp"
New-Item -ItemType Directory -Path $script:ReportDir -Force | Out-Null

try {
    Start-Transcript -Path (Join-Path $script:ReportDir "$script:ScriptName.log") -Force | Out-Null
} catch {
    Write-Host "WARNING: Could not start transcript: $($_.Exception.Message)" -ForegroundColor Yellow
}

function Write-Section {
    param([string]$Text)
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor DarkGray
    Write-Host $Text -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor DarkGray
}

function Add-Result {
    param(
        [string]$Category,
        [string]$Item,
        [string]$Status,
        [object]$CurrentValue,
        [object]$DesiredValue,
        [string]$Path,
        [string]$Name,
        [string]$Confidence,
        [string]$Support,
        [string]$Message
    )

    $script:Results.Add([pscustomobject]@{
        Time         = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Mode         = $Mode
        Category     = $Category
        Item         = $Item
        Status       = $Status
        CurrentValue = if ($null -eq $CurrentValue) { "" } else { [string]$CurrentValue }
        DesiredValue = if ($null -eq $DesiredValue) { "" } else { [string]$DesiredValue }
        Path         = $Path
        Name         = $Name
        Confidence   = $Confidence
        Support      = $Support
        Message      = $Message
    }) | Out-Null
}

function Get-ConsoleStatusColor {
    param([string]$Status)

    switch -Wildcard ($Status) {
        "Compliant"          { return "Green" }
        "AlreadyConfigured"  { return "Green" }
        "Changed"            { return "Green" }
        "VerifyOK"           { return "Green" }
        "WouldChange"        { return "Yellow" }
        "WouldRemove"        { return "Yellow" }
        "Skipped"            { return "DarkYellow" }
        "VerifyFail"         { return "Red" }
        "Error"              { return "Red" }
        "Unsupported*"       { return "Red" }
        "RequiresVerification" { return "DarkYellow" }
        "Warning"            { return "Yellow" }
        default              { return "Gray" }
    }
}

function Write-ResultLine {
    param(
        [string]$Status,
        [string]$Category,
        [string]$Item,
        [object]$CurrentValue,
        [object]$DesiredValue,
        [string]$Message
    )

    $color = Get-ConsoleStatusColor $Status
    $cur = if ($null -eq $CurrentValue) { "<missing>" } else { [string]$CurrentValue }
    $des = if ($null -eq $DesiredValue) { "" } else { [string]$DesiredValue }

    Write-Host ("[{0}] {1} :: {2} | current='{3}' desired='{4}' {5}" -f $Status, $Category, $Item, $cur, $des, $Message) -ForegroundColor $color
}

function Get-RegValueSafe {
    param(
        [string]$Path,
        [string]$Name
    )

    try {
        if (-not (Test-Path $Path)) {
            return [pscustomobject]@{ Exists = $false; Value = $null; Error = $null }
        }

        $props = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        return [pscustomobject]@{ Exists = $true; Value = $props.$Name; Error = $null }
    } catch {
        return [pscustomobject]@{ Exists = $false; Value = $null; Error = $_.Exception.Message }
    }
}

function Test-ValueEquals {
    param(
        [object]$A,
        [object]$B,
        [string]$Type
    )

    if ($Type -eq "DWord") {
        try { return ([int]$A -eq [int]$B) } catch { return $false }
    }

    return ([string]$A -eq [string]$B)
}

function Test-WidgetsDisabledByPolicy {
    <#
    Windows 11 25H2 can omit the per-user TaskbarDa UI value when Widgets are already disabled
    by the device policy. In that case, missing TaskbarDa is not a real failure.
    Official policy-backed control:
      HKLM:\\SOFTWARE\\Policies\\Microsoft\\Dsh\\AllowNewsAndInterests = 0
    #>

    $policy = Get-RegValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests"
    if (-not $policy.Exists) { return $false }

    try { return ([int]$policy.Value -eq 0) } catch { return $false }
}

function Test-TaskbarDaSatisfiedByPolicy {
    param([pscustomobject]$Setting)

    if ($Setting.Name -ne "TaskbarDa") { return $false }
    if ($Setting.Type -ne "DWord") { return $false }

    try {
        if ([int]$Setting.Value -ne 0) { return $false }
    } catch {
        return $false
    }

    return (Test-WidgetsDisabledByPolicy)
}

function Get-Applicability {
    param([pscustomobject]$Setting)

    $support = "Supported"

    if ($Setting.MinBuild -gt 0 -and $script:BuildNumber -gt 0 -and $script:BuildNumber -lt $Setting.MinBuild) {
        return [pscustomobject]@{
            Status = "UnsupportedBuild"
            Message = "Requires build >= $($Setting.MinBuild); detected build $script:BuildNumber."
            CanApply = $false
        }
    }

    # Only gate on UBR when it is actually known (> 0). If the UBR could not be read,
    # fail open (treat as applicable) rather than wrongly reporting UnsupportedBuild,
    # because $null/0 would otherwise always compare as less than MinUBR.
    if ($Setting.MinBuild -eq $script:BuildNumber -and $Setting.MinUBR -gt 0 -and $script:UBR -gt 0 -and $script:UBR -lt $Setting.MinUBR) {
        return [pscustomobject]@{
            Status = "UnsupportedBuild"
            Message = "Requires build $($Setting.MinBuild).$($Setting.MinUBR)+; detected build $script:BuildNumber.$script:UBR."
            CanApply = $false
        }
    }

    if ($Setting.Editions -and $Setting.Editions.Count -gt 0) {
        if ($Setting.Editions -notcontains $script:EditionGroup) {
            $support = "MaybeIgnoredOnEdition"
            return [pscustomobject]@{
                Status = $support
                Message = "Policy is documented for editions: $($Setting.Editions -join ', '); detected edition group: $script:EditionGroup. Registry value can be written, but Windows may ignore it."
                CanApply = $Setting.ApplyIfMaybeUnsupported
            }
        }
    }

    if ($Setting.Confidence -eq "BestEffort") {
        $support = "BestEffort"
    } elseif ($Setting.Confidence -eq "Deprecated") {
        $support = "DeprecatedOrLegacy"
    } elseif ($Setting.Confidence -eq "UISetting") {
        $support = "UISetting"
    } elseif ($Setting.Confidence -eq "RequiresVerification") {
        $support = "RequiresVerification"
    }

    return [pscustomobject]@{
        Status = $support
        Message = $Setting.Note
        CanApply = $true
    }
}

function Add-RegSetting {
    param(
        [Parameter(Mandatory=$true)][string]$Category,
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][ValidateSet("DWord", "String")][string]$Type,
        [Parameter(Mandatory=$true)][object]$Value,
        [Parameter(Mandatory=$true)][string]$Description,
        [int]$MinBuild = 0,
        [string[]]$Editions = @(),
        [ValidateSet("Official", "BestEffort", "Deprecated", "UISetting", "RequiresVerification")]
        [string]$Confidence = "Official",
        [string]$Note = "",
        [bool]$ApplyIfMaybeUnsupported = $true,
        [int]$MinUBR = 0
    )

    $script:RegistrySettings.Add([pscustomobject]@{
        Category = $Category
        Path = $Path
        Name = $Name
        Type = $Type
        Value = $Value
        Description = $Description
        MinBuild = $MinBuild
        Editions = $Editions
        Confidence = $Confidence
        Note = $Note
        ApplyIfMaybeUnsupported = $ApplyIfMaybeUnsupported
        MinUBR = $MinUBR
    }) | Out-Null
}

function Invoke-RegSetting {
    param([pscustomobject]$Setting)

    $applicability = Get-Applicability $Setting
    $desired = $Setting.Value
    $read = Get-RegValueSafe -Path $Setting.Path -Name $Setting.Name
    $current = $read.Value
    $equals = $false

    if ($read.Exists) {
        $equals = Test-ValueEquals -A $current -B $desired -Type $Setting.Type
    }

    $satisfiedByPolicy = $false
    if (-not $equals -and (Test-TaskbarDaSatisfiedByPolicy -Setting $Setting)) {
        $satisfiedByPolicy = $true
        $equals = $true
        if (-not $read.Exists) {
            $current = "Missing; satisfied by Widgets policy AllowNewsAndInterests=0"
        }
    }

    $supportText = $applicability.Status
    if (-not [string]::IsNullOrWhiteSpace($applicability.Message)) {
        $supportText = "$supportText; $($applicability.Message)"
    }

    # Audit and Verify are both read-only: identical structure, only the status
    # labels and messages differ. Drive them from one table to avoid duplication.
    if ($Mode -eq "Audit" -or $Mode -eq "Verify") {
        $readOnly = @{
            Audit  = @{ Pass = "Compliant"; Fail = "WouldChange"; PassMsg = "Already matches desired value."; FailMsg = "No changes made in Audit mode." }
            Verify = @{ Pass = "VerifyOK";   Fail = "VerifyFail";  PassMsg = "Desired registry value is present."; FailMsg = "Desired registry value is missing or different." }
        }
        $m = $readOnly[$Mode]

        $status = if ($equals) { $m.Pass } else { $m.Fail }
        $msg    = if ($equals) { $m.PassMsg } else { $m.FailMsg }

        if ($satisfiedByPolicy) {
            $msg = "Per-user TaskbarDa value is not required because Widgets are disabled by policy AllowNewsAndInterests=0."
        }

        if ($applicability.Status -eq "UnsupportedBuild") {
            $status = "UnsupportedBuild"
            $msg = $applicability.Message
        }

        Add-Result $Setting.Category $Setting.Description $status $current $desired $Setting.Path $Setting.Name $Setting.Confidence $supportText $msg
        Write-ResultLine $status $Setting.Category $Setting.Description $current $desired $msg
        return
    }

    if ($Mode -eq "Apply") {
        if (-not $applicability.CanApply) {
            Add-Result $Setting.Category $Setting.Description "Skipped" $current $desired $Setting.Path $Setting.Name $Setting.Confidence $supportText "Skipped because this setting is not applicable to this Windows build/edition."
            Write-ResultLine "Skipped" $Setting.Category $Setting.Description $current $desired "Not applicable."
            return
        }

        if ($equals) {
            $alreadyMessage = "Already configured. No write performed."
            $printMessage = "No write needed."
            if ($satisfiedByPolicy) {
                $alreadyMessage = "No write performed: per-user TaskbarDa value is not required because Widgets are disabled by policy AllowNewsAndInterests=0."
                $printMessage = "Satisfied by Widgets policy."
            }

            Add-Result $Setting.Category $Setting.Description "AlreadyConfigured" $current $desired $Setting.Path $Setting.Name $Setting.Confidence $supportText $alreadyMessage
            Write-ResultLine "AlreadyConfigured" $Setting.Category $Setting.Description $current $desired $printMessage
            return
        }

        if (-not $PSCmdlet.ShouldProcess("$($Setting.Path)\$($Setting.Name)", "Set $($Setting.Type) to '$desired'")) {
            Add-Result $Setting.Category $Setting.Description "Skipped" $current $desired $Setting.Path $Setting.Name $Setting.Confidence $supportText "Skipped by -WhatIf/-Confirm."
            Write-ResultLine "Skipped" $Setting.Category $Setting.Description $current $desired "Skipped (WhatIf/Confirm)."
            return
        }

        try {
            $script:RollbackEntries.Add([pscustomobject]@{
                Path     = $Setting.Path
                Name     = $Setting.Name
                Type     = $Setting.Type
                Existed  = $read.Exists
                OldValue = if ($read.Exists) { $read.Value } else { $null }
            }) | Out-Null

            if (-not (Test-Path $Setting.Path)) {
                New-Item -Path $Setting.Path -Force | Out-Null
            }

            if ($Setting.Type -eq "DWord") {
                New-ItemProperty -Path $Setting.Path -Name $Setting.Name -Value ([int]$desired) -PropertyType DWord -Force | Out-Null
            } elseif ($Setting.Type -eq "String") {
                New-ItemProperty -Path $Setting.Path -Name $Setting.Name -Value ([string]$desired) -PropertyType String -Force | Out-Null
            }

            $verify = Get-RegValueSafe -Path $Setting.Path -Name $Setting.Name
            $verifyOk = $false
            if ($verify.Exists) {
                $verifyOk = Test-ValueEquals -A $verify.Value -B $desired -Type $Setting.Type
            }

            if ($verifyOk) {
                Add-Result $Setting.Category $Setting.Description "Changed" $current $desired $Setting.Path $Setting.Name $Setting.Confidence $supportText "Value written and verified."
                Write-ResultLine "Changed" $Setting.Category $Setting.Description $current $desired "Written and verified."
            } else {
                Add-Result $Setting.Category $Setting.Description "VerifyFail" $verify.Value $desired $Setting.Path $Setting.Name $Setting.Confidence $supportText "Value write attempted, but verification failed."
                Write-ResultLine "VerifyFail" $Setting.Category $Setting.Description $verify.Value $desired "Write attempted but verify failed."
            }
        } catch {
            Add-Result $Setting.Category $Setting.Description "Error" $current $desired $Setting.Path $Setting.Name $Setting.Confidence $supportText $_.Exception.Message
            Write-ResultLine "Error" $Setting.Category $Setting.Description $current $desired $_.Exception.Message
        }
    }
}

function Export-RegKeySafe {
    param(
        [Parameter(Mandatory=$true)][string]$RegPath,
        [Parameter(Mandatory=$true)][string]$FileName
    )

    $outFile = Join-Path $script:ReportDir $FileName

    cmd /c "reg query `"$RegPath`" >nul 2>&1"
    if ($LASTEXITCODE -eq 0) {
        cmd /c "reg export `"$RegPath`" `"$outFile`" /y >nul 2>&1"
        if ($LASTEXITCODE -eq 0) {
            Add-Result "Backup" "Registry export: $RegPath" "Changed" "" "" $RegPath "" "Official" "Backup" "Exported to: $FileName"
            Write-Host "Exported registry backup: $RegPath" -ForegroundColor Green
        } else {
            Add-Result "Backup" "Registry export: $RegPath" "Warning" "" "" $RegPath "" "Official" "Backup" "reg export failed."
            Write-Host "WARNING: Could not export $RegPath" -ForegroundColor Yellow
        }
    } else {
        Add-Result "Backup" "Registry export: $RegPath" "Skipped" "" "" $RegPath "" "Official" "Backup" "Registry key not found."
        Write-Host "Registry key not found, skipped backup: $RegPath" -ForegroundColor DarkYellow
    }
}

function Invoke-RegistryBackup {
    if ($Mode -ne "Apply") { return }

    Write-Section "Registry backup"

    $backupKeys = @(
        "HKLM\SOFTWARE\Policies\Microsoft\Windows",
        "HKCU\SOFTWARE\Policies\Microsoft\Windows",
        "HKLM\SOFTWARE\Policies\Microsoft\Dsh",
        "HKLM\SOFTWARE\Policies\Microsoft\Edge",
        "HKLM\SOFTWARE\Policies\Microsoft\Windows\Appx",
        "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock",
        "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced",
        "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager",
        "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo",
        "HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy",
        "HKCU\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement",
        "HKCU\Software\Microsoft\Siuf\Rules",
        "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR",
        "HKCU\System\GameConfigStore",
        "HKCU\Software\Microsoft\GameBar",
        "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem",
        "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power",
        "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies",
        "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings",
        "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore"
    )

    foreach ($key in $backupKeys) {
        $fileName = ($key -replace '[\\/:*?"<>| ]', '_') + ".reg"
        Export-RegKeySafe -RegPath $key -FileName $fileName
    }
}

function ConvertTo-RegFileHivePath {
    param([string]$PsPath)

    # Convert "HKLM:\SOFTWARE\..." or "HKCU:\Software\..." to .reg hive notation.
    $p = $PsPath -replace '^HKLM:\\', 'HKEY_LOCAL_MACHINE\'
    $p = $p     -replace '^HKCU:\\', 'HKEY_CURRENT_USER\'
    $p = $p     -replace '^HKCR:\\', 'HKEY_CLASSES_ROOT\'
    $p = $p     -replace '^HKU:\\',  'HKEY_USERS\'
    return $p
}

function Format-RegValueLine {
    param(
        [string]$Name,
        [string]$Type,
        [object]$Value,
        [bool]$Delete
    )

    # Value name escaping for .reg: backslash and double-quote.
    $escapedName = ($Name -replace '\\', '\\') -replace '"', '\"'

    if ($Delete) {
        return "`"$escapedName`"=-"
    }

    if ($Type -eq "DWord") {
        $dword = ('{0:x8}' -f [int]$Value)
        return "`"$escapedName`"=dword:$dword"
    }

    # String (REG_SZ)
    $escapedValue = ([string]$Value -replace '\\', '\\') -replace '"', '\"'
    return "`"$escapedName`"=`"$escapedValue`""
}

function Write-RollbackRegFile {
    if ($Mode -ne "Apply") { return }
    if ($script:RollbackEntries.Count -eq 0) { return }

    $rollbackPath = Join-Path $script:ReportDir "rollback.reg"

    $lines = New-Object 'System.Collections.Generic.List[string]'
    $lines.Add("Windows Registry Editor Version 5.00") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("; Auto-generated rollback for Win11 25H2 Calm Mode.") | Out-Null
    $lines.Add("; Restores each value changed in this Apply run to its prior state.") | Out-Null
    $lines.Add("; Values that did not exist before are removed (=-).") | Out-Null
    $lines.Add("; Note: this does not recreate registry keys that the script created.") | Out-Null
    $lines.Add("") | Out-Null

    # Group by key so each [key] header is written once.
    $byKey = $script:RollbackEntries | Group-Object Path
    foreach ($group in $byKey) {
        $hivePath = ConvertTo-RegFileHivePath $group.Name
        $lines.Add("[$hivePath]") | Out-Null

        foreach ($entry in $group.Group) {
            if ($entry.Existed) {
                $lines.Add((Format-RegValueLine -Name $entry.Name -Type $entry.Type -Value $entry.OldValue -Delete $false)) | Out-Null
            } else {
                $lines.Add((Format-RegValueLine -Name $entry.Name -Type $entry.Type -Value $null -Delete $true)) | Out-Null
            }
        }

        $lines.Add("") | Out-Null
    }

    try {
        # .reg files must be ANSI or UTF-16 LE; UTF-16 LE is safest for regedit import.
        $lines | Out-File -FilePath $rollbackPath -Encoding Unicode
        Add-Result "Backup" "Rollback file" "Changed" "" $rollbackPath "" "" "Official" "Backup" "Per-value rollback.reg generated. Double-click to restore prior values."
        Write-Host "Rollback file written: $rollbackPath" -ForegroundColor Green
    } catch {
        Add-Result "Backup" "Rollback file" "Warning" "" $rollbackPath "" "" "Official" "Backup" "Could not write rollback.reg: $($_.Exception.Message)"
        Write-Host "WARNING: Could not write rollback.reg: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Invoke-RestorePoint {
    if ($Mode -ne "Apply") { return }
    if ($SkipRestorePoint) {
        Add-Result "Preflight" "Restore point" "Skipped" "" "" "" "" "Official" "Supported" "Skipped by -SkipRestorePoint."
        return
    }

    Write-Section "Restore point"

    if (-not $PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Create System Restore point")) {
        Add-Result "Preflight" "Restore point" "Skipped" "" "" "" "" "Official" "Supported" "Skipped by -WhatIf/-Confirm."
        return
    }

    # Windows throttles restore points to one per 24h by default via
    # SystemRestorePointCreationFrequency. Temporarily set it to 0 so our
    # checkpoint is not silently skipped, then restore the prior value.
    $srKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore"
    $freqRead = Get-RegValueSafe -Path $srKey -Name "SystemRestorePointCreationFrequency"
    $freqChanged = $false
    try {
        if (-not (Test-Path $srKey)) { New-Item -Path $srKey -Force | Out-Null }
        New-ItemProperty -Path $srKey -Name "SystemRestorePointCreationFrequency" -Value 0 -PropertyType DWord -Force | Out-Null
        $freqChanged = $true
    } catch { Write-Verbose "Ignored non-critical error: $($_.Exception.Message)" }

    try {
        Checkpoint-Computer -Description "Before $script:ScriptTitle" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Add-Result "Preflight" "Restore point" "Changed" "" "" "" "" "Official" "Supported" "Restore point created."
        Write-Host "Restore point created." -ForegroundColor Green
    } catch {
        $msg = $_.Exception.Message
        $hint = "System Protection may be disabled for the system drive. Enable it: Settings > System > About > System protection, or run 'Enable-ComputerRestore -Drive C:\\'. A rollback.reg is still generated as a fallback."
        if ($msg -match "1440|frequency|already") {
            $hint = "Windows allows only one restore point per 24h by default and one may already exist for today. The script's per-value rollback.reg still provides a fallback."
        }
        Add-Result "Preflight" "Restore point" "Warning" "" "" "" "" "Official" "Supported" "Restore point was not created: $msg $hint"
        Write-Host "WARNING: Restore point was not created. $hint" -ForegroundColor Yellow
    } finally {
        # Restore the original throttling value to avoid leaving the system more permissive.
        try {
            if ($freqChanged) {
                if ($freqRead.Exists) {
                    New-ItemProperty -Path $srKey -Name "SystemRestorePointCreationFrequency" -Value ([int]$freqRead.Value) -PropertyType DWord -Force | Out-Null
                } else {
                    Remove-ItemProperty -Path $srKey -Name "SystemRestorePointCreationFrequency" -ErrorAction SilentlyContinue
                }
            }
        } catch { Write-Verbose "Ignored non-critical error: $($_.Exception.Message)" }
    }
}

function Get-AppxMatches {
    param([string[]]$Patterns)

    $current = @()
    $allUsers = @()
    $provisioned = @()

    foreach ($pattern in $Patterns) {
        try {
            $current += Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object {
                $_.Name -like $pattern -or $_.PackageFullName -like $pattern
            }
        } catch { Write-Verbose "Ignored non-critical error: $($_.Exception.Message)" }

        try {
            $allUsers += Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object {
                $_.Name -like $pattern -or $_.PackageFullName -like $pattern
            }
        } catch { Write-Verbose "Ignored non-critical error: $($_.Exception.Message)" }

        try {
            $provisioned += Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object {
                $_.DisplayName -like $pattern -or $_.PackageName -like $pattern
            }
        } catch { Write-Verbose "Ignored non-critical error: $($_.Exception.Message)" }
    }

    return [pscustomobject]@{
        CurrentUser = @($current | Sort-Object PackageFullName -Unique)
        AllUsers = @($allUsers | Sort-Object PackageFullName -Unique)
        Provisioned = @($provisioned | Sort-Object PackageName -Unique)
    }
}

function Invoke-AppCleanupTarget {
    param(
        [string]$Name,
        [string[]]$Patterns,
        [bool]$Enabled
    )

    if (-not $Enabled) {
        Add-Result "Appx Cleanup" $Name "Skipped" "" "Absent" "" "" "BestEffort" "DisabledByConfig" "This cleanup target is disabled in script toggles."
        return
    }

    if ($NoAppCleanup) {
        Add-Result "Appx Cleanup" $Name "Skipped" "" "Absent" "" "" "BestEffort" "SkippedBySwitch" "Skipped by -NoAppCleanup."
        return
    }

    $appxMatches = Get-AppxMatches -Patterns $Patterns
    $count = @($appxMatches.CurrentUser).Count + @($appxMatches.AllUsers).Count + @($appxMatches.Provisioned).Count
    $currentSummary = "CurrentUser=$(@($appxMatches.CurrentUser).Count); AllUsers=$(@($appxMatches.AllUsers).Count); Provisioned=$(@($appxMatches.Provisioned).Count)"

    if ($Mode -eq "Audit") {
        $status = if ($count -eq 0) { "Compliant" } else { "WouldRemove" }
        Add-Result "Appx Cleanup" $Name $status $currentSummary "Absent" "" "" "BestEffort" "BestEffort" "Audit only; no packages removed."
        Write-ResultLine $status "Appx Cleanup" $Name $currentSummary "Absent" "Audit only."
        return
    }

    if ($Mode -eq "Verify") {
        $status = if ($count -eq 0) { "VerifyOK" } else { "VerifyFail" }
        Add-Result "Appx Cleanup" $Name $status $currentSummary "Absent" "" "" "BestEffort" "BestEffort" "Verify Appx package absence."
        Write-ResultLine $status "Appx Cleanup" $Name $currentSummary "Absent" "Verify only."
        return
    }

    if ($Mode -eq "Apply") {
        if ($count -eq 0) {
            Add-Result "Appx Cleanup" $Name "AlreadyConfigured" $currentSummary "Absent" "" "" "BestEffort" "BestEffort" "No matching packages found."
            Write-ResultLine "AlreadyConfigured" "Appx Cleanup" $Name $currentSummary "Absent" "No matching packages."
            return
        }

        if (-not $PSCmdlet.ShouldProcess($Name, "Remove Appx package(s)")) {
            Add-Result "Appx Cleanup" $Name "Skipped" $currentSummary "Absent" "" "" "BestEffort" "BestEffort" "Skipped by -WhatIf/-Confirm."
            Write-ResultLine "Skipped" "Appx Cleanup" $Name $currentSummary "Absent" "Skipped (WhatIf/Confirm)."
            return
        }

        try {
            foreach ($pkg in $appxMatches.CurrentUser) {
                Write-Host "Removing current-user Appx: $($pkg.Name)" -ForegroundColor Yellow
                Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction SilentlyContinue
            }

            foreach ($pkg in $appxMatches.AllUsers) {
                try {
                    Write-Host "Attempting all-users Appx removal: $($pkg.Name)" -ForegroundColor Yellow
                    Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction SilentlyContinue
                } catch { Write-Verbose "Ignored non-critical error: $($_.Exception.Message)" }
            }

            foreach ($prov in $appxMatches.Provisioned) {
                Write-Host "Removing provisioned Appx: $($prov.DisplayName)" -ForegroundColor Yellow
                Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction SilentlyContinue | Out-Null
            }

            Start-Sleep -Seconds 1
            $after = Get-AppxMatches -Patterns $Patterns
            $afterCount = @($after.CurrentUser).Count + @($after.AllUsers).Count + @($after.Provisioned).Count
            $afterSummary = "CurrentUser=$(@($after.CurrentUser).Count); AllUsers=$(@($after.AllUsers).Count); Provisioned=$(@($after.Provisioned).Count)"

            if ($afterCount -eq 0) {
                Add-Result "Appx Cleanup" $Name "Changed" $currentSummary "Absent" "" "" "BestEffort" "BestEffort" "Packages removed and verified absent."
                Write-ResultLine "Changed" "Appx Cleanup" $Name $currentSummary "Absent" "Removed and verified."
            } else {
                Add-Result "Appx Cleanup" $Name "Warning" $afterSummary "Absent" "" "" "BestEffort" "BestEffort" "Some packages remain. This can happen for system/user-protected packages."
                Write-ResultLine "Warning" "Appx Cleanup" $Name $afterSummary "Absent" "Some packages remain."
            }
        } catch {
            Add-Result "Appx Cleanup" $Name "Error" $currentSummary "Absent" "" "" "BestEffort" "BestEffort" $_.Exception.Message
            Write-ResultLine "Error" "Appx Cleanup" $Name $currentSummary "Absent" $_.Exception.Message
        }
    }
}

function Invoke-ExeCleanupTarget {
    param(
        [string]$Name,
        [string[]]$ExePaths,
        [string]$VerifyExePath,
        [string]$UninstallArgs,
        [bool]$Enabled
    )

    if (-not $Enabled) {
        Add-Result "App Cleanup" $Name "Skipped" "" "Absent" "" "" "BestEffort" "DisabledByConfig" "This cleanup target is disabled in script toggles."
        return
    }

    if ($NoAppCleanup) {
        Add-Result "App Cleanup" $Name "Skipped" "" "Absent" "" "" "BestEffort" "SkippedBySwitch" "Skipped by -NoAppCleanup."
        return
    }

    $isInstalled = $false
    $foundExe = $null
    foreach ($path in $ExePaths) {
        if (Test-Path $path) {
            $isInstalled = $true
            $foundExe = $path
            break
        }
    }

    if ($Mode -eq "Audit") {
        $status = if ($isInstalled) { "WouldRemove" } else { "Compliant" }
        Add-Result "App Cleanup" $Name $status $isInstalled "False" "" "" "BestEffort" "BestEffort" "Audit only."
        Write-ResultLine $status "App Cleanup" $Name $isInstalled "False" "Audit only."
        return
    }

    if ($Mode -eq "Verify") {
        $exists = Test-Path $VerifyExePath
        $status = if (-not $exists) { "VerifyOK" } else { "VerifyFail" }
        Add-Result "App Cleanup" $Name $status $exists "False" $VerifyExePath "" "BestEffort" "BestEffort" "Verify exe absence."
        Write-ResultLine $status "App Cleanup" $Name $exists "False" "Verify only."
        return
    }

    if ($Mode -eq "Apply") {
        if (-not $PSCmdlet.ShouldProcess($Name, "Uninstall")) {
            Add-Result "App Cleanup" $Name "Skipped" "" "Uninstalled" "" "" "BestEffort" "BestEffort" "Skipped by -WhatIf/-Confirm."
            Write-ResultLine "Skipped" "App Cleanup" $Name "" "Uninstalled" "Skipped (WhatIf/Confirm)."
            return
        }

        try {
            if ($isInstalled) {
                Start-Process $foundExe $UninstallArgs -Wait -ErrorAction SilentlyContinue
                Add-Result "App Cleanup" $Name "Changed" "Installed" "Uninstalled" $foundExe "" "BestEffort" "BestEffort" "Uninstall command executed."
            } else {
                Add-Result "App Cleanup" $Name "AlreadyConfigured" "Not found" "Uninstalled" "" "" "BestEffort" "BestEffort" "Exe not found."
            }
        } catch {
            Add-Result "App Cleanup" $Name "Error" "Unknown" "Uninstalled" "" "" "BestEffort" "BestEffort" $_.Exception.Message
        }
    }
}

function Invoke-AppCleanup {
    Write-Section "App cleanup"

    Invoke-AppCleanupTarget -Name "Microsoft Copilot app" -Patterns @("*Copilot*", "Microsoft.Copilot*") -Enabled $RemoveCopilotApp
    Invoke-AppCleanupTarget -Name "Microsoft Teams personal" -Patterns @("MSTeams*", "MicrosoftTeams*") -Enabled $RemoveTeamsPersonal
    Invoke-AppCleanupTarget -Name "Xbox apps" -Patterns @("Microsoft.Xbox*", "Microsoft.GamingApp*", "Microsoft.XboxGamingOverlay*", "Microsoft.XboxGameOverlay*", "Microsoft.XboxIdentityProvider*", "Microsoft.XboxSpeechToTextOverlay*") -Enabled $RemoveXboxApps

    Invoke-ExeCleanupTarget -Name "OneDrive uninstall" -ExePaths @("$env:SystemRoot\System32\OneDriveSetup.exe", "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") -VerifyExePath (Join-Path $env:LOCALAPPDATA "Microsoft\OneDrive\OneDrive.exe") -UninstallArgs "/uninstall" -Enabled $RemoveOneDrive
}

function Add-PreflightResults {
    Write-Section "Preflight"

    # Windows 11 is best detected by build number. On many Windows 11 builds, the legacy
    # ProductName registry value can still say "Windows 10 Pro".
    $isWindows11 = ($script:BuildNumber -ge 22000)
    $versionMessage = "ProductName=$script:ProductName; DisplayVersion=$script:DisplayVersion; Build=$script:BuildNumber; UBR=$script:UBR; EditionId=$script:EditionId; EditionGroup=$script:EditionGroup"

    $status = if ($isWindows11) { "Compliant" } else { "Warning" }
    $versionCheckMessage = if ($isWindows11) { "Windows 11 detected by build number >= 22000. ProductName can be a legacy value." } else { "Build number is below 22000; this does not look like Windows 11." }
    Add-Result "Preflight" "Windows version" $status $versionMessage "Windows 11 $TargetReleaseVersionInfo" "" "" "Official" "Detected" $versionCheckMessage
    Write-ResultLine $status "Preflight" "Windows version" $versionMessage "Windows 11 $TargetReleaseVersionInfo" $versionCheckMessage

    $targetStatus = if ($script:DisplayVersion -eq $TargetReleaseVersionInfo) { "Compliant" } else { "Warning" }
    Add-Result "Preflight" "Target release match" $targetStatus $script:DisplayVersion $TargetReleaseVersionInfo "" "" "Official" "Detected" "If this is not 25H2, adjust -TargetReleaseVersionInfo or do not use TargetReleaseVersion pinning."
    Write-ResultLine $targetStatus "Preflight" "Target release match" $script:DisplayVersion $TargetReleaseVersionInfo "Check target version."

    $adminStatus = if ($script:CurrentUserIsAdmin) { "Compliant" } else { "Warning" }
    Add-Result "Preflight" "Administrator" $adminStatus $script:CurrentUserIsAdmin "True for Apply" "" "" "Official" "Detected" "Apply mode requires Administrator."
    Write-ResultLine $adminStatus "Preflight" "Administrator" $script:CurrentUserIsAdmin "True for Apply" ""

    # Per-user (HKCU) tweaks land in the hive of whoever runs the script. If that is not
    # the interactive user (for example, a separate elevated account), those tweaks miss
    # the signed-in profile while the report would still say Changed. Warn explicitly.
    $hkcuStatus = "Compliant"
    $hkcuMsg = "Per-user (HKCU) settings apply to the account running this script: $script:CurrentIdentityName."
    if (-not [string]::IsNullOrWhiteSpace($script:InteractiveUser) -and
        -not [string]::IsNullOrWhiteSpace($script:CurrentIdentityName) -and
        $script:InteractiveUser -ne $script:CurrentIdentityName) {
        $hkcuStatus = "Warning"
        $hkcuMsg = "Script identity ($script:CurrentIdentityName) differs from the interactive user ($script:InteractiveUser). Per-user (HKCU) settings will be written to '$script:CurrentIdentityName', NOT the signed-in user. Run as your own account with elevation so HKCU tweaks reach the right profile."
    }
    Add-Result "Preflight" "Per-user hive (HKCU)" $hkcuStatus $script:CurrentIdentityName $script:InteractiveUser "" "" "Official" "Detected" $hkcuMsg
    Write-ResultLine $hkcuStatus "Preflight" "Per-user hive (HKCU)" $script:CurrentIdentityName $script:InteractiveUser $hkcuMsg
}

function Initialize-RegistrySettings {
    # ---------------- Windows AI / Recall / Copilot ----------------
    if ($EnableWindowsAIBlock) {
        $WindowsAI_HKLM = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
        $WindowsAI_HKCU = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
        $WindowsCopilot_HKCU = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
        $PaintPolicies_HKLM = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint"

        Add-RegSetting "Windows AI" $WindowsAI_HKLM "AllowRecallEnablement" "DWord" 0 "Make Recall optional component unavailable" 26100 @("Pro","Enterprise","Education","IoTEnterprise") "Official" "WindowsAI policy; prevents users from enabling Recall where supported." $true 3915
        Add-RegSetting "Windows AI" $WindowsAI_HKLM "DisableAIDataAnalysis" "DWord" 1 "Disable Recall snapshot saving / AI data analysis" 26100 @("Pro","Enterprise","Education","IoTEnterprise") "Official" "WindowsAI policy." $true 3915
        Add-RegSetting "Windows AI" $WindowsAI_HKCU "DisableAIDataAnalysis" "DWord" 1 "Disable Recall snapshot saving for current user" 26100 @("Pro","Enterprise","Education","IoTEnterprise") "Official" "User-scoped WindowsAI policy." $true 3915
        Add-RegSetting "Windows AI" $WindowsAI_HKLM "AllowRecallExport" "DWord" 0 "Block Recall export where supported" 26100 @("Pro","Enterprise","Education","IoTEnterprise") "RequiresVerification" "WindowsAI policy where supported."

        Add-RegSetting "Windows AI" $WindowsAI_HKLM "DisableClickToDo" "DWord" 1 "Disable Click to Do" 26100 @("Pro","Enterprise","Education","IoTEnterprise") "RequiresVerification" "WindowsAI policy."
        Add-RegSetting "Windows AI" $WindowsAI_HKCU "DisableClickToDo" "DWord" 1 "Disable Click to Do for current user" 26100 @("Pro","Enterprise","Education","IoTEnterprise") "RequiresVerification" "User-scoped WindowsAI policy."
        Add-RegSetting "Windows AI" $WindowsAI_HKLM "DisableSettingsAgent" "DWord" 1 "Disable AI agent/search in Settings where supported" 26100 @("Enterprise","Education","IoTEnterprise") "RequiresVerification" "Policy name is not fully confirmed across builds/regions/editions. Verify with gpresult or the registry after Apply before relying on it."

        Add-RegSetting "Windows AI" $PaintPolicies_HKLM "DisableCocreator" "DWord" 1 "Disable Paint Cocreator" 26100 @("Pro","Enterprise","Education","IoTEnterprise") "Official" "Paint AI policy." $true 3360
        Add-RegSetting "Windows AI" $PaintPolicies_HKLM "DisableGenerativeFill" "DWord" 1 "Disable Paint Generative Fill" 26100 @("Pro","Enterprise","Education","IoTEnterprise") "Official" "Paint AI policy." $true 3360
        Add-RegSetting "Windows AI" $PaintPolicies_HKLM "DisableImageCreator" "DWord" 1 "Disable Paint Image Creator" 26100 @("Pro","Enterprise","Education","IoTEnterprise") "Official" "Paint AI policy." $true 3360

        Add-RegSetting "Copilot" $WindowsCopilot_HKCU "TurnOffWindowsCopilot" "DWord" 1 "Turn off legacy Windows Copilot" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Deprecated" "Microsoft marks this old Copilot policy as deprecated; kept for legacy behavior."
        Add-RegSetting "Copilot" "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCopilotButton" "DWord" 0 "Hide Copilot taskbar button if present" 22000 @() "UISetting" "Explorer UI setting; build-dependent."
        Add-RegSetting "Copilot" $WindowsAI_HKLM "RemoveMicrosoftCopilotApp" "DWord" 1 "Request Microsoft Copilot app removal where supported" 26100 @("Pro","Enterprise","Education","IoTEnterprise") "BestEffort" "Policy availability/behavior can vary by build and Copilot package state."
        Add-RegSetting "Copilot" $WindowsAI_HKCU "RemoveMicrosoftCopilotApp" "DWord" 1 "Request Microsoft Copilot app removal for current user where supported" 26100 @("Pro","Enterprise","Education","IoTEnterprise") "BestEffort" "User-scoped best-effort Copilot app removal policy."
    }

    # ---------------- Widgets / News / Weather ----------------
    if ($EnableWidgetsBlock) {
        $Dsh_HKLM = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
        Add-RegSetting "Widgets" $Dsh_HKLM "AllowNewsAndInterests" "DWord" 0 "Disable Widgets / News and Interests" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" "Policy-backed Widgets disable."
        Add-RegSetting "Widgets" $Dsh_HKLM "DisableWidgetsBoard" "DWord" 1 "Disable Widgets board where supported" 26100 @("Pro","Enterprise","Education","IoTEnterprise") "RequiresVerification" "Newer Widgets policy; may be Insider/build-dependent and not fully documented. Verify after Apply."
        Add-RegSetting "Widgets" $Dsh_HKLM "DisableWidgetsOnLockScreen" "DWord" 1 "Disable Widgets on lock screen where supported" 26100 @("Pro","Enterprise","Education","IoTEnterprise") "RequiresVerification" "Newer Widgets policy; may be Insider/build-dependent and not fully documented. Verify after Apply."
        Add-RegSetting "Widgets" "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa" "DWord" 0 "Hide Widgets button on taskbar" 22000 @() "UISetting" "Explorer taskbar UI setting."
    }

    # ---------------- Cloud Content / Consumer Experience ----------------
    if ($EnableCloudContentBlock) {
        $CloudContent_HKLM = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
        $CloudContent_HKCU = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"

        Add-RegSetting "Cloud Content" $CloudContent_HKLM "DisableWindowsConsumerFeatures" "DWord" 1 "Disable Windows consumer experiences" 22000 @("Enterprise","Education","IoTEnterprise") "Official" "Microsoft documents some CloudContent policies as Enterprise/Education/IoT only; Pro may ignore."
        Add-RegSetting "Cloud Content" $CloudContent_HKLM "DisableSoftLanding" "DWord" 1 "Disable soft landing tips/prompts" 22000 @("Enterprise","Education","IoTEnterprise") "Official" "May be ignored on Pro/Home."
        Add-RegSetting "Cloud Content" $CloudContent_HKLM "DisableCloudOptimizedContent" "DWord" 1 "Disable cloud optimized content" 22000 @("Enterprise","Education","IoTEnterprise") "Official" "May be ignored on Pro/Home."
        Add-RegSetting "Cloud Content" $CloudContent_HKLM "DisableConsumerAccountStateContent" "DWord" 1 "Disable Microsoft account state consumer content" 22000 @("Enterprise","Education","IoTEnterprise") "Official" "May be ignored on Pro/Home."

        Add-RegSetting "Cloud Content" $CloudContent_HKCU "DisableWindowsSpotlightFeatures" "DWord" 1 "Disable Windows Spotlight features" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" ""
        Add-RegSetting "Cloud Content" $CloudContent_HKCU "DisableWindowsSpotlightOnActionCenter" "DWord" 1 "Disable Spotlight in Action Center" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" ""
        Add-RegSetting "Cloud Content" $CloudContent_HKCU "DisableWindowsSpotlightOnSettings" "DWord" 1 "Disable Spotlight suggestions in Settings" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" ""
        Add-RegSetting "Cloud Content" $CloudContent_HKCU "DisableWindowsSpotlightWindowsWelcomeExperience" "DWord" 1 "Disable Windows welcome experience after updates" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" ""
        Add-RegSetting "Cloud Content" $CloudContent_HKCU "DisableThirdPartySuggestions" "DWord" 1 "Disable third-party suggestions" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" ""
        Add-RegSetting "Cloud Content" $CloudContent_HKCU "DisableTailoredExperiencesWithDiagnosticData" "DWord" 1 "Disable tailored experiences with diagnostic data" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" ""

        $CDM_HKCU = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        $cdmSettings = @(
            "ContentDeliveryAllowed",
            "OemPreInstalledAppsEnabled",
            "PreInstalledAppsEnabled",
            "PreInstalledAppsEverEnabled",
            "SilentInstalledAppsEnabled",
            "SystemPaneSuggestionsEnabled",
            "SoftLandingEnabled",
            "RotatingLockScreenEnabled",
            "RotatingLockScreenOverlayEnabled",
            "SubscribedContentEnabled",
            "SubscribedContent-310093Enabled",
            "SubscribedContent-338387Enabled",
            "SubscribedContent-338388Enabled",
            "SubscribedContent-338389Enabled",
            "SubscribedContent-338393Enabled",
            "SubscribedContent-353694Enabled",
            "SubscribedContent-353696Enabled"
        )

        foreach ($name in $cdmSettings) {
            Add-RegSetting "Cloud Content UI" $CDM_HKCU $name "DWord" 0 "Disable ContentDeliveryManager setting: $name" 22000 @() "UISetting" "Current-user UI/preference setting; exact behavior can vary by build."
        }

        Add-RegSetting "Cloud Content UI" "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" "ScoobeSystemSettingEnabled" "DWord" 0 "Disable 'Get even more out of Windows' post-OOBE prompt" 22000 @() "UISetting" ""
    }

    # ---------------- Privacy / Diagnostics / Advertising ----------------
    if ($EnablePrivacyBlock) {
        Add-RegSetting "Privacy" "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" "DisabledByGroupPolicy" "DWord" 1 "Disable Advertising ID by policy" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" ""
        Add-RegSetting "Privacy" "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" "DWord" 0 "Disable Advertising ID for current user" 22000 @() "UISetting" ""
        Add-RegSetting "Privacy" "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" "DWord" $TelemetryLevel "Set diagnostic data level (AllowTelemetry=$TelemetryLevel)" 22000 @("Home","Pro","Enterprise","Education","IoTEnterprise") "Official" "On Pro/Home, 1 means Required diagnostic data; 0 (Security/Off) is honored only on Enterprise/Education/IoT. Configurable via -TelemetryLevel."
        Add-RegSetting "Privacy" "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" "TailoredExperiencesWithDiagnosticDataEnabled" "DWord" 0 "Disable tailored experiences" 22000 @() "UISetting" ""
        Add-RegSetting "Privacy" "HKCU:\Software\Microsoft\Siuf\Rules" "NumberOfSIUFInPeriod" "DWord" 0 "Disable feedback frequency prompts" 22000 @() "UISetting" ""
        Add-RegSetting "Privacy" "HKCU:\Software\Microsoft\Siuf\Rules" "PeriodInNanoSeconds" "DWord" 0 "Disable feedback prompt period" 22000 @() "UISetting" ""
    }

    # ---------------- Search ----------------
    if ($EnableSearchBlock) {
        $Search_HKLM = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        Add-RegSetting "Search" $Search_HKLM "EnableDynamicContentInWSB" "DWord" 0 "Disable Search highlights / dynamic content in Windows Search Box" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" ""
        Add-RegSetting "Search" $Search_HKLM "AllowCloudSearch" "DWord" 0 "Disable cloud search integration in Windows Search" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" ""
        Add-RegSetting "Search" $Search_HKLM "AllowSearchToUseLocation" "DWord" 0 "Disable location-aware Windows Search" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" ""
        Add-RegSetting "Search" $Search_HKLM "DisableWebSearch" "DWord" 1 "Disable web search where policy is honored" 22000 @("Enterprise","Education","IoTEnterprise") "Official" "Historically not always honored on Pro; marked as maybe ignored outside Enterprise/Education/IoT."
        Add-RegSetting "Search" $Search_HKLM "DoNotUseWebResults" "DWord" 1 "Do not use web results in Search where policy is honored" 22000 @("Enterprise","Education","IoTEnterprise") "Official" "Historically not always honored on Pro; marked as maybe ignored outside Enterprise/Education/IoT."
        Add-RegSetting "Search" "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions" "DWord" 1 "Disable Search box suggestions in Explorer/Start" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" ""
    }

    # ---------------- Start Menu / Taskbar / Explorer ----------------
    if ($EnableStartTaskbarBlock) {
        $ExplorerPolicy_HKLM = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
        $ExplorerPolicy_HKCU = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
        $ExplorerAdvanced_HKCU = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

        Add-RegSetting "Start" $ExplorerPolicy_HKLM "HideRecommendedSection" "DWord" 1 "Hide Recommended section in Start where supported" 22000 @("Enterprise","Education","IoTEnterprise") "Official" "Microsoft limits some Start policies by edition; Pro may ignore."
        Add-RegSetting "Start" $ExplorerPolicy_HKCU "HideRecommendedSection" "DWord" 1 "Hide Recommended section in Start for current user where supported" 22000 @("Enterprise","Education","IoTEnterprise") "Official" "May be ignored on Pro/Home."
        Add-RegSetting "Start" $ExplorerPolicy_HKLM "HideRecommendedPersonalizedSites" "DWord" 1 "Hide recommended personalized sites" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" ""
        Add-RegSetting "Start" $ExplorerPolicy_HKCU "HideRecommendedPersonalizedSites" "DWord" 1 "Hide recommended personalized sites for current user" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" ""
        Add-RegSetting "Start" $ExplorerPolicy_HKLM "HideRecentlyAddedApps" "DWord" 1 "Hide recently added apps" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" ""
        Add-RegSetting "Start" $ExplorerPolicy_HKCU "HideRecentlyAddedApps" "DWord" 1 "Hide recently added apps for current user" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" ""
        Add-RegSetting "Start" $ExplorerPolicy_HKLM "HideFrequentlyUsedApps" "DWord" 1 "Hide frequently used apps" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" ""
        Add-RegSetting "Start" $ExplorerPolicy_HKCU "HideFrequentlyUsedApps" "DWord" 1 "Hide frequently used apps for current user" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" ""

        if ($SetTaskbarLeft) {
            Add-RegSetting "Taskbar" $ExplorerAdvanced_HKCU "TaskbarAl" "DWord" 0 "Align taskbar to left" 22000 @() "UISetting" ""
        }

        $searchModeValue = 1
        if ($SearchMode -eq "Hidden") { $searchModeValue = 0 }
        if ($SearchMode -eq "Icon") { $searchModeValue = 1 }
        if ($SearchMode -eq "Box") { $searchModeValue = 2 }

        Add-RegSetting "Taskbar" $ExplorerAdvanced_HKCU "SearchboxTaskbarMode" "DWord" $searchModeValue "Set taskbar search mode to $SearchMode" 22000 @() "UISetting" ""
        Add-RegSetting "Taskbar" $ExplorerAdvanced_HKCU "ShowTaskViewButton" "DWord" 0 "Hide Task View button" 22000 @() "UISetting" ""
        # TaskbarDa is already covered in the Widgets block. Do not register it twice,
        # because Windows 11 25H2 may omit this UI value when Widgets are disabled by policy.
        Add-RegSetting "Taskbar" $ExplorerAdvanced_HKCU "TaskbarMn" "DWord" 0 "Hide Chat/Teams consumer button if present" 22000 @() "UISetting" ""
        Add-RegSetting "Start" $ExplorerAdvanced_HKCU "Start_TrackDocs" "DWord" 0 "Do not track recent documents in Start/Jump Lists" 22000 @() "UISetting" ""
        Add-RegSetting "Start" $ExplorerAdvanced_HKCU "Start_TrackProgs" "DWord" 0 "Do not track frequently used programs" 22000 @() "UISetting" ""
        Add-RegSetting "Start" $ExplorerAdvanced_HKCU "Start_IrisRecommendations" "DWord" 0 "Disable Start recommendations UI toggle where supported" 22000 @() "UISetting" ""
        Add-RegSetting "Explorer" $ExplorerAdvanced_HKCU "HideFileExt" "DWord" 0 "Show file extensions in Explorer" 22000 @() "UISetting" ""
        Add-RegSetting "Explorer" $ExplorerAdvanced_HKCU "ShowSyncProviderNotifications" "DWord" 0 "Disable sync provider notifications in Explorer" 22000 @() "UISetting" ""
        Add-RegSetting "Explorer" $ExplorerAdvanced_HKCU "LaunchTo" "DWord" 1 "Open Explorer to This PC" 22000 @() "UISetting" ""
    }

    # ---------------- Windows Update ----------------
    if ($EnableWindowsUpdateBlock) {
        $WU_HKLM = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        $AU_HKLM = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"

        Add-RegSetting "Windows Update" $AU_HKLM "NoAutoUpdate" "DWord" 0 "Keep Windows Update enabled" 22000 @("Home","Pro","Enterprise","Education","IoTEnterprise") "Official" "Does not disable the Windows Update service."
    if ($EnableManualWindowsUpdateMode) {
        Add-RegSetting "Windows Update" $AU_HKLM "AUOptions" "DWord" 2 "Notify before downloading and installing updates (manual updates)" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" "AUOptions=2 means Windows notifies before BOTH download and install, so updates become manual and security patches are not installed until the user acts. This does NOT disable Windows Update or its service; it only reduces update automation."
    }
        Add-RegSetting "Windows Update" $AU_HKLM "NoAutoRebootWithLoggedOnUsers" "DWord" 1 "Avoid auto-restart while user is logged on" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" "May be affected by modern Windows Update restart policies."
        Add-RegSetting "Windows Update" $WU_HKLM "ExcludeWUDriversInQualityUpdate" "DWord" 1 "Do not include drivers with Windows Updates" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" ""
        Add-RegSetting "Windows Update" $WU_HKLM "SetAllowOptionalContent" "DWord" 0 "Do not automatically receive optional updates / CFRs" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" ""
        Add-RegSetting "Windows Update" $WU_HKLM "DeferFeatureUpdates" "DWord" 1 "Enable feature update deferral" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" ""
        Add-RegSetting "Windows Update" $WU_HKLM "DeferFeatureUpdatesPeriodInDays" "DWord" $FeatureUpdateDeferralDays "Defer feature updates by $FeatureUpdateDeferralDays days" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" ""
        Add-RegSetting "Windows Update" $WU_HKLM "DeferQualityUpdates" "DWord" 1 "Enable quality update deferral" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" ""
        Add-RegSetting "Windows Update" $WU_HKLM "DeferQualityUpdatesPeriodInDays" "DWord" $QualityUpdateDeferralDays "Defer quality updates by $QualityUpdateDeferralDays days" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" ""
        Add-RegSetting "Windows Update" $WU_HKLM "ManagePreviewBuilds" "DWord" 0 "Disable Windows Insider preview build management by user" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" ""
        Add-RegSetting "Windows Update" $WU_HKLM "SetActiveHours" "DWord" 1 "Set active hours manually" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" ""
        Add-RegSetting "Windows Update" $WU_HKLM "ActiveHoursStart" "DWord" $ActiveHoursStart "Active hours start" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" ""
        Add-RegSetting "Windows Update" $WU_HKLM "ActiveHoursEnd" "DWord" $ActiveHoursEnd "Active hours end" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" ""
        if ($EnableTargetReleaseVersionPin) {
            # Opt-in only. Pinning can stop the device from moving off an end-of-service
            # release, which eventually blocks feature and security updates.
            Add-RegSetting "Windows Update" $WU_HKLM "TargetReleaseVersion" "DWord" 1 "Enable target release version pinning" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" "Opt-in via `$EnableTargetReleaseVersionPin. Can block updates once the pinned release reaches end of service."
            Add-RegSetting "Windows Update" $WU_HKLM "ProductVersion" "String" "Windows 11" "Target product version" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" "Opt-in via `$EnableTargetReleaseVersionPin."
            Add-RegSetting "Windows Update" $WU_HKLM "TargetReleaseVersionInfo" "String" $TargetReleaseVersionInfo "Pin Windows feature version to $TargetReleaseVersionInfo" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" "Opt-in via `$EnableTargetReleaseVersionPin. Pins the feature version to $TargetReleaseVersionInfo."
        }
        Add-RegSetting "Windows Update UI" "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "IsContinuousInnovationOptedIn" "DWord" 0 "Turn off 'Get latest updates as soon as available' UI toggle" 22000 @() "UISetting" "UI mirror/toggle; SetAllowOptionalContent is the policy-backed control."
    }

    # ---------------- Delivery Optimization ----------------
    if ($EnableDeliveryOptimization) {
        Add-RegSetting "Delivery Optimization" "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" "DODownloadMode" "DWord" 0 "Disable peer-to-peer Delivery Optimization" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" "0 = HTTP only; no peer-to-peer."
    }

    # ---------------- Edge Quiet Mode ----------------
    if ($EnableEdgeQuietMode) {
        $EdgePolicy_HKLM = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        Add-RegSetting "Microsoft Edge" $EdgePolicy_HKLM "StartupBoostEnabled" "DWord" 0 "Disable Edge Startup Boost" 22000 @("Home","Pro","Enterprise","Education","IoTEnterprise") "Official" "Microsoft Edge browser policy."
        Add-RegSetting "Microsoft Edge" $EdgePolicy_HKLM "BackgroundModeEnabled" "DWord" 0 "Do not keep Edge background apps running after close" 22000 @("Home","Pro","Enterprise","Education","IoTEnterprise") "Official" "Microsoft Edge browser policy."
        Add-RegSetting "Microsoft Edge" $EdgePolicy_HKLM "HideFirstRunExperience" "DWord" 1 "Hide Edge first-run experience" 22000 @("Home","Pro","Enterprise","Education","IoTEnterprise") "Official" "Microsoft Edge browser policy."
        Add-RegSetting "Microsoft Edge" $EdgePolicy_HKLM "LaunchEdgeOnWindowsStartupEnabled" "DWord" 0 "Do not launch Edge automatically at Windows startup" 22000 @("Home","Pro","Enterprise","Education","IoTEnterprise") "Official" "Microsoft Edge browser policy."
        Add-RegSetting "Microsoft Edge" $EdgePolicy_HKLM "PromotionalTabsEnabled" "DWord" 0 "Disable Edge promotional tabs" 22000 @("Home","Pro","Enterprise","Education","IoTEnterprise") "Deprecated" "Deprecated Edge policy; kept for legacy compatibility."
        Add-RegSetting "Microsoft Edge" $EdgePolicy_HKLM "HubsSidebarEnabled" "DWord" 0 "Disable Edge sidebar/hubs where supported" 22000 @("Home","Pro","Enterprise","Education","IoTEnterprise") "Official" "Microsoft Edge browser policy."
    }

    # ---------------- Developer Mode + Long Paths ----------------
    if ($EnableDeveloperMode) {
        $AppxPolicy_HKLM = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Appx"
        $AppModelUnlock_HKLM = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
        Add-RegSetting "Developer" $AppxPolicy_HKLM "AllowDevelopmentWithoutDevLicense" "DWord" 1 "Enable Developer Mode policy" 22000 @("Home","Pro","Enterprise","Education","IoTEnterprise") "Official" "SECURITY TRADE-OFF: Allows development without developer license."
        Add-RegSetting "Developer" $AppxPolicy_HKLM "AllowAllTrustedApps" "DWord" 1 "Allow all trusted apps / sideloading policy" 22000 @("Home","Pro","Enterprise","Education","IoTEnterprise") "Official" "SECURITY TRADE-OFF: Allows sideloading of apps."
        Add-RegSetting "Developer" $AppModelUnlock_HKLM "AllowDevelopmentWithoutDevLicense" "DWord" 1 "Enable Developer Mode UI compatibility key" 22000 @() "UISetting" "Compatibility/UI key used by Windows Developer settings."
        Add-RegSetting "Developer" $AppModelUnlock_HKLM "AllowAllTrustedApps" "DWord" 1 "Allow trusted apps UI compatibility key" 22000 @() "UISetting" "Compatibility/UI key used by Windows Developer settings."
    }

    if ($EnableLongPaths) {
        Add-RegSetting "Developer" "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "LongPathsEnabled" "DWord" 1 "Enable Win32 long paths" 14393 @("Home","Pro","Enterprise","Education","IoTEnterprise") "Official" "Apps also need to be longPathAware. Reboot recommended."
    }

    # ---------------- Fast Startup ----------------
    if ($DisableFastStartup) {
        Add-RegSetting "Power" "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" "DWord" 0 "Disable Fast Startup local setting" 22000 @("Home","Pro","Enterprise","Education","IoTEnterprise") "Official" "Does not disable hibernation itself."
        Add-RegSetting "Power" "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "HiberbootEnabled" "DWord" 0 "Do not require Fast Startup by policy" 22000 @("Pro","Enterprise","Education","IoTEnterprise") "Official" "ADMX WinInit Hiberboot policy. Disabled/not configured means local setting is used."
    }

    # ---------------- Gaming ----------------
    if ($EnableGamingTweaks) {
        Add-RegSetting "Gaming" "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" "DWord" 0 "Disable background capture / Game DVR" 22000 @() "UISetting" ""
        Add-RegSetting "Gaming" "HKCU:\System\GameConfigStore" "GameDVR_Enabled" "DWord" 0 "Disable Game DVR in GameConfigStore" 22000 @() "UISetting" ""
        Add-RegSetting "Gaming" "HKCU:\Software\Microsoft\GameBar" "ShowStartupPanel" "DWord" 0 "Hide Game Bar startup panel" 22000 @() "UISetting" ""
    }
}

function Invoke-AllRegistrySettings {
    Write-Section "Registry policy/settings $Mode"

    foreach ($setting in $script:RegistrySettings) {
        Invoke-RegSetting -Setting $setting
    }
}

function Invoke-GpUpdateAndExplorer {
    if ($Mode -ne "Apply") { return }

    Write-Section "Apply policy refresh"

    if (-not $PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Refresh Group Policy and restart Explorer")) {
        Add-Result "Apply" "Policy refresh" "Skipped" "" "" "" "" "Official" "Supported" "Skipped by -WhatIf/-Confirm."
        return
    }

    try {
        gpupdate /force | Out-Host
        if ($LASTEXITCODE -eq 0) {
            Add-Result "Apply" "gpupdate /force" "Changed" "" "" "" "" "Official" "Supported" "Group Policy update command executed."
        } else {
            Add-Result "Apply" "gpupdate /force" "Warning" "" "" "" "" "Official" "Supported" "gpupdate exited with code $LASTEXITCODE."
        }
    } catch {
        Add-Result "Apply" "gpupdate /force" "Warning" "" "" "" "" "Official" "Supported" "gpupdate failed: $($_.Exception.Message)"
    }

    try {
        $gpFile = Join-Path $script:ReportDir "gpresult.html"
        cmd /c "gpresult /h `"$gpFile`" /f >nul 2>&1"
        if (Test-Path $gpFile) {
            Add-Result "Report" "gpresult.html" "Changed" "" $gpFile "" "" "Official" "Supported" "gpresult report created."
        } else {
            Add-Result "Report" "gpresult.html" "Warning" "" $gpFile "" "" "Official" "Supported" "gpresult report was not created."
        }
    } catch {
        Add-Result "Report" "gpresult.html" "Warning" "" "" "" "" "Official" "Supported" "gpresult failed: $($_.Exception.Message)"
    }

    if (-not $NoRestartExplorer) {
        try {
            Write-Host "Restarting Explorer..." -ForegroundColor Cyan
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            Start-Process explorer.exe
            Add-Result "Apply" "Restart Explorer" "Changed" "" "" "" "" "UISetting" "Supported" "Explorer restarted to apply taskbar/start UI settings."
        } catch {
            Add-Result "Apply" "Restart Explorer" "Warning" "" "" "" "" "UISetting" "Supported" "Explorer restart failed: $($_.Exception.Message)"
        }
    } else {
        Add-Result "Apply" "Restart Explorer" "Skipped" "" "" "" "" "UISetting" "Supported" "Skipped by -NoRestartExplorer."
    }
}

function Write-Reports {
    Write-Section "Writing reports"

    $csvPath = Join-Path $script:ReportDir "$script:ScriptName-results.csv"
    $htmlPath = Join-Path $script:ReportDir "$script:ScriptName-report.html"
    $jsonPath = Join-Path $script:ReportDir "$script:ScriptName-results.json"

    try {
        $script:Results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    } catch {
        Write-Host "WARNING: CSV report failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    try {
        $script:Results | ConvertTo-Json -Depth 6 | Out-File -FilePath $jsonPath -Encoding UTF8
    } catch {
        Write-Host "WARNING: JSON report failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    $summary = $script:Results | Group-Object Status | Sort-Object Name | Select-Object Name, Count
    $summaryHtml = $summary | ConvertTo-Html -Fragment -PreContent "<h2>Status summary</h2>"
    $resultsHtml = $script:Results | Sort-Object Category, Item | ConvertTo-Html -Fragment -PreContent "<h2>Detailed results</h2>"

    $css = @"
<style>
body { font-family: Segoe UI, Arial, sans-serif; margin: 24px; line-height: 1.35; }
h1 { margin-bottom: 0; }
.meta { color: #555; margin-top: 6px; margin-bottom: 18px; }
table { border-collapse: collapse; width: 100%; margin: 12px 0 28px 0; font-size: 13px; }
th, td { border: 1px solid #ddd; padding: 6px 8px; vertical-align: top; }
th { background: #f3f3f3; text-align: left; }
tr:nth-child(even) { background: #fafafa; }
.note { background: #fff7d6; padding: 10px; border: 1px solid #f0d36a; border-radius: 6px; }
</style>
"@

    $encTitle = [System.Net.WebUtility]::HtmlEncode($script:ScriptTitle)
    $encProduct = [System.Net.WebUtility]::HtmlEncode($script:ProductName)
    $encReportDir = [System.Net.WebUtility]::HtmlEncode($script:ReportDir)

    $html = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>$encTitle Report</title>
$css
</head>
<body>
<h1>$encTitle Report</h1>
<div class="meta">
Mode: <b>$Mode</b><br>
Generated: <b>$(Get-Date)</b><br>
Product: <b>$encProduct</b><br>
DisplayVersion: <b>$script:DisplayVersion</b><br>
Build: <b>$script:BuildNumber.$script:UBR</b><br>
Edition: <b>$script:EditionId</b> / group <b>$script:EditionGroup</b><br>
Admin: <b>$script:CurrentUserIsAdmin</b><br>
Report folder: <b>$encReportDir</b>
</div>
<div class="note">
<b>Important:</b> Registry verification proves that the value was written/read successfully. It cannot always prove that Windows UI fully honors a policy, especially for edition-limited or build-dependent policies. Such entries are marked as BestEffort, DeprecatedOrLegacy, UISetting, or MaybeIgnoredOnEdition.
</div>
$summaryHtml
$resultsHtml
</body>
</html>
"@

    try {
        $html | Out-File -FilePath $htmlPath -Encoding UTF8
        Write-Host "HTML report: $htmlPath" -ForegroundColor Green
        Write-Host "CSV report:  $csvPath" -ForegroundColor Green
        Write-Host "JSON report: $jsonPath" -ForegroundColor Green
    } catch {
        Write-Host "WARNING: HTML report failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# ============================================================
# MAIN
# ============================================================

Write-Section "$script:ScriptTitle - $Mode"

Write-Host "Mode: $Mode" -ForegroundColor Cyan
Write-Host "Report folder: $script:ReportDir" -ForegroundColor Yellow
Write-Host "Windows: $script:ProductName | DisplayVersion=$script:DisplayVersion | Build=$script:BuildNumber.$script:UBR | Edition=$script:EditionId" -ForegroundColor Cyan

Add-PreflightResults
Initialize-RegistrySettings

Invoke-RegistryBackup
Invoke-RestorePoint

Invoke-AllRegistrySettings
Write-RollbackRegFile
Invoke-AppCleanup
Invoke-GpUpdateAndExplorer
Write-Reports

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "Report folder:" -ForegroundColor Cyan
Write-Host $script:ReportDir -ForegroundColor Yellow

if ($Mode -eq "Audit") {
    Write-Host ""
    Write-Host "No changes were made. To apply:" -ForegroundColor Cyan
    Write-Host ".\$script:ScriptName.ps1 -Mode Apply" -ForegroundColor Yellow
}

if ($Mode -eq "Apply") {
    Write-Host ""
    Write-Host "Recommended: restart your laptop after Apply mode." -ForegroundColor Cyan
    Write-Host "Then run:" -ForegroundColor Cyan
    Write-Host ".\$script:ScriptName.ps1 -Mode Verify" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To undo registry changes, double-click rollback.reg in the report folder," -ForegroundColor Cyan
    Write-Host "or use the System Restore point created before Apply." -ForegroundColor Cyan
}

try { Stop-Transcript | Out-Null } catch { Write-Verbose "Ignored non-critical error: $($_.Exception.Message)" }
