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

# Basic HiDPI: make the process system-DPI aware so the form and text are not
# bitmap-stretched (blurry) on scaled displays. Best-effort; ignore if unavailable.
try {
    if (-not ([System.Management.Automation.PSTypeName]'NativeDpi').Type) {
        Add-Type -Namespace Native -Name Dpi -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool SetProcessDPIAware();
'@
    }
    [void][Native.Dpi]::SetProcessDPIAware()
} catch { Write-Verbose "DPI awareness not set: $($_.Exception.Message)" }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

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

# Best-effort cleanup of any temp config files left behind by previous runs that
# crashed before they could delete their own. Current runs clean up after -Wait.
try {
    Get-ChildItem -Path $env:TEMP -Filter "Win11-CalmMode-GUI-config-*.json" -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
} catch { Write-Verbose "Temp cleanup skipped: $($_.Exception.Message)" }

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
$form.Size = New-Object System.Drawing.Size(940, 680)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = New-Object System.Drawing.Size(720, 480)
$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
$form.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96)

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

$btnSelectAll = Get-ActionButton -Text "Select all" -X 10 -Width 84
$btnSelectNone = Get-ActionButton -Text "Select none" -X 98 -Width 84
$btnSave = Get-ActionButton -Text "Save config..." -X 186 -Width 92
$btnLoad = Get-ActionButton -Text "Load config..." -X 282 -Width 92
$btnAudit = Get-ActionButton -Text "Run Audit (safe)" -X 388 -Width 120
$btnApply = Get-ActionButton -Text "Apply..." -X 512 -Width 92
$btnUndo = Get-ActionButton -Text "Undo last Apply" -X 608 -Width 120
$btnClose = Get-ActionButton -Text "Close" -X 732 -Width 80

$panel.Controls.AddRange(@($btnSelectAll, $btnSelectNone, $btnSave, $btnLoad, $btnAudit, $btnApply, $btnUndo, $btnClose))

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

$btnSave.Add_Click({
    $dlg = New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Filter = "JSON config (*.json)|*.json|All files (*.*)|*.*"
    $dlg.FileName = "Win11-CalmMode-config.json"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        try {
            $json = Get-SelectionConfig | ConvertTo-Json -Depth 5
            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($dlg.FileName, $json, $utf8NoBom)
            $status.Text = "Saved config to $($dlg.FileName)"
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Could not save config.`n`n$($_.Exception.Message)",
                "Win11 25H2 Calm Mode", "OK", "Error") | Out-Null
        }
    }
})

$btnLoad.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = "JSON config (*.json)|*.json|All files (*.*)|*.*"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        try {
            $cfg = Get-Content -LiteralPath $dlg.FileName -Raw -ErrorAction Stop | ConvertFrom-Json
            Set-TreeFromConfig -Config $cfg
            $status.Text = "Loaded config from $($dlg.FileName)"
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Could not load config.`n`n$($_.Exception.Message)",
                "Win11 25H2 Calm Mode", "OK", "Error") | Out-Null
        }
    }
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

# Apply a parsed config object (same schema as Get-SelectionConfig) to the tree.
# Only mutates in-memory checkbox state, so ShouldProcess does not apply here.
function Set-TreeFromConfig {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param($Config)
    $disabled = @()
    if ($Config.PSObject.Properties.Name -contains "disabledTweaks" -and $Config.disabledTweaks) {
        $disabled = @($Config.disabledTweaks)
    }
    $blockProps = if ($Config.PSObject.Properties.Name -contains "blocks" -and $Config.blocks) { $Config.blocks } else { $null }

    # Suppress the block->children cascade so we can set each child explicitly.
    $script:Suppress = $true
    try {
        foreach ($blockNode in $tree.Nodes) {
            $tag = $blockNode.Tag
            if ($null -eq $tag -or $tag.Kind -ne "block") { continue }
            if ($blockProps -and ($blockProps.PSObject.Properties.Name -contains $tag.Key)) {
                $blockNode.Checked = [bool]$blockProps.$($tag.Key)
            }
            foreach ($child in $blockNode.Nodes) {
                if ($null -eq $child.Tag -or $child.Tag.Kind -ne "tweak") { continue }
                $child.Checked = ($blockNode.Checked -and ($disabled -notcontains $child.Tag.Key))
            }
        }
    } finally {
        $script:Suppress = $false
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

# Locate the JSON results file the engine just wrote under a report base folder.
function Find-LatestResultsJson {
    param([string]$Base, [string]$Mode)
    if ([string]::IsNullOrWhiteSpace($Base) -or -not (Test-Path -LiteralPath $Base)) { return $null }
    $dir = Get-ChildItem -LiteralPath $Base -Directory -Filter "Win11-25H2-CalmMode-v*-$Mode-*" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $dir) { return $null }
    $json = Get-ChildItem -LiteralPath $dir.FullName -Filter "*-results.json" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($json) { return $json.FullName }
    return $null
}

# Show the engine's results in a grid. Defaults to a "Needs attention" view.
function Show-ResultsDialog {
    param([object[]]$Results, [string]$Mode)

    $attention = @("WouldChange", "WouldRemove", "Warning", "VerifyFail", "Error",
        "RequiresVerification", "MaybeIgnoredOnEdition", "UnsupportedBuild")

    $rf = New-Object System.Windows.Forms.Form
    $rf.Text = "$Mode results"
    $rf.Size = New-Object System.Drawing.Size(900, 560)
    $rf.StartPosition = "CenterParent"
    $rf.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi

    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Dock = "Fill"
    $grid.ReadOnly = $true
    $grid.AllowUserToAddRows = $false
    $grid.AllowUserToDeleteRows = $false
    $grid.RowHeadersVisible = $false
    $grid.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
    $grid.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
    foreach ($c in @("Category", "Item", "Status", "Current", "Desired", "Message")) {
        [void]$grid.Columns.Add($c, $c)
    }
    $grid.Columns["Item"].FillWeight = 200
    $grid.Columns["Message"].FillWeight = 260

    $top = New-Object System.Windows.Forms.Panel
    $top.Dock = "Top"
    $top.Height = 34
    $chkAll = New-Object System.Windows.Forms.CheckBox
    $chkAll.Text = "Show all (including compliant)"
    $chkAll.Location = New-Object System.Drawing.Point(10, 8)
    $chkAll.AutoSize = $true
    $summary = New-Object System.Windows.Forms.Label
    $summary.Location = New-Object System.Drawing.Point(260, 10)
    $summary.AutoSize = $true
    $counts = $Results | Group-Object Status | Sort-Object Name
    $summary.Text = "Total: $($Results.Count)  |  " + (($counts | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join "   ")
    $top.Controls.AddRange(@($chkAll, $summary))

    $populate = {
        $grid.Rows.Clear()
        foreach ($r in $Results) {
            if (-not $chkAll.Checked -and ($attention -notcontains $r.Status)) { continue }
            $i = $grid.Rows.Add($r.Category, $r.Item, $r.Status, $r.CurrentValue, $r.DesiredValue, $r.Message)
            $fore = switch -Wildcard ($r.Status) {
                "Error"       { "Red" }
                "VerifyFail"  { "Red" }
                "Warning"     { "DarkOrange" }
                "WouldChange" { "DarkOrange" }
                "WouldRemove" { "DarkOrange" }
                "Unsupported*" { "Firebrick" }
                default       { "Black" }
            }
            $grid.Rows[$i].Cells["Status"].Style.ForeColor = [System.Drawing.Color]::FromName($fore)
        }
        if ($grid.Rows.Count -eq 0) {
            $status2 = if ($chkAll.Checked) { "no results" } else { "nothing needs attention" }
            $rf.Text = "$Mode results - $status2"
        }
    }
    $chkAll.Add_CheckedChanged($populate)
    & $populate

    $rf.Controls.Add($grid)
    $rf.Controls.Add($top)
    $grid.BringToFront()
    [void]$rf.ShowDialog()
    $rf.Dispose()
}

# Run the engine in a given mode with the current selection, then show the results
# in-window. Audit runs hidden (read-only, throwaway report); Apply runs elevated
# and writes its report + rollback.reg to the Desktop (preserved).
function Invoke-Engine {
    param([ValidateSet("Audit", "Apply")][string]$Mode)

    $cfgPath = Get-TempConfigPath
    $auditTempBase = $null
    if ($Mode -eq "Audit") {
        $auditTempBase = Join-Path $env:TEMP ("Win11-CalmMode-GUI-audit-" + [Guid]::NewGuid().ToString("N"))
        [void](New-Item -ItemType Directory -Path $auditTempBase -Force)
        $reportBase = $auditTempBase
    } else {
        $reportBase = [Environment]::GetFolderPath("Desktop")
    }

    $argList = @(
        "-NoProfile", "-ExecutionPolicy", "Bypass",
        "-File", "`"$EnginePath`"",
        "-Mode", $Mode,
        "-ConfigPath", "`"$cfgPath`"",
        "-ReportPath", "`"$reportBase`""
    )
    # Apply: also run a Verify pass so the results window confirms the values landed.
    if ($Mode -eq "Apply") { $argList += "-ThenVerify" }

    try {
        $form.Enabled = $false
        if ($Mode -eq "Apply") {
            $status.Text = "Launching elevated Apply... approve the UAC prompt, then wait."
            $status.Refresh()
            $proc = Start-Process -FilePath $script:PowerShellExe -ArgumentList $argList -Verb RunAs -Wait -PassThru
        } else {
            $status.Text = "Running Audit (read-only)... please wait."
            $status.Refresh()
            $proc = Start-Process -FilePath $script:PowerShellExe -ArgumentList $argList -WindowStyle Hidden -Wait -PassThru
        }

        $jsonPath = Find-LatestResultsJson -Base $reportBase -Mode $Mode
        if ($jsonPath) {
            $results = @(Get-Content -LiteralPath $jsonPath -Raw -ErrorAction Stop | ConvertFrom-Json)
            $status.Text = "$Mode complete: $($results.Count) checks (engine exit $($proc.ExitCode)). See results window."
            Show-ResultsDialog -Results $results -Mode $Mode
        } else {
            $status.Text = "$Mode finished (engine exit $($proc.ExitCode)) but no results file was found."
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Could not run the engine.`n`n$($_.Exception.Message)",
            "Win11 25H2 Calm Mode", "OK", "Error") | Out-Null
        $status.Text = "Ready. Audit is read-only and changes nothing."
    } finally {
        $form.Enabled = $true
        Remove-Item -LiteralPath $cfgPath -Force -ErrorAction SilentlyContinue
        if ($auditTempBase -and (Test-Path -LiteralPath $auditTempBase)) {
            Remove-Item -LiteralPath $auditTempBase -Recurse -Force -ErrorAction SilentlyContinue
        }
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

$btnUndo.Add_Click({
    # Find the most recent Apply report folder on the Desktop and import its rollback.reg.
    $desktop = [Environment]::GetFolderPath("Desktop")
    $dir = Get-ChildItem -LiteralPath $desktop -Directory -Filter "Win11-25H2-CalmMode-v*-Apply-*" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $dir) {
        [System.Windows.Forms.MessageBox]::Show(
            "No Apply report folder found on the Desktop to undo.",
            "Win11 25H2 Calm Mode", "OK", "Information") | Out-Null
        return
    }
    $answer = [System.Windows.Forms.MessageBox]::Show(
        "Undo will import rollback.reg from:" + [Environment]::NewLine + $dir.Name + [Environment]::NewLine + [Environment]::NewLine +
        "This restores REGISTRY values only - it does NOT bring back removed Appx packages." + [Environment]::NewLine +
        "Requires Administrator (you will see a UAC prompt)." + [Environment]::NewLine + [Environment]::NewLine +
        "Continue?",
        "Confirm Undo last Apply", "YesNo", "Warning")
    if ($answer -ne "Yes") { return }

    $argList = @(
        "-NoProfile", "-ExecutionPolicy", "Bypass",
        "-File", "`"$EnginePath`"",
        "-RestoreFrom", "`"$($dir.FullName)`""
    )
    try {
        $status.Text = "Launching elevated restore... approve the UAC prompt."
        Start-Process -FilePath $script:PowerShellExe -ArgumentList $argList -Verb RunAs | Out-Null
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Could not start the restore.`n`n$($_.Exception.Message)",
            "Win11 25H2 Calm Mode", "OK", "Error") | Out-Null
    }
})

$btnClose.Add_Click({ $form.Close() })

if ($SelfTest) {
    # Headless check: tree built, and config formation / round-trip work. No UI shown.
    $fail = New-Object System.Collections.ArrayList
    $tweakNodeCount = 0
    foreach ($n in $tree.Nodes) { $tweakNodeCount += $n.Nodes.Count }

    $cfg0 = Get-SelectionConfig
    if ($cfg0.blocks.Count -ne $tree.Nodes.Count) {
        [void]$fail.Add("block count $($cfg0.blocks.Count) != node count $($tree.Nodes.Count)")
    }

    # Pick a block that has tweaks, to exercise the tweak/block disable round trips.
    $blockKey = $null; $tweakKey = $null
    foreach ($n in $tree.Nodes) {
        if ($null -ne $n.Tag -and $n.Tag.Kind -eq "block" -and $n.Nodes.Count -gt 0) {
            $blockKey = $n.Tag.Key; $tweakKey = $n.Nodes[0].Tag.Key; break
        }
    }

    if ($null -eq $blockKey) {
        [void]$fail.Add("no block with tweaks found")
    } else {
        $allBlocks = @{}
        foreach ($n in $tree.Nodes) { $allBlocks[$n.Tag.Key] = $true }

        # Round trip 1: block ON, its first tweak disabled (via the real JSON path).
        $rt1 = (@{ blocks = $allBlocks; disabledTweaks = @($tweakKey) } | ConvertTo-Json -Depth 5) | ConvertFrom-Json
        Set-TreeFromConfig -Config $rt1
        if ((Get-SelectionConfig).disabledTweaks -notcontains $tweakKey) {
            [void]$fail.Add("tweak-disable round trip failed for $tweakKey")
        }

        # Round trip 2: whole block disabled.
        $allBlocks2 = @{}
        foreach ($n in $tree.Nodes) { $allBlocks2[$n.Tag.Key] = $true }
        $allBlocks2[$blockKey] = $false
        $rt2 = (@{ blocks = $allBlocks2; disabledTweaks = @() } | ConvertTo-Json -Depth 5) | ConvertFrom-Json
        Set-TreeFromConfig -Config $rt2
        if ((Get-SelectionConfig).blocks[$blockKey] -ne $false) {
            [void]$fail.Add("block-disable round trip failed for $blockKey")
        }
    }

    $form.Dispose()
    if ($fail.Count -eq 0) {
        Write-Output ("SELFTEST OK: blockNodes={0} tweakNodes={1} blocksInConfig={2}" -f `
            $tree.Nodes.Count, $tweakNodeCount, $cfg0.blocks.Count)
        return
    } else {
        Write-Output ("SELFTEST FAIL: " + ($fail -join "; "))
        exit 1
    }
}

[void]$form.ShowDialog()
$form.Dispose()
