#requires -Version 5.1
#requires -PSEdition Desktop

<#
Win11-25H2-CalmMode-GUI.ps1

A thin Windows Forms front-end for Win11-25H2-CalmMode.ps1. It does NOT contain any
policy logic of its own: it asks the engine for its catalog (-ExportCatalog), shows
blocks and individual tweaks as checkboxes, then writes a temporary JSON config and
calls the engine with -ConfigPath. The engine remains the single source of truth.

Safety model (same as the engine):
  - Default action is Audit (read-only). Apply is a separate, explicit button.
  - Apply requires Administrator and a confirmation dialog.
  - No external dependencies: System.Windows.Forms ships with .NET Framework on
    Windows PowerShell 5.1 Desktop.

This launcher changes nothing on the system by itself; it only orchestrates the engine.
#>

[CmdletBinding()]
param(
    # Path to the engine script. Empty = the sibling script next to this file.
    [string]$EnginePath = "",

    # Build the catalog and the form, print a one-line summary, then exit WITHOUT showing
    # the window. Used for headless verification; changes nothing and shows no UI.
    [switch]$SelfTest
)

$ErrorActionPreference = "Stop"

# Resolve the engine path robustly: $PSScriptRoot is not always populated depending on
# how the launcher is invoked, so fall back to this script's own directory.
if ([string]::IsNullOrWhiteSpace($EnginePath)) {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    $EnginePath = Join-Path $scriptDir "Win11-25H2-CalmMode.ps1"
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

if (-not (Test-Path -LiteralPath $EnginePath)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Engine script not found:`n$EnginePath",
        "Win11 25H2 Calm Mode", "OK", "Error") | Out-Null
    return
}

# Resolve the 64-bit Windows PowerShell so the engine runs in the correct registry view
# even if this GUI was launched from a 32-bit host.
function Get-PowerShellExe {
    $candidates = @(
        (Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"),
        (Join-Path $env:SystemRoot "Sysnative\WindowsPowerShell\v1.0\powershell.exe")
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { return $c }
    }
    return "powershell.exe"
}

$script:PowerShellExe = Get-PowerShellExe

# ------------------------------------------------------------
# Load the catalog from the engine (-ExportCatalog prints JSON)
# ------------------------------------------------------------
function Get-Catalog {
    $psExe = $script:PowerShellExe
    $out = & $psExe -NoProfile -ExecutionPolicy Bypass -File $EnginePath -ExportCatalog 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($out -join ""))) {
        throw "Failed to read catalog from engine (exit $LASTEXITCODE)."
    }
    # Defense-in-depth: isolate the JSON object even if a stray host line slips through.
    $text = ($out -join "`n")
    $start = $text.IndexOf("{")
    $end = $text.LastIndexOf("}")
    if ($start -lt 0 -or $end -le $start) {
        throw "Engine did not return a JSON catalog."
    }
    return ($text.Substring($start, $end - $start + 1) | ConvertFrom-Json)
}

try {
    $catalog = Get-Catalog
} catch {
    [System.Windows.Forms.MessageBox]::Show(
        "Could not load the settings catalog from the engine.`n`n$($_.Exception.Message)",
        "Win11 25H2 Calm Mode", "OK", "Error") | Out-Null
    return
}

# Friendly block titles for the tree (fallback to the raw key if unknown).
$blockTitles = @{
    "WindowsAI"               = "Windows AI / Recall / Copilot"
    "Widgets"                 = "Widgets / News and Interests"
    "CloudContent"            = "Cloud Content / ads / recommendations"
    "Privacy"                 = "Privacy / diagnostics / advertising"
    "Search"                  = "Search"
    "StartTaskbar"            = "Start menu / Taskbar / Explorer"
    "WindowsUpdate"           = "Windows Update"
    "DeliveryOptimization"    = "Delivery Optimization (no P2P)"
    "EdgeQuietMode"           = "Microsoft Edge quiet mode"
    "DeveloperMode"           = "Developer Mode / sideloading (security trade-off)"
    "LongPaths"               = "Win32 long paths"
    "FastStartupDisable"      = "Disable Fast Startup"
    "Gaming"                  = "Gaming (Game DVR / Game Bar)"
    "ManualWindowsUpdateMode" = "Manual Windows Update mode (AUOptions=2)"
    "TargetReleaseVersionPin" = "Pin feature version (can block updates)"
    "RemoveCopilotApp"        = "Appx cleanup: remove Copilot app (opt-in)"
    "RemoveTeamsPersonal"     = "Appx cleanup: remove Teams personal (opt-in)"
    "RemoveXboxApps"          = "Appx cleanup: remove Xbox apps (opt-in)"
    "RemoveOneDrive"          = "Appx cleanup: uninstall OneDrive (opt-in)"
}

# ------------------------------------------------------------
# Build the form
# ------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Win11 25H2 Calm Mode v$($catalog.ScriptVersion) - configuration"
$form.Size = New-Object System.Drawing.Size(820, 680)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = New-Object System.Drawing.Size(640, 480)

# Header with detected environment.
$header = New-Object System.Windows.Forms.Label
$header.Dock = "Top"
$header.Height = 48
$header.Padding = New-Object System.Windows.Forms.Padding(10, 8, 10, 0)
$header.Text = "Detected: Build $($catalog.Build).$($catalog.UBR), edition group $($catalog.EditionGroup). " +
    "Check the blocks and tweaks you want, then run Audit first (read-only)."
$form.Controls.Add($header)

# TreeView with checkboxes: blocks at top level, tweaks as children.
$tree = New-Object System.Windows.Forms.TreeView
$tree.Dock = "Fill"
$tree.CheckBoxes = $true
$tree.HideSelection = $false
$form.Controls.Add($tree)

# Bottom panel with action buttons.
$panel = New-Object System.Windows.Forms.Panel
$panel.Dock = "Bottom"
$panel.Height = 96
$form.Controls.Add($panel)

# Description box shows the selected node's details.
$desc = New-Object System.Windows.Forms.TextBox
$desc.Dock = "Bottom"
$desc.Multiline = $true
$desc.ReadOnly = $true
$desc.Height = 60
$desc.ScrollBars = "Vertical"
$form.Controls.Add($desc)

# Tree must be added last visually so Fill works under the docked panels.
$tree.BringToFront()

# Group tweaks by block.
$tweaksByBlock = @{}
foreach ($t in $catalog.Tweaks) {
    $bk = if ([string]::IsNullOrEmpty($t.BlockKey)) { "Other" } else { $t.BlockKey }
    if (-not $tweaksByBlock.ContainsKey($bk)) { $tweaksByBlock[$bk] = New-Object System.Collections.ArrayList }
    [void]$tweaksByBlock[$bk].Add($t)
}

# Build nodes for each block in the catalog's block order.
foreach ($block in $catalog.Blocks) {
    $title = if ($blockTitles.ContainsKey($block.Key)) { $blockTitles[$block.Key] } else { $block.Key }
    $blockNode = New-Object System.Windows.Forms.TreeNode($title)
    $blockNode.Checked = [bool]$block.Enabled
    $blockNode.Tag = [pscustomobject]@{ Kind = "block"; Key = $block.Key }

    if ($tweaksByBlock.ContainsKey($block.Key)) {
        foreach ($t in $tweaksByBlock[$block.Key]) {
            $label = "$($t.Description)  [$($t.Confidence)]"
            $tweakNode = New-Object System.Windows.Forms.TreeNode($label)
            # Tweaks start checked; the engine applies them unless unchecked.
            $tweakNode.Checked = $true
            $tweakNode.Tag = [pscustomobject]@{ Kind = "tweak"; Key = $t.Key; Detail = $t }
            [void]$blockNode.Nodes.Add($tweakNode)
        }
    }

    [void]$tree.Nodes.Add($blockNode)
}

# Checking/unchecking a block toggles all its child tweaks. Guard against recursion.
$script:Suppress = $false
$tree.Add_AfterCheck({
    param($src, $e)
    if ($script:Suppress) { return }
    if ($null -ne $e.Node.Tag -and $e.Node.Tag.Kind -eq "block") {
        $script:Suppress = $true
        foreach ($child in $e.Node.Nodes) { $child.Checked = $e.Node.Checked }
        $script:Suppress = $false
    }
})

# Show details for the selected node.
$tree.Add_AfterSelect({
    param($src, $e)
    $tag = $e.Node.Tag
    if ($null -eq $tag) { $desc.Text = ""; return }
    if ($tag.Kind -eq "tweak") {
        $d = $tag.Detail
        $ed = if ($d.Editions -and $d.Editions.Count -gt 0) { ($d.Editions -join ", ") } else { "all editions" }
        $desc.Text = "$($d.Path)\$($d.Name) = $($d.Value) [$($d.Type)]`r`n" +
            "Confidence: $($d.Confidence) | Min build: $($d.MinBuild)$(if ($d.MinUBR -gt 0) { ".$($d.MinUBR)" }) | Editions: $ed"
    } else {
        $desc.Text = "Block: $($tag.Key). Unchecking it skips the whole block."
    }
})

# ------------------------------------------------------------
# Buttons
# ------------------------------------------------------------
function Get-ActionButton {
    param([string]$Text, [int]$X, [int]$Width = 130)
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Location = New-Object System.Drawing.Point($X, 12)
    $b.Size = New-Object System.Drawing.Size($Width, 32)
    return $b
}

$btnSelectAll = Get-ActionButton -Text "Select all" -X 10 -Width 90
$btnSelectNone = Get-ActionButton -Text "Select none" -X 106 -Width 90
$btnAudit = Get-ActionButton -Text "Run Audit (safe)" -X 360 -Width 150
$btnApply = Get-ActionButton -Text "Apply..." -X 516 -Width 120
$btnClose = Get-ActionButton -Text "Close" -X 642 -Width 90

$panel.Controls.AddRange(@($btnSelectAll, $btnSelectNone, $btnAudit, $btnApply, $btnClose))

# Status line.
$status = New-Object System.Windows.Forms.Label
$status.Location = New-Object System.Drawing.Point(12, 54)
$status.Size = New-Object System.Drawing.Size(780, 36)
$status.Text = "Ready. Audit is read-only and changes nothing."
$panel.Controls.Add($status)

$btnSelectAll.Add_Click({
    foreach ($n in $tree.Nodes) { $n.Checked = $true }
})
$btnSelectNone.Add_Click({
    foreach ($n in $tree.Nodes) { $n.Checked = $false }
})

# Build the config object from the current checkbox state.
function Get-SelectionConfig {
    $blocks = @{}
    $disabled = New-Object System.Collections.ArrayList
    foreach ($blockNode in $tree.Nodes) {
        $tag = $blockNode.Tag
        if ($null -eq $tag -or $tag.Kind -ne "block") { continue }
        $blocks[$tag.Key] = [bool]$blockNode.Checked
        # If a block is enabled, collect any individually unchecked tweaks.
        if ($blockNode.Checked) {
            foreach ($child in $blockNode.Nodes) {
                if (-not $child.Checked -and $null -ne $child.Tag -and $child.Tag.Kind -eq "tweak") {
                    [void]$disabled.Add($child.Tag.Key)
                }
            }
        }
    }
    return [pscustomobject]@{
        blocks         = $blocks
        disabledTweaks = @($disabled)
    }
}

# Write the selection config to a temp file and return its path.
function Get-TempConfigPath {
    $cfg = Get-SelectionConfig
    $json = $cfg | ConvertTo-Json -Depth 5
    $path = Join-Path $env:TEMP ("Win11-CalmMode-GUI-config-" + [Guid]::NewGuid().ToString("N") + ".json")
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $json, $utf8NoBom)
    return $path
}

# Run the engine in a given mode with the current selection. Apply runs elevated.
function Invoke-Engine {
    param([ValidateSet("Audit", "Apply")][string]$Mode)

    $cfgPath = Get-TempConfigPath
    $argList = @(
        "-NoProfile", "-ExecutionPolicy", "Bypass",
        "-File", "`"$EnginePath`"",
        "-Mode", $Mode,
        "-ConfigPath", "`"$cfgPath`""
    )

    try {
        if ($Mode -eq "Apply") {
            # Apply needs Administrator: relaunch the engine elevated in its own window.
            $status.Text = "Launching elevated Apply... approve the UAC prompt."
            Start-Process -FilePath $script:PowerShellExe -ArgumentList $argList -Verb RunAs | Out-Null
        } else {
            $status.Text = "Running Audit... a console window will show the report."
            Start-Process -FilePath $script:PowerShellExe -ArgumentList $argList | Out-Null
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Could not start the engine.`n`n$($_.Exception.Message)",
            "Win11 25H2 Calm Mode", "OK", "Error") | Out-Null
    }
}

$btnAudit.Add_Click({
    Invoke-Engine -Mode "Audit"
})

$btnApply.Add_Click({
    $answer = [System.Windows.Forms.MessageBox]::Show(
        "Apply will CHANGE system settings according to your selection." + [Environment]::NewLine +
        "It requires Administrator (you will see a UAC prompt) and creates a backup and a System Restore point first." + [Environment]::NewLine + [Environment]::NewLine +
        "It is strongly recommended to run Audit first and review the report." + [Environment]::NewLine + [Environment]::NewLine +
        "Continue with Apply?",
        "Confirm Apply", "YesNo", "Warning")
    if ($answer -eq "Yes") {
        Invoke-Engine -Mode "Apply"
    }
})

$btnClose.Add_Click({ $form.Close() })

if ($SelfTest) {
    # Headless check: confirm the tree built with all blocks and tweaks, then exit.
    $tweakNodeCount = 0
    foreach ($n in $tree.Nodes) { $tweakNodeCount += $n.Nodes.Count }
    Write-Output ("SELFTEST OK: blockNodes={0} tweakNodes={1} sampleConfig={2}" -f `
        $tree.Nodes.Count, $tweakNodeCount, ((Get-SelectionConfig | ConvertTo-Json -Depth 5 -Compress).Length))
    $form.Dispose()
    return
}

[void]$form.ShowDialog()
$form.Dispose()
