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

# The engine exports each block's Title (B3) and the attention-status list (B2) in the
# catalog, so the GUI no longer keeps its own copies as the source of truth. The list and
# hashtable below are only fallbacks for older engines whose catalog lacks these fields.
$script:AttentionStatuses = if ($catalog.PSObject.Properties.Name -contains "AttentionStatuses" -and $catalog.AttentionStatuses) {
    @($catalog.AttentionStatuses)
} else {
    @("WouldChange", "WouldRemove", "Warning", "VerifyFail", "Error",
        "RequiresVerification", "MaybeIgnoredOnEdition", "UnsupportedBuild")
}

# Friendly block titles for the tree (fallback when the catalog has no Title for a block).
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

# Top bar: environment header + a live filter box (D1). Both live in one Top-docked panel so
# the docking order stays simple and the tree fills the rest of the form.
$topBar = New-Object System.Windows.Forms.Panel
$topBar.Dock = "Top"
$topBar.Height = 84

$header = New-Object System.Windows.Forms.Label
$header.Location = New-Object System.Drawing.Point(10, 6)
$header.Size = New-Object System.Drawing.Size(900, 40)
$header.Anchor = "Top, Left, Right"
$header.Text = "Detected: Build $($catalog.Build).$($catalog.UBR), edition group $($catalog.EditionGroup). " +
    "Check the blocks and tweaks you want, then run Audit first (read-only)."

$lblFilter = New-Object System.Windows.Forms.Label
$lblFilter.Text = "Filter:"
$lblFilter.Location = New-Object System.Drawing.Point(10, 53)
$lblFilter.AutoSize = $true

$txtFilter = New-Object System.Windows.Forms.TextBox
$txtFilter.Location = New-Object System.Drawing.Point(60, 50)
$txtFilter.Size = New-Object System.Drawing.Size(360, 24)
$txtFilter.Anchor = "Top, Left"

$btnFilterClear = New-Object System.Windows.Forms.Button
$btnFilterClear.Text = "Clear"
$btnFilterClear.Size = New-Object System.Drawing.Size(60, 24)
$btnFilterClear.Location = New-Object System.Drawing.Point(428, 49)
$btnFilterClear.Anchor = "Top, Left"

$topBar.Controls.AddRange(@($header, $lblFilter, $txtFilter, $btnFilterClear))
$form.Controls.Add($topBar)

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

# Canonical model of every block node and its full child list. The tree's own Nodes
# collection is a VIEW that the filter (D1) may temporarily narrow, so all selection logic
# reads $script:BlockEntries instead of $tree.Nodes to stay correct under filtering.
$script:BlockEntries = New-Object System.Collections.ArrayList

# Build nodes for each block in the catalog's block order.
foreach ($block in $catalog.Blocks) {
    # Prefer the engine-provided Title (single source of truth); fall back to the local map.
    $title = if (-not [string]::IsNullOrWhiteSpace($block.Title)) {
        $block.Title
    } elseif ($blockTitles.ContainsKey($block.Key)) {
        $blockTitles[$block.Key]
    } else {
        $block.Key
    }
    $blockNode = New-Object System.Windows.Forms.TreeNode($title)
    $blockNode.Checked = [bool]$block.Enabled
    $blockNode.Tag = [pscustomobject]@{ Kind = "block"; Key = $block.Key }

    $childList = New-Object System.Collections.ArrayList
    if ($tweaksByBlock.ContainsKey($block.Key)) {
        foreach ($t in $tweaksByBlock[$block.Key]) {
            $label = "$($t.Description)  [$($t.Confidence)]"
            $tweakNode = New-Object System.Windows.Forms.TreeNode($label)
            # Tweaks start checked; the engine applies them unless unchecked.
            $tweakNode.Checked = $true
            $tweakNode.Tag = [pscustomobject]@{ Kind = "tweak"; Key = $t.Key; Detail = $t }
            [void]$blockNode.Nodes.Add($tweakNode)
            [void]$childList.Add($tweakNode)
        }
    }

    [void]$tree.Nodes.Add($blockNode)
    # BaseTitle is kept so D2 can append "(N would change)" without losing the original text.
    [void]$script:BlockEntries.Add([pscustomobject]@{ Node = $blockNode; Children = $childList; BaseTitle = $title })
}

# Checking/unchecking a block toggles all its child tweaks. Guard against recursion.
# Cascade over the canonical children (not $e.Node.Nodes) so a block toggle affects every
# tweak even when the filter is currently hiding some of them.
$script:Suppress = $false
$tree.Add_AfterCheck({
    param($src, $e)
    if ($script:Suppress) { return }
    if ($null -ne $e.Node.Tag -and $e.Node.Tag.Kind -eq "block") {
        $script:Suppress = $true
        $entry = $script:BlockEntries | Where-Object { $_.Node -eq $e.Node } | Select-Object -First 1
        $kids = if ($entry) { $entry.Children } else { $e.Node.Nodes }
        foreach ($child in $kids) { $child.Checked = $e.Node.Checked }
        $script:Suppress = $false
    }
})

# Live filter (D1): narrow the visible tree by substring match on block title or tweak label.
# Rebuilds $tree.Nodes from the canonical $script:BlockEntries each keystroke; node objects
# (and their Checked state) are reused, so filtering never loses the selection.
$applyFilter = {
    $f = $txtFilter.Text.Trim()
    $tree.BeginUpdate()
    try {
        $tree.Nodes.Clear()
        foreach ($entry in $script:BlockEntries) {
            $bn = $entry.Node
            $bn.Nodes.Clear()
            $blockMatch = ($f -eq "") -or ($bn.Text -match [regex]::Escape($f))
            $kids = New-Object System.Collections.ArrayList
            if ($blockMatch) {
                foreach ($c in $entry.Children) { [void]$kids.Add($c) }
            } else {
                foreach ($c in $entry.Children) {
                    if ($c.Text -match [regex]::Escape($f)) { [void]$kids.Add($c) }
                }
            }
            if ($blockMatch -or $kids.Count -gt 0) {
                foreach ($c in $kids) { [void]$bn.Nodes.Add($c) }
                [void]$tree.Nodes.Add($bn)
                if ($f -ne "") { $bn.Expand() }
            }
        }
    } finally {
        $tree.EndUpdate()
    }
}
$txtFilter.Add_TextChanged($applyFilter)
$btnFilterClear.Add_Click({ $txtFilter.Text = "" })

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

# Select all/none operate on the canonical entries (all blocks + every child), so they are
# predictable regardless of the current filter view.
$btnSelectAll.Add_Click({
    $script:Suppress = $true
    foreach ($entry in $script:BlockEntries) {
        $entry.Node.Checked = $true
        foreach ($c in $entry.Children) { $c.Checked = $true }
    }
    $script:Suppress = $false
})
$btnSelectNone.Add_Click({
    $script:Suppress = $true
    foreach ($entry in $script:BlockEntries) {
        $entry.Node.Checked = $false
        foreach ($c in $entry.Children) { $c.Checked = $false }
    }
    $script:Suppress = $false
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

# Build the config object from the current checkbox state. Reads the canonical entries, not
# $tree.Nodes, so a narrowed filter view never drops blocks/tweaks from the saved selection.
function Get-SelectionConfig {
    $blocks = @{}
    $disabled = New-Object System.Collections.ArrayList
    foreach ($entry in $script:BlockEntries) {
        $blockNode = $entry.Node
        $tag = $blockNode.Tag
        if ($null -eq $tag -or $tag.Kind -ne "block") { continue }
        $blocks[$tag.Key] = [bool]$blockNode.Checked
        # If a block is enabled, collect any individually unchecked tweaks.
        if ($blockNode.Checked) {
            foreach ($child in $entry.Children) {
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
    # Iterate the canonical entries so the round trip covers filtered-out nodes too.
    $script:Suppress = $true
    try {
        foreach ($entry in $script:BlockEntries) {
            $blockNode = $entry.Node
            $tag = $blockNode.Tag
            if ($null -eq $tag -or $tag.Kind -ne "block") { continue }
            if ($blockProps -and ($blockProps.PSObject.Properties.Name -contains $tag.Key)) {
                $blockNode.Checked = [bool]$blockProps.$($tag.Key)
            }
            foreach ($child in $entry.Children) {
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

    # Use the engine's attention-status list (from the catalog) so highlighting never drifts
    # from the HTML report. Falls back to a literal list only if the script-scope copy is unset.
    $attention = if ($script:AttentionStatuses) { $script:AttentionStatuses } else {
        @("WouldChange", "WouldRemove", "Warning", "VerifyFail", "Error",
            "RequiresVerification", "MaybeIgnoredOnEdition", "UnsupportedBuild")
    }

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

    # D3: export the currently shown rows (respecting the "Show all" toggle) to CSV.
    $btnExport = New-Object System.Windows.Forms.Button
    $btnExport.Text = "Export CSV..."
    $btnExport.Size = New-Object System.Drawing.Size(110, 24)
    $btnExport.Location = New-Object System.Drawing.Point(($rf.ClientSize.Width - 122), 5)
    $btnExport.Anchor = "Top, Right"
    $btnExport.Add_Click({
        $dlg = New-Object System.Windows.Forms.SaveFileDialog
        $dlg.Filter = "CSV (*.csv)|*.csv|All files (*.*)|*.*"
        $dlg.FileName = "Win11-CalmMode-$Mode-results.csv"
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            try {
                $rows = if ($chkAll.Checked) { $Results } else { $Results | Where-Object { $attention -contains $_.Status } }
                $csv = $rows | Select-Object Category, Item, Status, CurrentValue, DesiredValue, Confidence, Support, Message | ConvertTo-Csv -NoTypeInformation
                $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
                [System.IO.File]::WriteAllLines($dlg.FileName, $csv, $utf8NoBom)
            } catch {
                [System.Windows.Forms.MessageBox]::Show(
                    "Could not export results.`n`n$($_.Exception.Message)",
                    "Win11 25H2 Calm Mode", "OK", "Error") | Out-Null
            }
        }
    })
    $top.Controls.AddRange(@($chkAll, $summary, $btnExport))

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

# D2: after an Audit, annotate each block node with how many of its tweaks would change, so
# the tree shows where the action is. Maps each result row back to its block via the catalog
# (result rows carry Path/Name; the catalog ties "$Path\$Name" to a BlockKey).
function Update-BlockCounts {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param([object[]]$Results)

    $keyToBlock = @{}
    foreach ($t in $catalog.Tweaks) {
        if (-not [string]::IsNullOrWhiteSpace($t.Key)) { $keyToBlock[$t.Key.ToLowerInvariant()] = $t.BlockKey }
    }

    $perBlock = @{}
    foreach ($r in $Results) {
        if ($r.Status -ne "WouldChange" -and $r.Status -ne "WouldRemove") { continue }
        $k = ("{0}\{1}" -f $r.Path, $r.Name).ToLowerInvariant()
        $bk = $keyToBlock[$k]
        if ($bk) { $perBlock[$bk] = ([int]$perBlock[$bk]) + 1 }
    }

    foreach ($entry in $script:BlockEntries) {
        $bk = $entry.Node.Tag.Key
        $n = [int]$perBlock[$bk]
        $entry.Node.Text = if ($n -gt 0) { "$($entry.BaseTitle)  ($n would change)" } else { $entry.BaseTitle }
    }
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
            if ($Mode -eq "Audit") { Update-BlockCounts -Results $results }
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

# D4: a quick hidden Audit with the current selection, returning how many items would change.
# Used to preview Apply's impact before the UAC prompt. Read-only; cleans up its temp files.
# Returns $null if the count could not be computed.
function Get-AuditPreviewCount {
    $cfgPath = Get-TempConfigPath
    $tmpBase = Join-Path $env:TEMP ("Win11-CalmMode-GUI-preview-" + [Guid]::NewGuid().ToString("N"))
    [void](New-Item -ItemType Directory -Path $tmpBase -Force)
    try {
        $argList = @(
            "-NoProfile", "-ExecutionPolicy", "Bypass",
            "-File", "`"$EnginePath`"",
            "-Mode", "Audit",
            "-ConfigPath", "`"$cfgPath`"",
            "-ReportPath", "`"$tmpBase`""
        )
        Start-Process -FilePath $script:PowerShellExe -ArgumentList $argList -WindowStyle Hidden -Wait | Out-Null
        $jsonPath = Find-LatestResultsJson -Base $tmpBase -Mode "Audit"
        if (-not $jsonPath) { return $null }
        $results = @(Get-Content -LiteralPath $jsonPath -Raw -ErrorAction Stop | ConvertFrom-Json)
        return @($results | Where-Object { $_.Status -eq "WouldChange" -or $_.Status -eq "WouldRemove" }).Count
    } catch {
        return $null
    } finally {
        Remove-Item -LiteralPath $cfgPath -Force -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $tmpBase) { Remove-Item -LiteralPath $tmpBase -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

$btnAudit.Add_Click({
    Invoke-Engine -Mode "Audit"
})

$btnApply.Add_Click({
    # D4: compute the impact preview (quick hidden Audit) before asking to proceed.
    $form.Enabled = $false
    $status.Text = "Calculating impact (quick Audit)... please wait."
    $status.Refresh()
    $preview = Get-AuditPreviewCount
    $form.Enabled = $true
    $status.Text = "Ready. Audit is read-only and changes nothing."

    $previewLine = if ($null -ne $preview) {
        "Based on a quick Audit, about $preview item(s) would change."
    } else {
        "Could not compute the impact preview (the Apply itself will still report every change)."
    }

    $answer = [System.Windows.Forms.MessageBox]::Show(
        "Apply will CHANGE system settings according to your selection." + [Environment]::NewLine +
        $previewLine + [Environment]::NewLine + [Environment]::NewLine +
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

    $target = $null
    $targetLabel = $null
    if ($dir) {
        $target = $dir.FullName
        $targetLabel = $dir.Name
    } else {
        # A3 fallback: no Desktop folder (custom -ReportPath, redirected/OneDrive Desktop, etc.).
        # Let the user browse to any report folder that contains rollback.reg.
        $ask = [System.Windows.Forms.MessageBox]::Show(
            "No Apply report folder was found on the Desktop." + [Environment]::NewLine + [Environment]::NewLine +
            "Browse to a report folder that contains rollback.reg?",
            "Win11 25H2 Calm Mode", "YesNo", "Information")
        if ($ask -ne "Yes") { return }
        $fb = New-Object System.Windows.Forms.FolderBrowserDialog
        $fb.Description = "Select a report folder that contains rollback.reg"
        if ($fb.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
        $target = $fb.SelectedPath
        $targetLabel = $fb.SelectedPath
    }

    $answer = [System.Windows.Forms.MessageBox]::Show(
        "Undo will import rollback.reg from:" + [Environment]::NewLine + $targetLabel + [Environment]::NewLine + [Environment]::NewLine +
        "This restores REGISTRY values only - it does NOT bring back removed Appx packages." + [Environment]::NewLine +
        "Requires Administrator (you will see a UAC prompt)." + [Environment]::NewLine + [Environment]::NewLine +
        "Continue?",
        "Confirm Undo last Apply", "YesNo", "Warning")
    if ($answer -ne "Yes") { return }

    $argList = @(
        "-NoProfile", "-ExecutionPolicy", "Bypass",
        "-File", "`"$EnginePath`"",
        "-RestoreFrom", "`"$target`""
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
    foreach ($entry in $script:BlockEntries) { $tweakNodeCount += $entry.Children.Count }

    $cfg0 = Get-SelectionConfig
    if ($cfg0.blocks.Count -ne $script:BlockEntries.Count) {
        [void]$fail.Add("block count $($cfg0.blocks.Count) != entry count $($script:BlockEntries.Count)")
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

        # Filter round trip (D1): a narrow filter must narrow the visible tree but must NOT
        # change the canonical selection that Get-SelectionConfig reports.
        $txtFilter.Text = "zzz-no-such-tweak-zzz"
        & $applyFilter
        if ($tree.Nodes.Count -ne 0) {
            [void]$fail.Add("filter did not hide non-matching blocks (visible=$($tree.Nodes.Count))")
        }
        if ((Get-SelectionConfig).blocks.Count -ne $script:BlockEntries.Count) {
            [void]$fail.Add("filter changed the canonical selection count")
        }
        $txtFilter.Text = ""
        & $applyFilter
        if ($tree.Nodes.Count -ne $script:BlockEntries.Count) {
            [void]$fail.Add("clearing the filter did not restore all blocks")
        }
    }

    $form.Dispose()
    if ($fail.Count -eq 0) {
        Write-Output ("SELFTEST OK: blockNodes={0} tweakNodes={1} blocksInConfig={2}" -f `
            $script:BlockEntries.Count, $tweakNodeCount, $cfg0.blocks.Count)
        return
    } else {
        Write-Output ("SELFTEST FAIL: " + ($fail -join "; "))
        exit 1
    }
}

[void]$form.ShowDialog()
$form.Dispose()
