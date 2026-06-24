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

$script:Lang = "EN"
$script:UIStrings = @{
    "EN" = @{
        "FormTitle" = "Win11 25H2 Calm Mode v{0} - configuration"
        "Header" = "Select the categories and tweaks you want, run Audit first, then Apply only after reviewing the results."
        "HeaderProduct" = "Windows 11 25H2"
        "HeaderBuild" = "Build {0}.{1}"
        "HeaderEdition" = "Edition: {0}"
        "HeaderMode" = "Mode: Audit first"
        "BadgeSafeDefault" = "Safe by default"
        "BadgeAuditFirst" = "Audit first"
        "BadgeNoChanges" = "No changes until Apply"
        "FilterLabel" = "Filter:"
        "FilterClear" = "Clear"
        "CategoryHeader" = "Categories"
        "TweaksHeader" = "Tweaks"
        "ColTweak" = "Tweak"
        "ColConfidence" = "Confidence"
        "ColRisk" = "Risk"
        "ColRegistry" = "Registry"
        "RiskSafe" = "Safe"
        "RiskNeedsVerify" = "Needs verify"
        "RiskOptIn" = "Opt-in"
        "RiskMayBeIgnored" = "May be ignored"
        "RiskLegacy" = "Legacy"
        "RiskUISetting" = "UI setting"
        "DetailSupport" = "Support: {0}"
        "DetailRisk" = "Risk: {0}"
        "DetailAdminRequired" = "Admin: required for HKLM / system-wide Apply"
        "DetailAdminUser" = "Admin: current-user value, but GUI Apply still runs elevated"
        "DetailRestartNone" = "Restart: usually not required"
        "DetailRestartExplorer" = "Restart: Explorer refresh may be needed"
        "DetailRestartReboot" = "Restart: reboot recommended"
        "DetailRestartApp" = "Restart: close/reopen the affected app if needed"
        "DetailRollbackRegistry" = "Rollback: rollback.reg restores this registry value."
        "DetailRollbackAppx" = "Rollback: registry rollback does NOT restore removed Appx packages."
        "BlockDetailDesc" = "Block: {0}`r`nSelected tweaks: {1}/{2}`r`nRisk: {3}`r`nApply is disabled until a successful Audit after any selection change."
        "StatusAuditRequired" = "Selection changed. Run Audit again before Apply."
        "StatusAuditPassedApplyEnabled" = "Audit complete: no errors. Apply is now available after review."
        "StatusAuditErrorsApplyDisabled" = "Audit complete, but errors were found. Apply remains disabled."
        "ApplyBlockedRunAudit" = "Run Audit first. Apply is disabled until the current selection has a successful Audit."
        "TabSummary" = "Summary"
        "TabDetails" = "Details"
        "TabRaw" = "Raw log"
        "SummaryMetric" = "{0}: {1}"
        "SummaryWouldChange" = "Would change"
        "SummaryAlreadyOk" = "Already OK"
        "SummaryChanged" = "Changed"
        "SummaryNeedsVerification" = "Needs verification"
        "SummaryUnsupported" = "Unsupported"
        "SummaryErrors" = "Errors"
        "SummaryTotal" = "Total"
        "BtnSelectAll" = "Select all"
        "BtnSelectNone" = "Select none"
        "BtnSave" = "Save config..."
        "BtnLoad" = "Load config..."
        "BtnAudit" = "Run Audit (safe)"
        "BtnApply" = "Apply..."
        "BtnUndo" = "Undo last Apply"
        "BtnClose" = "Close"
        "StatusReady" = "Ready. Audit is read-only and changes nothing."
        "ErrorEngineNotFound" = "Engine script not found:`n{0}"
        "ErrorCatalogLoad" = "Could not load the settings catalog from the engine.`n`n{0}"
        "StatusSaved" = "Saved config to {0}"
        "ErrorSave" = "Could not save config.`n`n{0}"
        "StatusLoaded" = "Loaded config from {0}"
        "ErrorLoad" = "Could not load config.`n`n{0}"
        "DialogApplyWarning" = "Apply will CHANGE system settings according to your selection.`n{0}`n`nIt requires Administrator (you will see a UAC prompt) and creates a backup and a System Restore point first.`n`nIt is strongly recommended to run Audit first and review the report.`n`nContinue with Apply?"
        "PreviewLineOk" = "Based on a quick Audit, about {0} item(s) would change."
        "PreviewLineFail" = "Could not compute the impact preview (the Apply itself will still report every change)."
        "StatusApplyLaunch" = "Launching elevated Apply... approve the UAC prompt, then wait."
        "StatusAuditLaunch" = "Running Audit (read-only)... please wait."
        "StatusImpactCalc" = "Calculating impact (quick Audit)... please wait."
        "StatusComplete" = "{0} complete: {1} checks (engine exit {2}). See results window."
        "StatusNoResults" = "{0} finished (engine exit {1}) but no results file was found."
        "ErrorEngineRun" = "Could not run the engine.`n`n{0}"
        "UndoNotFoundAsk" = "No Apply report folder was found on the Desktop.`n`nBrowse to a report folder that contains rollback.reg?"
        "UndoBrowseDesc" = "Select a report folder that contains rollback.reg"
        "UndoWarning" = "Undo will import rollback.reg from:`n{0}`n`nThis restores REGISTRY values only - it does NOT bring back removed Appx packages.`nRequires Administrator (you will see a UAC prompt).`n`nContinue?"
        "StatusUndoLaunch" = "Launching elevated restore... approve the UAC prompt."
        "ErrorUndoRun" = "Could not start the restore.`n`n{0}"
        "NodeBlockDesc" = "Block: {0}. Unchecking it skips the whole block."
        "NodeTweakDesc" = "{0}`r`n{1}\{2} = {3} [{4}]`r`nConfidence: {5} | Min build: {6} | Editions: {7}"
        "EditionsAll" = "all editions"
        "WouldChangeText" = " ({0} would change)"
        "GridShowAll" = "Show all (including compliant)"
        "GridTotal" = "Total: {0}  |  {1}"
        "GridExport" = "Export CSV..."
        "GridTitle" = "{0} results"
        "GridTitleEmpty" = "{0} results - no results"
        "GridTitleNoAttention" = "{0} results - nothing needs attention"
        "ErrorExport" = "Could not export results.`n`n{0}"
        "ColCategory" = "Category"
        "ColItem" = "Item"
        "ColStatus" = "Status"
        "ColCurrent" = "Current"
        "ColDesired" = "Desired"
        "ColMessage" = "Message"
        "LangToggle" = "EN / UA"
    }
    "UA" = @{
        "FormTitle" = "Win11 25H2 Calm Mode v{0} - конфігурація"
        "Header" = "Позначте потрібні категорії й твіки, спочатку запустіть Аудит, а Apply - лише після перегляду результатів."
        "HeaderProduct" = "Windows 11 25H2"
        "HeaderBuild" = "Build {0}.{1}"
        "HeaderEdition" = "Редакція: {0}"
        "HeaderMode" = "Режим: спочатку Аудит"
        "BadgeSafeDefault" = "Безпечно за замовчуванням"
        "BadgeAuditFirst" = "Спочатку Аудит"
        "BadgeNoChanges" = "Без змін до Apply"
        "FilterLabel" = "Фільтр:"
        "FilterClear" = "Очистити"
        "CategoryHeader" = "Категорії"
        "TweaksHeader" = "Твіки"
        "ColTweak" = "Твік"
        "ColConfidence" = "Надійність"
        "ColRisk" = "Ризик"
        "ColRegistry" = "Реєстр"
        "RiskSafe" = "Безпечно"
        "RiskNeedsVerify" = "Перевірити"
        "RiskOptIn" = "Opt-in"
        "RiskMayBeIgnored" = "Може ігноруватись"
        "RiskLegacy" = "Застаріле"
        "RiskUISetting" = "UI setting"
        "DetailSupport" = "Підтримка: {0}"
        "DetailRisk" = "Ризик: {0}"
        "DetailAdminRequired" = "Admin: потрібен для HKLM / системного Apply"
        "DetailAdminUser" = "Admin: значення поточного користувача, але GUI Apply все одно запускається elevated"
        "DetailRestartNone" = "Restart: зазвичай не потрібен"
        "DetailRestartExplorer" = "Restart: може знадобитися оновлення Провідника"
        "DetailRestartReboot" = "Restart: рекомендоване перезавантаження"
        "DetailRestartApp" = "Restart: за потреби закрийте/відкрийте відповідну програму"
        "DetailRollbackRegistry" = "Rollback: rollback.reg відновлює це registry value."
        "DetailRollbackAppx" = "Rollback: registry rollback НЕ повертає видалені Appx пакети."
        "BlockDetailDesc" = "Блок: {0}`r`nВибрано твіків: {1}/{2}`r`nРизик: {3}`r`nApply вимкнений до успішного Audit після кожної зміни вибору."
        "StatusAuditRequired" = "Вибір змінено. Запустіть Audit ще раз перед Apply."
        "StatusAuditPassedApplyEnabled" = "Audit завершено без помилок. Apply тепер доступний після перегляду результатів."
        "StatusAuditErrorsApplyDisabled" = "Audit завершено, але знайдено помилки. Apply лишається вимкненим."
        "ApplyBlockedRunAudit" = "Спочатку запустіть Audit. Apply вимкнений, доки поточний вибір не пройде успішний Audit."
        "TabSummary" = "Summary"
        "TabDetails" = "Details"
        "TabRaw" = "Raw log"
        "SummaryMetric" = "{0}: {1}"
        "SummaryWouldChange" = "Зміниться"
        "SummaryAlreadyOk" = "Вже OK"
        "SummaryChanged" = "Змінено"
        "SummaryNeedsVerification" = "Потребує перевірки"
        "SummaryUnsupported" = "Не підтримується"
        "SummaryErrors" = "Помилки"
        "SummaryTotal" = "Всього"
        "BtnSelectAll" = "Вибрати все"
        "BtnSelectNone" = "Зняти все"
        "BtnSave" = "Зберегти..."
        "BtnLoad" = "Завантажити..."
        "BtnAudit" = "Аудит (безпечно)"
        "BtnApply" = "Застосувати..."
        "BtnUndo" = "Відкат"
        "BtnClose" = "Закрити"
        "StatusReady" = "Готово. Аудит працює в режимі читання і нічого не змінює."
        "ErrorEngineNotFound" = "Скрипт рушія не знайдено:`n{0}"
        "ErrorCatalogLoad" = "Не вдалося завантажити каталог налаштувань із рушія.`n`n{0}"
        "StatusSaved" = "Конфігурацію збережено в {0}"
        "ErrorSave" = "Не вдалося зберегти конфігурацію.`n`n{0}"
        "StatusLoaded" = "Конфігурацію завантажено з {0}"
        "ErrorLoad" = "Не вдалося завантажити конфігурацію.`n`n{0}"
        "DialogApplyWarning" = "Застосування ЗМІНИТЬ налаштування системи відповідно до вашого вибору.`n{0}`n`nПотрібні права Адміністратора (з'явиться вікно UAC). Скрипт створить резервну копію та точку відновлення.`n`nНастійно рекомендується спочатку запустити Аудит і переглянути звіт.`n`nПродовжити Застосування?"
        "PreviewLineOk" = "За попереднім Аудитом, зміниться близько {0} параметрів."
        "PreviewLineFail" = "Не вдалося розрахувати вплив (але Застосування все одно покаже всі зміни у звіті)."
        "StatusApplyLaunch" = "Запуск Застосування від імені адміністратора... підтвердіть UAC і зачекайте."
        "StatusAuditLaunch" = "Виконання Аудиту (без змін)... зачекайте."
        "StatusImpactCalc" = "Розрахунок впливу (швидкий Аудит)... зачекайте."
        "StatusComplete" = "{0} завершено: {1} перевірок (вихід {2}). Дивіться вікно звітів."
        "StatusNoResults" = "{0} завершився (вихід {1}), але файл результатів не знайдено."
        "ErrorEngineRun" = "Не вдалося запустити рушій.`n`n{0}"
        "UndoNotFoundAsk" = "На Робочому столі не знайдено папку зі звітом.`n`nВибрати вручну папку, яка містить rollback.reg?"
        "UndoBrowseDesc" = "Оберіть папку зі звітом, що містить rollback.reg"
        "UndoWarning" = "Відкат імпортує rollback.reg з:`n{0}`n`nЦе відновить ЛИШЕ реєстр - видалені Appx пакети НЕ ПОВЕРНУТЬСЯ.`nПотрібні права Адміністратора (з'явиться вікно UAC).`n`nПродовжити?"
        "StatusUndoLaunch" = "Запуск відновлення... підтвердіть UAC."
        "ErrorUndoRun" = "Не вдалося запустити відновлення.`n`n{0}"
        "NodeBlockDesc" = "Блок: {0}. Якщо зняти позначку, весь блок буде пропущено."
        "NodeTweakDesc" = "{0}`r`n{1}\{2} = {3} [{4}]`r`nНадійність: {5} | Мін. білд: {6} | Редакції: {7}"
        "EditionsAll" = "всі редакції"
        "WouldChangeText" = " (зміниться {0})"
        "GridShowAll" = "Показати всі (включно з Compliant)"
        "GridTotal" = "Всього: {0}  |  {1}"
        "GridExport" = "Експорт CSV..."
        "GridTitle" = "Результати {0}"
        "GridTitleEmpty" = "Результати {0} - порожньо"
        "GridTitleNoAttention" = "Результати {0} - увага не потрібна"
        "ErrorExport" = "Не вдалося експортувати результати.`n`n{0}"
        "ColCategory" = "Категорія"
        "ColItem" = "Твік"
        "ColStatus" = "Статус"
        "ColCurrent" = "Поточне"
        "ColDesired" = "Бажане"
        "ColMessage" = "Повідомлення"
        "LangToggle" = "EN / UA"
    }
}

function Get-String {
    param([string]$Key, [object[]]$ArgsToFormat = $null)
    $str = $script:UIStrings[$script:Lang][$Key]
    if (-not $str) { $str = $script:UIStrings["EN"][$Key] }
    if ($null -ne $ArgsToFormat -and $ArgsToFormat.Count -gt 0) {
        return ($str -f $ArgsToFormat)
    }
    return $str
}

function Update-UILanguage {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param()

    if ($form) { $form.Text = Get-String "FormTitle" @($catalog.ScriptVersion) }
    if ($header -and $catalog) {
        $header.Text = Get-String "Header" @($catalog.Build, $catalog.UBR, $catalog.EditionGroup)
    }
    if ($lblProduct) { $lblProduct.Text = Get-String "HeaderProduct" }
    if ($lblBuild) { $lblBuild.Text = Get-String "HeaderBuild" @($catalog.Build, $catalog.UBR) }
    if ($lblEdition) { $lblEdition.Text = Get-String "HeaderEdition" @($catalog.EditionGroup) }
    if ($lblMode) { $lblMode.Text = Get-String "HeaderMode" }
    if ($badgeSafe) { $badgeSafe.Text = Get-String "BadgeSafeDefault" }
    if ($badgeAudit) { $badgeAudit.Text = Get-String "BadgeAuditFirst" }
    if ($badgeNoChanges) { $badgeNoChanges.Text = Get-String "BadgeNoChanges" }
    if ($lblCategories) { $lblCategories.Text = Get-String "CategoryHeader" }
    if ($lblTweaks) { $lblTweaks.Text = Get-String "TweaksHeader" }
    if ($categoryList -and $categoryList.Columns.Count -gt 0) { $categoryList.Columns[0].Text = Get-String "CategoryHeader" }
    if ($tweakList -and $tweakList.Columns.Count -ge 4) {
        $tweakList.Columns[0].Text = Get-String "ColTweak"
        $tweakList.Columns[1].Text = Get-String "ColConfidence"
        $tweakList.Columns[2].Text = Get-String "ColRisk"
        $tweakList.Columns[3].Text = Get-String "ColRegistry"
    }
    if ($lblFilter) { $lblFilter.Text = Get-String "FilterLabel" }
    if ($btnFilterClear) { $btnFilterClear.Text = Get-String "FilterClear" }
    if ($btnSelectAll) { $btnSelectAll.Text = Get-String "BtnSelectAll" }
    if ($btnSelectNone) { $btnSelectNone.Text = Get-String "BtnSelectNone" }
    if ($btnSave) { $btnSave.Text = Get-String "BtnSave" }
    if ($btnLoad) { $btnLoad.Text = Get-String "BtnLoad" }
    if ($btnAudit) { $btnAudit.Text = Get-String "BtnAudit" }
    if ($btnApply) { $btnApply.Text = Get-String "BtnApply" }
    if ($btnUndo) { $btnUndo.Text = Get-String "BtnUndo" }
    if ($btnClose) { $btnClose.Text = Get-String "BtnClose" }
    if ($btnLanguage) { $btnLanguage.Text = Get-String "LangToggle" }

    if ($status) {
        if ($status.Text -match "Ready|Готово") {
            $status.Text = Get-String "StatusReady"
        }
    }

    # Refresh canonical block/tweak labels.
    if ($script:BlockEntries) {
        foreach ($entry in $script:BlockEntries) {
            $bk = $entry.Node.Tag.Key
            $n = if ($script:PerBlockCounts -and $script:PerBlockCounts[$bk]) { [int]$script:PerBlockCounts[$bk] } else { 0 }
            $entry.BaseTitle = Get-LocalizedBlockTitle -Key $bk -FallbackTitle $entry.Node.Tag.TitleEN
            $entry.Node.Text = if ($n -gt 0) { $entry.BaseTitle + (Get-String "WouldChangeText" @($n)) } else { $entry.BaseTitle }
            foreach ($child in $entry.Children) {
                if ($child.Tag -and $child.Tag.Kind -eq "tweak") {
                    $child.Text = Get-TweakNodeText -Detail $child.Tag.Detail
                }
            }
        }
    }

    if ($applyFilter) { & $applyFilter }

    if ($tweakList -and $tweakList.SelectedItems.Count -gt 0) {
        Update-DescriptionFromTag -Tag $tweakList.SelectedItems[0].Tag
    } elseif ($categoryList -and $categoryList.SelectedItems.Count -gt 0) {
        Update-DescriptionFromTag -Tag $categoryList.SelectedItems[0].Tag.Node.Tag
    }
    if ($updateListColumnLayout) { & $updateListColumnLayout }
}


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
        "$(Get-String "ErrorEngineNotFound" @($EnginePath))",
        "Win11 25H2 Calm Mode", "OK", "Error") | Out-Null
    return
}

# Resolve the 64-bit Windows PowerShell so the engine runs in the correct registry view
# even if this GUI was launched from a 32-bit host.
function Get-PowerShellExe {
    $candidates = @(
        (Join-Path $env:SystemRoot "Sysnative\WindowsPowerShell\v1.0\powershell.exe"),
        (Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe")
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
    $out = & $psExe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $EnginePath -ExportCatalog 2>$null
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
        "$(Get-String "ErrorCatalogLoad" @($_.Exception.Message))",
        "Win11 25H2 Calm Mode", "OK", "Error") | Out-Null
    return
}

$script:TweakDetailsByKey = @{}
foreach ($t in $catalog.Tweaks) {
    if (-not [string]::IsNullOrWhiteSpace([string]$t.Key)) {
        $script:TweakDetailsByKey[([string]$t.Key).ToLowerInvariant()] = $t
    }
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
$blockTitles_EN = @{
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

$blockTitles_UA = @{
    "WindowsAI"               = "Windows AI / Recall / Copilot"
    "Widgets"                 = "Віджети / Новини та інтереси"
    "CloudContent"            = "Хмарний контент / реклама / рекомендації"
    "Privacy"                 = "Приватність / діагностика / реклама"
    "Search"                  = "Пошук"
    "StartTaskbar"            = "Меню Пуск / Панель завдань / Провідник"
    "WindowsUpdate"           = "Оновлення Windows"
    "DeliveryOptimization"    = "Оптимізація доставки (без P2P)"
    "EdgeQuietMode"           = "Тихий режим Microsoft Edge"
    "DeveloperMode"           = "Режим розробника / sideloading (ризик для безпеки)"
    "LongPaths"               = "Довгі шляхи Win32"
    "FastStartupDisable"      = "Вимкнути швидкий запуск (Fast Startup)"
    "Gaming"                  = "Ігри (Game DVR / Game Bar)"
    "ManualWindowsUpdateMode" = "Ручний режим оновлень (AUOptions=2)"
    "TargetReleaseVersionPin" = "Фіксація версії (може блокувати оновлення)"
    "RemoveCopilotApp"        = "Очищення Appx: видалити Copilot (opt-in)"
    "RemoveTeamsPersonal"     = "Очищення Appx: видалити Teams personal (opt-in)"
    "RemoveXboxApps"          = "Очищення Appx: видалити Xbox apps (opt-in)"
    "RemoveOneDrive"          = "Очищення Appx: видалити OneDrive (opt-in)"
}

function Get-LocalizedBlockTitle {
    param([string]$Key, [string]$FallbackTitle)
    $dict = if ($script:Lang -eq "UA") { $blockTitles_UA } else { $blockTitles_EN }
    if ($dict.ContainsKey($Key)) { return $dict[$Key] }
    if (-not [string]::IsNullOrWhiteSpace($FallbackTitle)) { return $FallbackTitle }
    return $Key
}

$categoryTitles_UA = @{
    "Windows AI" = "Windows AI"
    "Widgets" = "Віджети"
    "Cloud Content" = "Хмарний контент"
    "Privacy" = "Приватність"
    "Search" = "Пошук"
    "Start" = "Пуск"
    "Taskbar" = "Панель завдань"
    "Explorer" = "Провідник"
    "Windows Update" = "Оновлення Windows"
    "Windows Update UI" = "Інтерфейс Windows Update"
    "Delivery Optimization" = "Оптимізація доставки"
    "Microsoft Edge" = "Microsoft Edge"
    "Developer" = "Розробник"
    "Power" = "Живлення"
    "Gaming" = "Ігри"
    "Appx Cleanup" = "Очищення Appx"
    "App Cleanup" = "Очищення програм"
    "Preflight" = "Перед перевіркою"
    "Apply" = "Застосування"
    "Report" = "Звіт"
}

$confidenceTitles_UA = @{
    "Official" = "Офіційно"
    "BestEffort" = "За можливістю"
    "Deprecated" = "Застаріле"
    "UISetting" = "Налаштування інтерфейсу"
    "RequiresVerification" = "Потребує перевірки"
}

$itemTitles_UA = @{
    "Microsoft Copilot app" = "Програма Microsoft Copilot"
    "Microsoft Teams personal" = "Особистий Microsoft Teams"
    "Xbox apps" = "Програми Xbox"
    "OneDrive uninstall" = "Видалення OneDrive"
    "Windows version" = "Версія Windows"
    "Target release match" = "Збіг цільового релізу"
    "Administrator" = "Адміністратор"
    "Per-user hive (HKCU)" = "Профіль користувача (HKCU)"
    "PowerShell bitness" = "Розрядність PowerShell"
    "Pending reboot" = "Очікується перезавантаження"
    "Run configuration" = "Конфігурація запуску"
    "Policy refresh" = "Оновлення політик"
    "gpupdate /force" = "gpupdate /force"
    "gpresult.html" = "gpresult.html"
    "Restart Explorer" = "Перезапуск Провідника"
}

$descriptionTranslations_UA = @{
    "Make Recall optional component unavailable" = "Зробити компонент Recall недоступним для ввімкнення"
    "Disable Recall snapshot saving / AI data analysis" = "Вимкнути збереження знімків Recall / аналіз AI-даних"
    "Disable Recall snapshot saving for current user" = "Вимкнути збереження знімків Recall для поточного користувача"
    "Block Recall export where supported" = "Заблокувати експорт Recall, де це підтримується"
    "Disable Click to Do" = "Вимкнути Click to Do"
    "Disable Click to Do for current user" = "Вимкнути Click to Do для поточного користувача"
    "Disable AI agent/search in Settings where supported" = "Вимкнути AI-агента/пошук у Параметрах, де це підтримується"
    "Disable Paint Cocreator" = "Вимкнути Paint Cocreator"
    "Disable Paint Generative Fill" = "Вимкнути генеративне заповнення в Paint"
    "Disable Paint Image Creator" = "Вимкнути створення зображень у Paint"
    "Turn off legacy Windows Copilot" = "Вимкнути застарілий Windows Copilot"
    "Hide Copilot taskbar button if present" = "Сховати кнопку Copilot на панелі завдань, якщо вона є"
    "Request Microsoft Copilot app removal where supported" = "Запросити видалення програми Microsoft Copilot, де це підтримується"
    "Request Microsoft Copilot app removal for current user where supported" = "Запросити видалення програми Microsoft Copilot для поточного користувача, де це підтримується"
    "Disable Widgets / News and Interests" = "Вимкнути віджети / Новини та інтереси"
    "Disable Widgets board where supported" = "Вимкнути дошку віджетів, де це підтримується"
    "Disable Widgets on lock screen where supported" = "Вимкнути віджети на екрані блокування, де це підтримується"
    "Hide Widgets button on taskbar" = "Сховати кнопку віджетів на панелі завдань"
    "Disable Windows consumer experiences" = "Вимкнути споживчі можливості Windows"
    "Disable soft landing tips/prompts" = "Вимкнути підказки та пропозиції soft landing"
    "Disable cloud optimized content" = "Вимкнути хмарно оптимізований контент"
    "Disable Microsoft account state consumer content" = "Вимкнути споживчий контент стану акаунта Microsoft"
    "Disable Windows Spotlight features" = "Вимкнути можливості Windows Spotlight"
    "Disable Spotlight in Action Center" = "Вимкнути Spotlight у Центрі дій"
    "Disable Spotlight suggestions in Settings" = "Вимкнути пропозиції Spotlight у Параметрах"
    "Disable Windows welcome experience after updates" = "Вимкнути вітальний екран Windows після оновлень"
    "Disable third-party suggestions" = "Вимкнути сторонні пропозиції"
    "Disable tailored experiences with diagnostic data" = "Вимкнути персоналізований досвід на основі діагностичних даних"
    "Disable 'Get even more out of Windows' post-OOBE prompt" = "Вимкнути підказку 'Отримайте ще більше від Windows' після OOBE"
    "Disable Advertising ID by policy" = "Вимкнути рекламний ідентифікатор через політику"
    "Disable Advertising ID for current user" = "Вимкнути рекламний ідентифікатор для поточного користувача"
    "Disable tailored experiences" = "Вимкнути персоналізований досвід"
    "Disable feedback frequency prompts" = "Вимкнути часті запити відгуків"
    "Disable feedback prompt period" = "Вимкнути періодичні запити відгуків"
    "Disable Search highlights / dynamic content in Windows Search Box" = "Вимкнути Search highlights / динамічний контент у пошуку Windows"
    "Disable cloud search integration in Windows Search" = "Вимкнути інтеграцію хмарного пошуку в Windows Search"
    "Disable location-aware Windows Search" = "Вимкнути пошук Windows з урахуванням розташування"
    "Disable web search where policy is honored" = "Вимкнути веб-пошук, де політика застосовується"
    "Do not use web results in Search where policy is honored" = "Не використовувати веб-результати в Пошуку, де політика застосовується"
    "Disable Search box suggestions in Explorer/Start" = "Вимкнути пропозиції у полі пошуку Провідника/Пуску"
    "Hide Recommended section in Start where supported" = "Сховати розділ Рекомендоване в Пуску, де це підтримується"
    "Hide Recommended section in Start for current user where supported" = "Сховати розділ Рекомендоване в Пуску для поточного користувача, де це підтримується"
    "Hide recommended personalized sites" = "Сховати рекомендовані персоналізовані сайти"
    "Hide recommended personalized sites for current user" = "Сховати рекомендовані персоналізовані сайти для поточного користувача"
    "Hide recently added apps" = "Сховати нещодавно додані програми"
    "Hide recently added apps for current user" = "Сховати нещодавно додані програми для поточного користувача"
    "Hide frequently used apps" = "Сховати часто використовувані програми"
    "Hide frequently used apps for current user" = "Сховати часто використовувані програми для поточного користувача"
    "Align taskbar to left" = "Вирівняти панель завдань ліворуч"
    "Hide Task View button" = "Сховати кнопку Подання завдань"
    "Hide Chat/Teams consumer button if present" = "Сховати кнопку Chat/Teams consumer, якщо вона є"
    "Do not track recent documents in Start/Jump Lists" = "Не відстежувати нещодавні документи в Пуску/списках переходів"
    "Do not track frequently used programs" = "Не відстежувати часто використовувані програми"
    "Disable Start recommendations UI toggle where supported" = "Вимкнути UI-перемикач рекомендацій у Пуску, де це підтримується"
    "Turn off account/subscription notifications on the Start user tile" = "Вимкнути сповіщення про акаунт/підписку на плитці користувача в Пуску"
    "Hide account-related notifications on Start (UI toggle)" = "Сховати сповіщення, пов'язані з акаунтом, у Пуску (UI-перемикач)"
    "Show file extensions in Explorer" = "Показувати розширення файлів у Провіднику"
    "Disable sync provider notifications in Explorer" = "Вимкнути сповіщення провайдерів синхронізації в Провіднику"
    "Open Explorer to This PC" = "Відкривати Провідник у Цей ПК"
    "Keep Windows Update enabled" = "Залишити Windows Update увімкненим"
    "Notify before downloading and installing updates (manual updates)" = "Сповіщати перед завантаженням і встановленням оновлень (ручні оновлення)"
    "Avoid auto-restart while user is logged on" = "Уникати автоперезавантаження, поки користувач увійшов у систему"
    "Do not include drivers with Windows Updates" = "Не включати драйвери в оновлення Windows"
    "Do not automatically receive optional updates / CFRs" = "Не отримувати автоматично необов'язкові оновлення / CFR"
    "Enable feature update deferral" = "Увімкнути відкладення функціональних оновлень"
    "Enable quality update deferral" = "Увімкнути відкладення якісних оновлень"
    "Disable Windows Insider preview build management by user" = "Заборонити користувачу керувати Windows Insider preview builds"
    "Set active hours manually" = "Налаштувати активні години вручну"
    "Active hours start" = "Початок активних годин"
    "Active hours end" = "Кінець активних годин"
    "Enable target release version pinning" = "Увімкнути фіксацію цільової версії релізу"
    "Target product version" = "Цільова версія продукту"
    "Turn off 'Get latest updates as soon as available' UI toggle" = "Вимкнути UI-перемикач 'Отримувати останні оновлення, щойно вони доступні'"
    "Disable peer-to-peer Delivery Optimization" = "Вимкнути peer-to-peer в Оптимізації доставки"
    "Disable Edge Startup Boost" = "Вимкнути пришвидшення запуску Edge"
    "Do not keep Edge background apps running after close" = "Не залишати фонові програми Edge після закриття"
    "Hide Edge first-run experience" = "Сховати перший запуск Edge"
    "Do not launch Edge automatically at Windows startup" = "Не запускати Edge автоматично під час старту Windows"
    "Disable Edge promotional tabs" = "Вимкнути рекламні вкладки Edge"
    "Disable Edge sidebar/hubs where supported" = "Вимкнути бічну панель/hubs Edge, де це підтримується"
    "Enable Developer Mode policy" = "Увімкнути політику режиму розробника"
    "Allow all trusted apps / sideloading policy" = "Дозволити всі довірені програми / політику sideloading"
    "Enable Developer Mode UI compatibility key" = "Увімкнути UI-ключ сумісності режиму розробника"
    "Allow trusted apps UI compatibility key" = "Дозволити UI-ключ сумісності для довірених програм"
    "Enable Win32 long paths" = "Увімкнути довгі шляхи Win32"
    "Disable Fast Startup local setting" = "Вимкнути локальне налаштування швидкого запуску"
    "Do not require Fast Startup by policy" = "Не вимагати швидкий запуск через політику"
    "Disable background capture / Game DVR" = "Вимкнути фоновий запис / Game DVR"
    "Disable Game DVR in GameConfigStore" = "Вимкнути Game DVR у GameConfigStore"
    "Hide Game Bar startup panel" = "Сховати стартову панель Game Bar"
}

function Get-LocalizedConfidence {
    param([string]$Confidence)
    if ($script:Lang -ne "UA") { return $Confidence }
    if ($confidenceTitles_UA.ContainsKey($Confidence)) { return $confidenceTitles_UA[$Confidence] }
    return $Confidence
}

function Get-LocalizedCategoryTitle {
    param([string]$Category)
    if ($script:Lang -ne "UA") { return $Category }
    if ($categoryTitles_UA.ContainsKey($Category)) { return $categoryTitles_UA[$Category] }
    return $Category
}

function Get-LocalizedTweakDescription {
    param([object]$Detail)

    if ($null -eq $Detail) { return "" }
    $description = [string]$Detail.Description
    if ($script:Lang -ne "UA") { return $description }

    if ($description -match "^Disable ContentDeliveryManager setting: (.+)$") {
        return "Вимкнути параметр ContentDeliveryManager: $($matches[1])"
    }
    if ($description -match "^Set diagnostic data level \(AllowTelemetry=(.+)\)$") {
        return "Встановити рівень діагностичних даних (AllowTelemetry=$($matches[1]))"
    }
    if ($description -match "^Defer feature updates by (.+) days$") {
        return "Відкласти функціональні оновлення на $($matches[1]) дн."
    }
    if ($description -match "^Defer quality updates by (.+) days$") {
        return "Відкласти якісні оновлення на $($matches[1]) дн."
    }
    if ($description -match "^Set taskbar search mode to (.+)$") {
        $mode = switch ($matches[1]) {
            "Hidden" { "приховано" }
            "Icon" { "іконка" }
            "Box" { "поле пошуку" }
            default { $matches[1] }
        }
        return "Встановити режим пошуку на панелі завдань: $mode"
    }
    if ($description -match "^Pin Windows feature version to (.+)$") {
        return "Закріпити функціональну версію Windows: $($matches[1])"
    }

    if ($descriptionTranslations_UA.ContainsKey($description)) { return $descriptionTranslations_UA[$description] }
    return $description
}

function Get-TweakNodeText {
    param([object]$Detail)
    return ("{0}  [{1}]" -f (Get-LocalizedTweakDescription -Detail $Detail), (Get-LocalizedConfidence $Detail.Confidence))
}

function Get-RegistryPreview {
    param([object]$Detail)
    if ($null -eq $Detail) { return "" }
    return ("{0}\{1} = {2}" -f $Detail.Path, $Detail.Name, $Detail.Value)
}

function Get-RiskKey {
    param([object]$Detail, [string]$BlockKey)
    if ($null -eq $Detail) {
        if ($BlockKey -match "^Remove") { return "RiskOptIn" }
        return "RiskSafe"
    }
    switch ([string]$Detail.Confidence) {
        "RequiresVerification" { return "RiskNeedsVerify" }
        "BestEffort" { return "RiskOptIn" }
        "Deprecated" { return "RiskLegacy" }
        "UISetting" { return "RiskUISetting" }
        default {
            if ($BlockKey -match "^Remove") { return "RiskOptIn" }
            return "RiskSafe"
        }
    }
}

function Get-RiskText {
    param([object]$Detail, [string]$BlockKey)
    return (Get-String (Get-RiskKey -Detail $Detail -BlockKey $BlockKey))
}

function Get-ConfidenceBackColor {
    param([string]$Confidence)
    switch ($Confidence) {
        "Official" { return [System.Drawing.Color]::FromArgb(232, 246, 239) }
        "RequiresVerification" { return [System.Drawing.Color]::FromArgb(255, 248, 219) }
        "BestEffort" { return [System.Drawing.Color]::FromArgb(232, 240, 247) }
        "Deprecated" { return [System.Drawing.Color]::FromArgb(255, 236, 224) }
        "UISetting" { return [System.Drawing.Color]::FromArgb(241, 243, 245) }
        default { return [System.Drawing.Color]::White }
    }
}

function Get-BlockRiskText {
    param($Entry)
    if ($Entry.Node.Tag.Key -match "^Remove") { return Get-String "RiskOptIn" }
    $hasVerify = $false
    $hasBestEffort = $false
    $hasDeprecated = $false
    foreach ($child in $Entry.Children) {
        if ($null -eq $child.Tag -or $child.Tag.Kind -ne "tweak") { continue }
        switch ([string]$child.Tag.Detail.Confidence) {
            "RequiresVerification" { $hasVerify = $true }
            "BestEffort" { $hasBestEffort = $true }
            "Deprecated" { $hasDeprecated = $true }
        }
    }
    if ($hasVerify) { return Get-String "RiskNeedsVerify" }
    if ($hasBestEffort) { return Get-String "RiskOptIn" }
    if ($hasDeprecated) { return Get-String "RiskLegacy" }
    return Get-String "RiskSafe"
}

function Get-SelectedTweakCount {
    param($Entry)
    $n = 0
    foreach ($child in $Entry.Children) {
        if ($child.Checked) { $n++ }
    }
    return $n
}

function Get-SupportSummary {
    param([object]$Detail)
    $parts = New-Object System.Collections.ArrayList
    $minBuild = "$($Detail.MinBuild)$(if ($Detail.MinUBR -gt 0) { ".$($Detail.MinUBR)" })"
    if ($Detail.MinBuild -gt 0) { [void]$parts.Add("build >= $minBuild") }
    $ed = if ($Detail.Editions -and $Detail.Editions.Count -gt 0) { ($Detail.Editions -join ", ") } else { Get-String "EditionsAll" }
    [void]$parts.Add("editions: $ed")
    [void]$parts.Add("confidence: $(Get-LocalizedConfidence ([string]$Detail.Confidence))")
    return ($parts -join "; ")
}

function Get-AdminDetailText {
    param([object]$Detail, [string]$BlockKey)
    if ($BlockKey -match "^Remove" -or [string]$Detail.Path -like "HKLM:*") {
        return Get-String "DetailAdminRequired"
    }
    return Get-String "DetailAdminUser"
}

function Get-RestartDetailText {
    param([object]$Detail, [string]$BlockKey)
    if ($BlockKey -eq "LongPaths" -or $BlockKey -eq "FastStartupDisable") { return Get-String "DetailRestartReboot" }
    if ($BlockKey -eq "StartTaskbar" -or $BlockKey -eq "Widgets" -or $BlockKey -eq "CloudContent") { return Get-String "DetailRestartExplorer" }
    if ($BlockKey -eq "EdgeQuietMode" -or $BlockKey -match "^Remove") { return Get-String "DetailRestartApp" }
    return Get-String "DetailRestartNone"
}

function Get-RollbackDetailText {
    param([string]$BlockKey)
    if ($BlockKey -match "^Remove") { return Get-String "DetailRollbackAppx" }
    return Get-String "DetailRollbackRegistry"
}

function Update-DescriptionFromTag {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param($Tag)

    if ($null -eq $desc) { return }
    if ($null -eq $Tag) { $desc.Text = ""; return }
    if ($Tag.Kind -eq "tweak") {
        $d = $Tag.Detail
        $blockKey = [string]$d.BlockKey
        $ed = if ($d.Editions -and $d.Editions.Count -gt 0) { ($d.Editions -join ", ") } else { (Get-String "EditionsAll") }
        $base = Get-String "NodeTweakDesc" @(
            (Get-LocalizedTweakDescription -Detail $d),
            $d.Path,
            $d.Name,
            $d.Value,
            $d.Type,
            (Get-LocalizedConfidence $d.Confidence),
            "$($d.MinBuild)$(if ($d.MinUBR -gt 0) { ".$($d.MinUBR)" })",
            $ed
        )
        $extra = @(
            (Get-String "DetailSupport" @((Get-SupportSummary -Detail $d))),
            (Get-String "DetailRisk" @((Get-RiskText -Detail $d -BlockKey $blockKey))),
            (Get-AdminDetailText -Detail $d -BlockKey $blockKey),
            (Get-RestartDetailText -Detail $d -BlockKey $blockKey),
            (Get-RollbackDetailText -BlockKey $blockKey)
        )
        $desc.Text = $base + "`r`n" + ($extra -join "`r`n")
    } elseif ($Tag.Kind -eq "block") {
        $entry = $script:BlockEntries | Where-Object { $_.Node.Tag.Key -eq $Tag.Key } | Select-Object -First 1
        if ($entry) {
            $blockText = Get-String "BlockDetailDesc" @(
                (Get-LocalizedBlockTitle -Key $Tag.Key -FallbackTitle $Tag.TitleEN),
                (Get-SelectedTweakCount -Entry $entry),
                $entry.Children.Count,
                (Get-BlockRiskText -Entry $entry)
            )
            if ($Tag.Key -match "^Remove") {
                $blockText += "`r`n" + (Get-String "DetailAdminRequired")
                $blockText += "`r`n" + (Get-String "DetailRollbackAppx")
            }
            $desc.Text = $blockText
        } else {
            $desc.Text = (Get-String "NodeBlockDesc" @($Tag.Key))
        }
    }
}

function Get-LocalizedResultItem {
    param([object]$Row)

    if ($script:Lang -ne "UA") { return $Row.Item }

    $key = ""
    if (-not [string]::IsNullOrWhiteSpace([string]$Row.Path) -and -not [string]::IsNullOrWhiteSpace([string]$Row.Name)) {
        $key = "{0}\{1}" -f $Row.Path, $Row.Name
    }
    if ($key -and $script:TweakDetailsByKey.ContainsKey($key.ToLowerInvariant())) {
        return Get-LocalizedTweakDescription -Detail $script:TweakDetailsByKey[$key.ToLowerInvariant()]
    }
    if ($descriptionTranslations_UA.ContainsKey([string]$Row.Item)) {
        $fakeDetail = [pscustomobject]@{ Description = [string]$Row.Item }
        return Get-LocalizedTweakDescription -Detail $fakeDetail
    }
    if ($itemTitles_UA.ContainsKey([string]$Row.Item)) { return $itemTitles_UA[([string]$Row.Item)] }
    return $Row.Item
}

function ConvertTo-DisplayResult {
    param([object]$Row)
    return [pscustomobject]@{
        Category = Get-LocalizedCategoryTitle ([string]$Row.Category)
        Item = Get-LocalizedResultItem -Row $Row
        Status = $Row.Status
        CurrentValue = $Row.CurrentValue
        DesiredValue = $Row.DesiredValue
        Confidence = Get-LocalizedConfidence ([string]$Row.Confidence)
        Support = $Row.Support
        Message = $Row.Message
    }
}

# ------------------------------------------------------------
# Build the form
# ------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = (Get-String "FormTitle" @($catalog.ScriptVersion))
$form.Size = New-Object System.Drawing.Size(1220, 840)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = New-Object System.Drawing.Size(1040, 640)
$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
$form.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96)
$form.BackColor = [System.Drawing.Color]::FromArgb(248, 249, 250)
$uiFont = New-Object System.Drawing.Font("Segoe UI", 9)
$uiFontBold = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Font = $uiFont

function New-BadgeLabel {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$Width,
        [System.Drawing.Color]$BackColor,
        [System.Drawing.Color]$ForeColor
    )
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $Text
    $l.Location = New-Object System.Drawing.Point($X, $Y)
    $l.Size = New-Object System.Drawing.Size($Width, 22)
    $l.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $l.BackColor = $BackColor
    $l.ForeColor = $ForeColor
    $l.Font = $uiFont
    return $l
}

# Top bar: compact environment/status panel plus filter.
$topBar = New-Object System.Windows.Forms.Panel
$topBar.Dock = "Top"
$topBar.Height = 118
$topBar.BackColor = [System.Drawing.Color]::White

$header = New-Object System.Windows.Forms.Label
$header.Location = New-Object System.Drawing.Point(12, 10)
$header.Size = New-Object System.Drawing.Size(1038, 18)
$header.Anchor = "Top, Left, Right"
$header.Text = (Get-String "Header" @($catalog.Build, $catalog.UBR, $catalog.EditionGroup))
$header.ForeColor = [System.Drawing.Color]::FromArgb(73, 80, 87)

$lblProduct = New-Object System.Windows.Forms.Label
$lblProduct.Text = (Get-String "HeaderProduct")
$lblProduct.Location = New-Object System.Drawing.Point(12, 34)
$lblProduct.Size = New-Object System.Drawing.Size(170, 24)
$lblProduct.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$lblProduct.ForeColor = [System.Drawing.Color]::FromArgb(33, 37, 41)

$lblBuild = New-Object System.Windows.Forms.Label
$lblBuild.Text = (Get-String "HeaderBuild" @($catalog.Build, $catalog.UBR))
$lblBuild.Location = New-Object System.Drawing.Point(196, 37)
$lblBuild.Size = New-Object System.Drawing.Size(135, 21)
$lblBuild.ForeColor = [System.Drawing.Color]::FromArgb(33, 37, 41)

$lblEdition = New-Object System.Windows.Forms.Label
$lblEdition.Text = (Get-String "HeaderEdition" @($catalog.EditionGroup))
$lblEdition.Location = New-Object System.Drawing.Point(342, 37)
$lblEdition.Size = New-Object System.Drawing.Size(135, 21)
$lblEdition.ForeColor = [System.Drawing.Color]::FromArgb(33, 37, 41)

$lblMode = New-Object System.Windows.Forms.Label
$lblMode.Text = (Get-String "HeaderMode")
$lblMode.Location = New-Object System.Drawing.Point(488, 37)
$lblMode.Size = New-Object System.Drawing.Size(160, 21)
$lblMode.ForeColor = [System.Drawing.Color]::FromArgb(33, 37, 41)

$badgeSafe = New-BadgeLabel -Text (Get-String "BadgeSafeDefault") -X 12 -Y 66 -Width 145 `
    -BackColor ([System.Drawing.Color]::FromArgb(232, 246, 239)) -ForeColor ([System.Drawing.Color]::FromArgb(25, 135, 84))
$badgeAudit = New-BadgeLabel -Text (Get-String "BadgeAuditFirst") -X 165 -Y 66 -Width 96 `
    -BackColor ([System.Drawing.Color]::FromArgb(232, 240, 254)) -ForeColor ([System.Drawing.Color]::FromArgb(13, 110, 253))
$badgeNoChanges = New-BadgeLabel -Text (Get-String "BadgeNoChanges") -X 269 -Y 66 -Width 145 `
    -BackColor ([System.Drawing.Color]::FromArgb(241, 243, 245)) -ForeColor ([System.Drawing.Color]::FromArgb(73, 80, 87))

$lblFilter = New-Object System.Windows.Forms.Label
$lblFilter.Text = (Get-String "FilterLabel")
$lblFilter.Location = New-Object System.Drawing.Point(432, 69)
$lblFilter.AutoSize = $true

$txtFilter = New-Object System.Windows.Forms.TextBox
$txtFilter.Location = New-Object System.Drawing.Point(482, 66)
$txtFilter.Size = New-Object System.Drawing.Size(320, 24)
$txtFilter.Anchor = "Top, Left, Right"

$btnFilterClear = New-Object System.Windows.Forms.Button
$btnFilterClear.Text = (Get-String "FilterClear")
$btnFilterClear.Size = New-Object System.Drawing.Size(70, 26)
$btnFilterClear.Location = New-Object System.Drawing.Point(810, 65)
$btnFilterClear.Anchor = "Top, Left"

$topBar.Controls.AddRange(@(
    $header, $lblProduct, $lblBuild, $lblEdition, $lblMode,
    $badgeSafe, $badgeAudit, $badgeNoChanges,
    $lblFilter, $txtFilter, $btnFilterClear
))

$btnLanguage = New-Object System.Windows.Forms.Button
$btnLanguage.Text = Get-String "LangToggle"
$btnLanguage.Size = New-Object System.Drawing.Size(76, 26)
$btnLanguage.Location = New-Object System.Drawing.Point(890, 65)
$btnLanguage.Anchor = "Top, Left"
$btnLanguage.Add_Click({
    $script:Lang = if ($script:Lang -eq "EN") { "UA" } else { "EN" }
    Update-UILanguage
})
$topBar.Controls.Add($btnLanguage)

function Update-TopBarLayout {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param()
    if (-not $topBar -or -not $txtFilter -or -not $btnFilterClear -or -not $btnLanguage) { return }
    $w = $topBar.ClientSize.Width
    if ($w -le 0 -and $form) { $w = $form.ClientSize.Width }
    if ($w -le 0) { return }

    $rightMargin = 12
    $gap = 8
    $languageX = [Math]::Max(650, $w - $rightMargin - $btnLanguage.Width)
    $clearX = [Math]::Max(570, $languageX - $gap - $btnFilterClear.Width)
    $filterWidth = [Math]::Max(140, $clearX - $gap - $txtFilter.Left)

    $btnLanguage.Location = New-Object System.Drawing.Point($languageX, 65)
    $btnFilterClear.Location = New-Object System.Drawing.Point($clearX, 65)
    $txtFilter.Size = New-Object System.Drawing.Size($filterWidth, 24)
}

$topBar.Add_Resize({ Update-TopBarLayout })
$form.Add_Shown({ Update-TopBarLayout })

$form.Controls.Add($topBar)

# Hidden TreeView remains the canonical selection model. The visible UI below is a
# friendlier two-pane view over these same TreeNode objects.
$tree = New-Object System.Windows.Forms.TreeView
$tree.CheckBoxes = $true
$tree.HideSelection = $false

$mainSplit = New-Object System.Windows.Forms.SplitContainer
$mainSplit.Dock = "Fill"
$mainSplit.Orientation = [System.Windows.Forms.Orientation]::Vertical
$mainSplit.SplitterDistance = 555
$mainSplit.BackColor = [System.Drawing.Color]::FromArgb(222, 226, 230)
$script:SplitterMovedByUser = $false

$leftPanel = New-Object System.Windows.Forms.Panel
$leftPanel.Dock = "Fill"
$leftPanel.BackColor = [System.Drawing.Color]::White
$lblCategories = New-Object System.Windows.Forms.Label
$lblCategories.Text = Get-String "CategoryHeader"
$lblCategories.Dock = "Top"
$lblCategories.Height = 30
$lblCategories.Padding = New-Object System.Windows.Forms.Padding -ArgumentList 10, 7, 0, 0
$lblCategories.Font = $uiFontBold

$categoryList = New-Object System.Windows.Forms.ListView
$categoryList.Dock = "Fill"
$categoryList.View = [System.Windows.Forms.View]::Details
$categoryList.CheckBoxes = $true
$categoryList.FullRowSelect = $true
$categoryList.HideSelection = $false
$categoryList.MultiSelect = $false
$categoryList.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$categoryList.ShowItemToolTips = $true
[void]$categoryList.Columns.Add((Get-String "CategoryHeader"), 260)
[void]$categoryList.Columns.Add((Get-String "ColRisk"), 90)

$leftPanel.Controls.Add($categoryList)
$leftPanel.Controls.Add($lblCategories)

$rightPanel = New-Object System.Windows.Forms.Panel
$rightPanel.Dock = "Fill"
$rightPanel.BackColor = [System.Drawing.Color]::White
$lblTweaks = New-Object System.Windows.Forms.Label
$lblTweaks.Text = Get-String "TweaksHeader"
$lblTweaks.Dock = "Top"
$lblTweaks.Height = 30
$lblTweaks.Padding = New-Object System.Windows.Forms.Padding -ArgumentList 10, 7, 0, 0
$lblTweaks.Font = $uiFontBold

$tweakList = New-Object System.Windows.Forms.ListView
$tweakList.Dock = "Fill"
$tweakList.View = [System.Windows.Forms.View]::Details
$tweakList.CheckBoxes = $true
$tweakList.FullRowSelect = $true
$tweakList.HideSelection = $false
$tweakList.MultiSelect = $false
$tweakList.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$tweakList.ShowItemToolTips = $true
[void]$tweakList.Columns.Add((Get-String "ColTweak"), 430)
[void]$tweakList.Columns.Add((Get-String "ColConfidence"), 132)
[void]$tweakList.Columns.Add((Get-String "ColRisk"), 112)
[void]$tweakList.Columns.Add((Get-String "ColRegistry"), 360)

$rightPanel.Controls.Add($tweakList)
$rightPanel.Controls.Add($lblTweaks)

$mainSplit.Panel1.Controls.Add($leftPanel)
$mainSplit.Panel2.Controls.Add($rightPanel)
$form.Controls.Add($mainSplit)

function Update-ListColumnLayout {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param()

    if ($categoryList -and $categoryList.Columns.Count -ge 2) {
        $w = [Math]::Max(260, $categoryList.ClientSize.Width - 22)
        $risk = 90
        $categoryList.Columns[1].Width = $risk
        $categoryList.Columns[0].Width = [Math]::Max(150, $w - $risk)
    }

    if ($tweakList -and $tweakList.Columns.Count -ge 4) {
        $w = [Math]::Max(520, $tweakList.ClientSize.Width - 22)
        $confidence = 132
        $risk = 112
        $registry = [Math]::Max(210, [int]($w * 0.34))
        $name = [Math]::Max(260, $w - $confidence - $risk - $registry)
        $tweakList.Columns[0].Width = $name
        $tweakList.Columns[1].Width = $confidence
        $tweakList.Columns[2].Width = $risk
        $tweakList.Columns[3].Width = $registry
    }
}

$updateListColumnLayout = { Update-ListColumnLayout }
$leftPanel.Add_Resize({ Update-ListColumnLayout })
$rightPanel.Add_Resize({ Update-ListColumnLayout })
$mainSplit.Add_SplitterMoved({
    $script:SplitterMovedByUser = $true
    Update-ListColumnLayout
})
$form.Add_Shown({
    if (-not $script:SplitterMovedByUser -and $mainSplit.ClientSize.Width -gt 0) {
        $target = [int]($mainSplit.ClientSize.Width * 0.46)
        $mainSplit.SplitterDistance = [Math]::Max(420, [Math]::Min($target, $mainSplit.ClientSize.Width - 520))
    }
    Update-ListColumnLayout
})

# Bottom panel with action buttons.
$panel = New-Object System.Windows.Forms.Panel
$panel.Dock = "Bottom"
$panel.Height = 104
$panel.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($panel)

# Description box shows the selected node's details.
$desc = New-Object System.Windows.Forms.TextBox
$desc.Dock = "Bottom"
$desc.Multiline = $true
$desc.ReadOnly = $true
$desc.Height = 78
$desc.ScrollBars = "Vertical"
$desc.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$desc.BackColor = [System.Drawing.Color]::FromArgb(248, 249, 250)
$form.Controls.Add($desc)

$mainSplit.BringToFront()

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
    $titleEN = if (-not [string]::IsNullOrWhiteSpace($block.Title)) {
        $block.Title
    } elseif ($blockTitles_EN.ContainsKey($block.Key)) {
        $blockTitles_EN[$block.Key]
    } else {
        $block.Key
    }

    $title = Get-LocalizedBlockTitle -Key $block.Key -FallbackTitle $titleEN

    $blockNode = New-Object System.Windows.Forms.TreeNode($title)
    $blockNode.Checked = [bool]$block.Enabled
    $blockNode.Tag = [pscustomobject]@{ Kind = "block"; Key = $block.Key; TitleEN = $titleEN }

    $childList = New-Object System.Collections.ArrayList
    if ($tweaksByBlock.ContainsKey($block.Key)) {
        foreach ($t in $tweaksByBlock[$block.Key]) {
            $label = Get-TweakNodeText -Detail $t
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
    [void]$script:BlockEntries.Add([pscustomobject]@{ Node = $blockNode; Children = $childList; BaseTitle = $title; TitleEN = $titleEN })
}

# Checking/unchecking a block toggles all its child tweaks. Guard against recursion.
# Cascade over the canonical children so a block toggle affects every tweak even when
# the filter is currently hiding some of them.
$script:Suppress = $false
$script:AuditGatePassed = $false

function Set-ApplyGate {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param([bool]$Enabled, [string]$StatusText = $null)
    $script:AuditGatePassed = [bool]$Enabled
    if ($btnApply) { $btnApply.Enabled = [bool]$Enabled }
    if ($status -and -not [string]::IsNullOrWhiteSpace($StatusText)) { $status.Text = $StatusText }
}

function Reset-ApplyGateForSelectionChange {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param()
    Set-ApplyGate -Enabled $false -StatusText (Get-String "StatusAuditRequired")
}

function Get-SelectedBlockEntry {
    if ($categoryList.SelectedItems.Count -gt 0) { return $categoryList.SelectedItems[0].Tag }
    if ($categoryList.Items.Count -gt 0) { return $categoryList.Items[0].Tag }
    return $null
}

function Test-EntryMatchesFilter {
    param($Entry, [string]$Filter)
    if ([string]::IsNullOrWhiteSpace($Filter)) { return $true }
    $needle = [regex]::Escape($Filter)
    if ($Entry.Node.Text -match $needle) { return $true }
    foreach ($c in $Entry.Children) {
        if ($c.Text -match $needle) { return $true }
        if ($c.Tag -and $c.Tag.Kind -eq "tweak" -and (Get-RegistryPreview -Detail $c.Tag.Detail) -match $needle) { return $true }
    }
    return $false
}

function Test-TweakMatchesFilter {
    param($Node, [string]$Filter, [bool]$BlockMatched)
    if ([string]::IsNullOrWhiteSpace($Filter) -or $BlockMatched) { return $true }
    $needle = [regex]::Escape($Filter)
    if ($Node.Text -match $needle) { return $true }
    if ($Node.Tag -and $Node.Tag.Kind -eq "tweak" -and (Get-RegistryPreview -Detail $Node.Tag.Detail) -match $needle) { return $true }
    return $false
}

function Refresh-TweakList {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param($Entry)

    $script:Suppress = $true
    $tweakList.BeginUpdate()
    try {
        $tweakList.Items.Clear()
        if ($null -eq $Entry) { return }
        $filter = $txtFilter.Text.Trim()
        $blockMatched = ([string]::IsNullOrWhiteSpace($filter) -or $Entry.Node.Text -match [regex]::Escape($filter))
        foreach ($child in $Entry.Children) {
            if (-not (Test-TweakMatchesFilter -Node $child -Filter $filter -BlockMatched $blockMatched)) { continue }
            $detail = $child.Tag.Detail
            $item = New-Object System.Windows.Forms.ListViewItem((Get-LocalizedTweakDescription -Detail $detail))
            $item.Checked = [bool]$child.Checked
            $item.Tag = $child.Tag
            $item.ToolTipText = "{0}`r`n{1}: {2}`r`n{3}: {4}`r`n{5}" -f `
                (Get-LocalizedTweakDescription -Detail $detail),
                (Get-String "ColConfidence"), (Get-LocalizedConfidence ([string]$detail.Confidence)),
                (Get-String "ColRisk"), (Get-RiskText -Detail $detail -BlockKey $Entry.Node.Tag.Key),
                (Get-RegistryPreview -Detail $detail)
            $item.BackColor = Get-ConfidenceBackColor ([string]$detail.Confidence)
            [void]$item.SubItems.Add((Get-LocalizedConfidence ([string]$detail.Confidence)))
            [void]$item.SubItems.Add((Get-RiskText -Detail $detail -BlockKey $Entry.Node.Tag.Key))
            [void]$item.SubItems.Add((Get-RegistryPreview -Detail $detail))
            [void]$tweakList.Items.Add($item)
        }
    } finally {
        $tweakList.EndUpdate()
        $script:Suppress = $false
    }
}

function Refresh-CategoryList {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param([string]$PreferredKey = $null)

    $currentKey = $PreferredKey
    if ([string]::IsNullOrWhiteSpace($currentKey) -and $categoryList.SelectedItems.Count -gt 0) {
        $currentKey = $categoryList.SelectedItems[0].Tag.Node.Tag.Key
    }

    $script:Suppress = $true
    $categoryList.BeginUpdate()
    try {
        $categoryList.Items.Clear()
        $filter = $txtFilter.Text.Trim()
        foreach ($entry in $script:BlockEntries) {
            if (-not (Test-EntryMatchesFilter -Entry $entry -Filter $filter)) { continue }
            $bk = $entry.Node.Tag.Key
            $n = if ($script:PerBlockCounts -and $script:PerBlockCounts[$bk]) { [int]$script:PerBlockCounts[$bk] } else { 0 }
            $title = if ($n -gt 0) { $entry.BaseTitle + (Get-String "WouldChangeText" @($n)) } else { $entry.BaseTitle }
            $item = New-Object System.Windows.Forms.ListViewItem($title)
            $item.Checked = [bool]$entry.Node.Checked
            $item.Tag = $entry
            $riskText = Get-BlockRiskText -Entry $entry
            $item.ToolTipText = "{0}`r`n{1}: {2}`r`n{3}: {4}/{5}" -f `
                $title,
                (Get-String "ColRisk"), $riskText,
                (Get-String "TweaksHeader"), (Get-SelectedTweakCount -Entry $entry), $entry.Children.Count
            [void]$item.SubItems.Add($riskText)
            if ($entry.Node.Tag.Key -match "^Remove") {
                $item.BackColor = [System.Drawing.Color]::FromArgb(255, 248, 219)
            }
            [void]$categoryList.Items.Add($item)
            if ($currentKey -eq $bk) { $item.Selected = $true }
        }
        if ($categoryList.SelectedItems.Count -eq 0 -and $categoryList.Items.Count -gt 0) {
            $categoryList.Items[0].Selected = $true
        }
    } finally {
        $categoryList.EndUpdate()
        $script:Suppress = $false
    }

    Refresh-TweakList -Entry (Get-SelectedBlockEntry)
}

# Live filter: narrow category/tweak lists by substring match on block title, tweak label,
# or registry preview. Canonical TreeNode state is reused, so filtering never loses selection.
$applyFilter = {
    Refresh-CategoryList
}
$txtFilter.Add_TextChanged($applyFilter)
$btnFilterClear.Add_Click({ $txtFilter.Text = "" })

$categoryList.Add_ItemChecked({
    param($src, $e)
    if ($script:Suppress) { return }
    $entry = $e.Item.Tag
    if ($null -eq $entry) { return }
    $script:Suppress = $true
    try {
        $entry.Node.Checked = [bool]$e.Item.Checked
        foreach ($child in $entry.Children) { $child.Checked = [bool]$e.Item.Checked }
    } finally {
        $script:Suppress = $false
    }
    Refresh-TweakList -Entry $entry
    Reset-ApplyGateForSelectionChange
})

$categoryList.Add_SelectedIndexChanged({
    $entry = Get-SelectedBlockEntry
    Refresh-TweakList -Entry $entry
    if ($entry) { Update-DescriptionFromTag -Tag $entry.Node.Tag }
})

$tweakList.Add_ItemChecked({
    param($src, $e)
    if ($script:Suppress) { return }
    if ($null -eq $e.Item.Tag -or $e.Item.Tag.Kind -ne "tweak") { return }
    $e.Item.Tag.Detail | Out-Null
    $node = $null
    foreach ($entry in $script:BlockEntries) {
        foreach ($child in $entry.Children) {
            if ($child.Tag.Key -eq $e.Item.Tag.Key) { $node = $child; break }
        }
        if ($node) { break }
    }
    if ($node) { $node.Checked = [bool]$e.Item.Checked }
    Reset-ApplyGateForSelectionChange
})

$tweakList.Add_SelectedIndexChanged({
    if ($tweakList.SelectedItems.Count -gt 0) {
        Update-DescriptionFromTag -Tag $tweakList.SelectedItems[0].Tag
    }
})

Refresh-CategoryList

# ------------------------------------------------------------
# Buttons
# ------------------------------------------------------------
function Get-ActionButton {
    param([string]$Text, [int]$X, [int]$Width = 130)
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Location = New-Object System.Drawing.Point($X, 12)
    $b.Size = New-Object System.Drawing.Size($Width, 32)
    $b.FlatStyle = [System.Windows.Forms.FlatStyle]::System
    return $b
}

$btnSelectAll = Get-ActionButton -Text (Get-String "BtnSelectAll") -X 10 -Width 84
$btnSelectNone = Get-ActionButton -Text (Get-String "BtnSelectNone") -X 98 -Width 84
$btnSave = Get-ActionButton -Text (Get-String "BtnSave") -X 186 -Width 92
$btnLoad = Get-ActionButton -Text (Get-String "BtnLoad") -X 282 -Width 100
$btnAudit = Get-ActionButton -Text (Get-String "BtnAudit") -X 386 -Width 130
$btnApply = Get-ActionButton -Text (Get-String "BtnApply") -X 520 -Width 110
$btnUndo = Get-ActionButton -Text (Get-String "BtnUndo") -X 634 -Width 100
$btnClose = Get-ActionButton -Text (Get-String "BtnClose") -X 738 -Width 80

$panel.Controls.AddRange(@($btnSelectAll, $btnSelectNone, $btnSave, $btnLoad, $btnAudit, $btnApply, $btnUndo, $btnClose))

$btnAudit.Font = $uiFontBold
$btnApply.Enabled = $false

# Status line.
$status = New-Object System.Windows.Forms.Label
$status.Location = New-Object System.Drawing.Point(12, 54)
$status.Size = New-Object System.Drawing.Size(780, 36)
$status.Text = (Get-String "StatusReady")
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
    Refresh-CategoryList
    Reset-ApplyGateForSelectionChange
})
$btnSelectNone.Add_Click({
    $script:Suppress = $true
    foreach ($entry in $script:BlockEntries) {
        $entry.Node.Checked = $false
        foreach ($c in $entry.Children) { $c.Checked = $false }
    }
    $script:Suppress = $false
    Refresh-CategoryList
    Reset-ApplyGateForSelectionChange
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
            $status.Text = (Get-String "StatusSaved" @($dlg.FileName))
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "$(Get-String "ErrorSave" @($_.Exception.Message))",
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
            Refresh-CategoryList
            Reset-ApplyGateForSelectionChange
            $status.Text = (Get-String "StatusLoaded" @($dlg.FileName))
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "$(Get-String "ErrorLoad" @($_.Exception.Message))",
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

function Get-NormalizedResultRows {
    param([object]$Rows)

    if ($null -eq $Rows) { return @() }
    $arr = @($Rows)
    while ($arr.Count -eq 1 -and $arr[0] -is [System.Array]) {
        $arr = @($arr[0])
    }
    return $arr
}

# Summary counters for the results tabs. These are UI groupings; the full fidelity
# results stay in Details and Raw.
function Get-ResultSummaryCounts {
    param([object]$Results)
    $rows = @(Get-NormalizedResultRows -Rows $Results)
    $would = @($rows | Where-Object { $_.Status -eq "WouldChange" -or $_.Status -eq "WouldRemove" }).Count
    $ok = @($rows | Where-Object { $_.Status -eq "Compliant" -or $_.Status -eq "AlreadyConfigured" -or $_.Status -eq "VerifyOK" }).Count
    $changed = @($rows | Where-Object { $_.Status -eq "Changed" }).Count
    $needs = @($rows | Where-Object {
            $_.Status -eq "RequiresVerification" -or $_.Support -eq "RequiresVerification" -or
            $_.Support -eq "MaybeIgnoredOnEdition" -or $_.Confidence -eq "RequiresVerification"
        }).Count
    $unsupported = @($rows | Where-Object {
            ([string]$_.Status).StartsWith("Unsupported") -or ([string]$_.Support).StartsWith("Unsupported")
        }).Count
    $errors = @($rows | Where-Object { $_.Status -eq "Error" -or $_.Status -eq "VerifyFail" }).Count
    return [pscustomobject]@{
        Total = $rows.Count
        WouldChange = $would
        AlreadyOk = $ok
        Changed = $changed
        NeedsVerification = $needs
        Unsupported = $unsupported
        Errors = $errors
    }
}

# Show the engine's results in Summary / Details / Raw tabs. Details defaults to a
# "Needs attention" view.
function Show-ResultsDialog {
    param([object]$Results, [string]$Mode, [string]$RawText = "")

    $Results = @(Get-NormalizedResultRows -Rows $Results)

    # Use the engine's attention-status list (from the catalog) so highlighting never drifts
    # from the HTML report. Falls back to a literal list only if the script-scope copy is unset.
    $attention = if ($script:AttentionStatuses) { $script:AttentionStatuses } else {
        @("WouldChange", "WouldRemove", "Warning", "VerifyFail", "Error",
            "RequiresVerification", "MaybeIgnoredOnEdition", "UnsupportedBuild")
    }
    function Test-AttentionResult {
        param($Row)
        return ($attention -contains $Row.Status -or
            $attention -contains $Row.Support -or
            $attention -contains $Row.Confidence)
    }

    $rf = New-Object System.Windows.Forms.Form
    $rf.Text = (Get-String "GridTitle" @($Mode))
    $rf.Size = New-Object System.Drawing.Size(960, 620)
    $rf.StartPosition = "CenterParent"
    $rf.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
    $rf.Font = $uiFont

    $tabs = New-Object System.Windows.Forms.TabControl
    $tabs.Dock = "Fill"

    $tabSummary = New-Object System.Windows.Forms.TabPage
    $tabSummary.Text = Get-String "TabSummary"
    $tabDetails = New-Object System.Windows.Forms.TabPage
    $tabDetails.Text = Get-String "TabDetails"
    $tabRaw = New-Object System.Windows.Forms.TabPage
    $tabRaw.Text = Get-String "TabRaw"

    $summaryList = New-Object System.Windows.Forms.ListView
    $summaryList.Dock = "Fill"
    $summaryList.View = [System.Windows.Forms.View]::Details
    $summaryList.FullRowSelect = $true
    $summaryList.HeaderStyle = [System.Windows.Forms.ColumnHeaderStyle]::None
    [void]$summaryList.Columns.Add("Metric", 260)
    [void]$summaryList.Columns.Add("Value", 120)
    $summaryCounts = Get-ResultSummaryCounts -Results $Results
    $metrics = @(
        @{ Label = Get-String "SummaryTotal"; Value = $summaryCounts.Total; Color = [System.Drawing.Color]::White },
        @{ Label = Get-String "SummaryWouldChange"; Value = $summaryCounts.WouldChange; Color = [System.Drawing.Color]::FromArgb(255, 248, 219) },
        @{ Label = Get-String "SummaryAlreadyOk"; Value = $summaryCounts.AlreadyOk; Color = [System.Drawing.Color]::FromArgb(232, 246, 239) },
        @{ Label = Get-String "SummaryChanged"; Value = $summaryCounts.Changed; Color = [System.Drawing.Color]::FromArgb(232, 246, 239) },
        @{ Label = Get-String "SummaryNeedsVerification"; Value = $summaryCounts.NeedsVerification; Color = [System.Drawing.Color]::FromArgb(255, 248, 219) },
        @{ Label = Get-String "SummaryUnsupported"; Value = $summaryCounts.Unsupported; Color = [System.Drawing.Color]::FromArgb(255, 236, 224) },
        @{ Label = Get-String "SummaryErrors"; Value = $summaryCounts.Errors; Color = [System.Drawing.Color]::FromArgb(248, 215, 218) }
    )
    foreach ($m in $metrics) {
        $item = New-Object System.Windows.Forms.ListViewItem([string]$m.Label)
        [void]$item.SubItems.Add([string]$m.Value)
        $item.BackColor = $m.Color
        [void]$summaryList.Items.Add($item)
    }
    $tabSummary.Controls.Add($summaryList)

    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Dock = "Fill"
    $grid.ReadOnly = $true
    $grid.AllowUserToAddRows = $false
    $grid.AllowUserToDeleteRows = $false
    $grid.RowHeadersVisible = $false
    $grid.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
    $grid.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
    $columns = @(
        @{ Name = "Category"; Header = Get-String "ColCategory" },
        @{ Name = "Item"; Header = Get-String "ColItem" },
        @{ Name = "Status"; Header = Get-String "ColStatus" },
        @{ Name = "Current"; Header = Get-String "ColCurrent" },
        @{ Name = "Desired"; Header = Get-String "ColDesired" },
        @{ Name = "Message"; Header = Get-String "ColMessage" }
    )
    foreach ($c in $columns) {
        [void]$grid.Columns.Add($c.Name, $c.Header)
    }
    $grid.Columns["Item"].FillWeight = 200
    $grid.Columns["Message"].FillWeight = 260

    $top = New-Object System.Windows.Forms.Panel
    $top.Dock = "Top"
    $top.Height = 34
    $chkAll = New-Object System.Windows.Forms.CheckBox
    $chkAll.Text = (Get-String "GridShowAll")
    $chkAll.Location = New-Object System.Drawing.Point(10, 8)
    $chkAll.AutoSize = $true
    $summary = New-Object System.Windows.Forms.Label
    $summary.Location = New-Object System.Drawing.Point(260, 10)
    $summary.AutoSize = $true
    $counts = $Results | Group-Object Status | Sort-Object Name
    $summary.Text = (Get-String "GridTotal" @($Results.Count, (($counts | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join "   ")))

    # D3: export the currently shown rows (respecting the "Show all" toggle) to CSV.
    $btnExport = New-Object System.Windows.Forms.Button
    $btnExport.Text = (Get-String "GridExport")
    $btnExport.Size = New-Object System.Drawing.Size(110, 24)
    $btnExport.Location = New-Object System.Drawing.Point(($rf.ClientSize.Width - 122), 5)
    $btnExport.Anchor = "Top, Right"
    $btnExport.Add_Click({
        $dlg = New-Object System.Windows.Forms.SaveFileDialog
        $dlg.Filter = "CSV (*.csv)|*.csv|All files (*.*)|*.*"
        $dlg.FileName = "Win11-CalmMode-$Mode-results.csv"
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            try {
                $rows = if ($chkAll.Checked) { $Results } else { $Results | Where-Object { Test-AttentionResult $_ } }
                $csv = $rows | ForEach-Object { ConvertTo-DisplayResult -Row $_ } |
                    Select-Object Category, Item, Status, CurrentValue, DesiredValue, Confidence, Support, Message |
                    ConvertTo-Csv -NoTypeInformation
                $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
                [System.IO.File]::WriteAllLines($dlg.FileName, $csv, $utf8NoBom)
            } catch {
                [System.Windows.Forms.MessageBox]::Show(
                    "$(Get-String "ErrorExport" @($_.Exception.Message))",
                    "Win11 25H2 Calm Mode", "OK", "Error") | Out-Null
            }
        }
    })
    $top.Controls.AddRange(@($chkAll, $summary, $btnExport))

    $populate = {
        $grid.Rows.Clear()
        foreach ($r in $Results) {
            if (-not $chkAll.Checked -and -not (Test-AttentionResult $r)) { continue }
            $display = ConvertTo-DisplayResult -Row $r
            $i = $grid.Rows.Add($display.Category, $display.Item, $display.Status, $display.CurrentValue, $display.DesiredValue, $display.Message)
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
            $rf.Text = if ($chkAll.Checked) { Get-String "GridTitleEmpty" @($Mode) } else { Get-String "GridTitleNoAttention" @($Mode) }
        }
    }
    $chkAll.Add_CheckedChanged($populate)
    & $populate

    $detailsPanel = New-Object System.Windows.Forms.Panel
    $detailsPanel.Dock = "Fill"
    $detailsPanel.Controls.Add($grid)
    $detailsPanel.Controls.Add($top)
    $grid.BringToFront()
    $tabDetails.Controls.Add($detailsPanel)

    $rawBox = New-Object System.Windows.Forms.TextBox
    $rawBox.Dock = "Fill"
    $rawBox.Multiline = $true
    $rawBox.ReadOnly = $true
    $rawBox.ScrollBars = "Both"
    $rawBox.WordWrap = $false
    $rawBox.Font = New-Object System.Drawing.Font("Consolas", 9)
    if ([string]::IsNullOrWhiteSpace($RawText)) {
        try { $RawText = ($Results | ConvertTo-Json -Depth 8) } catch { $RawText = "" }
    }
    $rawBox.Text = $RawText
    $tabRaw.Controls.Add($rawBox)

    [void]$tabs.TabPages.Add($tabSummary)
    [void]$tabs.TabPages.Add($tabDetails)
    [void]$tabs.TabPages.Add($tabRaw)
    $rf.Controls.Add($tabs)
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
        $script:PerBlockCounts = $perBlock; $entry.Node.Text = if ($n -gt 0) { $entry.BaseTitle + (Get-String "WouldChangeText" @($n)) } else { $entry.BaseTitle }
    }
    Refresh-CategoryList
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
            $status.Text = (Get-String "StatusApplyLaunch")
            $status.Refresh()
            $proc = Start-Process -FilePath $script:PowerShellExe -ArgumentList $argList -Verb RunAs -Wait -PassThru
        } else {
            $status.Text = (Get-String "StatusAuditLaunch")
            $status.Refresh()
            $proc = Start-Process -FilePath $script:PowerShellExe -ArgumentList $argList -WindowStyle Hidden -Wait -PassThru
        }

        $jsonPath = Find-LatestResultsJson -Base $reportBase -Mode $Mode
        if ($jsonPath) {
            $rawText = Get-Content -LiteralPath $jsonPath -Raw -ErrorAction Stop
            $results = @(Get-NormalizedResultRows -Rows ($rawText | ConvertFrom-Json))
            $status.Text = (Get-String "StatusComplete" @($Mode, $results.Count, $proc.ExitCode))
            if ($Mode -eq "Audit") {
                Update-BlockCounts -Results $results
                $summaryCounts = Get-ResultSummaryCounts -Results $results
                if ($proc.ExitCode -eq 0 -and $summaryCounts.Errors -eq 0) {
                    Set-ApplyGate -Enabled $true -StatusText (Get-String "StatusAuditPassedApplyEnabled")
                } else {
                    Set-ApplyGate -Enabled $false -StatusText (Get-String "StatusAuditErrorsApplyDisabled")
                }
            }
            Show-ResultsDialog -Results $results -Mode $Mode -RawText $rawText
        } else {
            if ($Mode -eq "Audit") { Set-ApplyGate -Enabled $false }
            $status.Text = (Get-String "StatusNoResults" @($Mode, $proc.ExitCode))
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "$(Get-String "ErrorEngineRun" @($_.Exception.Message))",
            "Win11 25H2 Calm Mode", "OK", "Error") | Out-Null
        if ($Mode -eq "Audit") { Set-ApplyGate -Enabled $false }
        $status.Text = (Get-String "StatusReady")
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
    if (-not $script:AuditGatePassed) {
        [System.Windows.Forms.MessageBox]::Show(
            (Get-String "ApplyBlockedRunAudit"),
            "Win11 25H2 Calm Mode", "OK", "Information") | Out-Null
        return
    }

    # D4: compute the impact preview (quick hidden Audit) before asking to proceed.
    $form.Enabled = $false
    $status.Text = (Get-String "StatusImpactCalc")
    $status.Refresh()
    $preview = Get-AuditPreviewCount
    $form.Enabled = $true
    $status.Text = (Get-String "StatusReady")

    $previewLine = if ($null -ne $preview) {
        (Get-String "PreviewLineOk" @($preview))
    } else {
        (Get-String "PreviewLineFail")
    }

    $answer = [System.Windows.Forms.MessageBox]::Show(
        (Get-String "DialogApplyWarning" @($previewLine)),
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
            (Get-String "UndoNotFoundAsk"),
            "Win11 25H2 Calm Mode", "YesNo", "Information")
        if ($ask -ne "Yes") { return }
        $fb = New-Object System.Windows.Forms.FolderBrowserDialog
        $fb.Description = (Get-String "UndoBrowseDesc")
        if ($fb.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
        $target = $fb.SelectedPath
        $targetLabel = $fb.SelectedPath
    }

    $answer = [System.Windows.Forms.MessageBox]::Show(
        (Get-String "UndoWarning" @($targetLabel)),
        "Confirm Undo last Apply", "YesNo", "Warning")
    if ($answer -ne "Yes") { return }

    $argList = @(
        "-NoProfile", "-ExecutionPolicy", "Bypass",
        "-File", "`"$EnginePath`"",
        "-RestoreFrom", "`"$target`""
    )
    try {
        $status.Text = (Get-String "StatusUndoLaunch")
        Start-Process -FilePath $script:PowerShellExe -ArgumentList $argList -Verb RunAs | Out-Null
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "$(Get-String "ErrorUndoRun" @($_.Exception.Message))",
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
    if ($categoryList.Items.Count -ne $script:BlockEntries.Count) {
        [void]$fail.Add("category list count $($categoryList.Items.Count) != entry count $($script:BlockEntries.Count)")
    }
    if ($categoryList.Items.Count -gt 0 -and $tweakList.Items.Count -eq 0) {
        [void]$fail.Add("visible tweak list is empty for the selected category")
    }
    if ($btnApply.Enabled) {
        [void]$fail.Add("Apply should be disabled before Audit")
    }

    $fakeRows = @(
        [pscustomobject]@{ Status = "WouldChange"; Support = ""; Confidence = "Official" },
        [pscustomobject]@{ Status = "Compliant"; Support = ""; Confidence = "Official" },
        [pscustomobject]@{ Status = "Changed"; Support = ""; Confidence = "Official" },
        [pscustomobject]@{ Status = "Warning"; Support = "MaybeIgnoredOnEdition"; Confidence = "RequiresVerification" },
        [pscustomobject]@{ Status = "UnsupportedBuild"; Support = ""; Confidence = "Official" },
        [pscustomobject]@{ Status = "Error"; Support = ""; Confidence = "Official" }
    )
    $fakeSummary = Get-ResultSummaryCounts -Results $fakeRows
    if ($fakeSummary.WouldChange -ne 1 -or $fakeSummary.AlreadyOk -ne 1 -or
        $fakeSummary.Changed -ne 1 -or $fakeSummary.NeedsVerification -ne 1 -or
        $fakeSummary.Unsupported -ne 1 -or $fakeSummary.Errors -ne 1) {
        [void]$fail.Add("result summary counters failed")
    }
    $nestedSummary = Get-ResultSummaryCounts -Results (, $fakeRows)
    if ($nestedSummary.Total -ne 6 -or $nestedSummary.WouldChange -ne 1 -or $nestedSummary.AlreadyOk -ne 1) {
        [void]$fail.Add("nested result array normalization failed")
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
        if ($categoryList.Items.Count -ne 0) {
            [void]$fail.Add("filter did not hide non-matching blocks (visible=$($categoryList.Items.Count))")
        }
        if ((Get-SelectionConfig).blocks.Count -ne $script:BlockEntries.Count) {
            [void]$fail.Add("filter changed the canonical selection count")
        }
        $txtFilter.Text = ""
        & $applyFilter
        if ($categoryList.Items.Count -ne $script:BlockEntries.Count) {
            [void]$fail.Add("clearing the filter did not restore all blocks")
        }

        # Localization check: every exported tweak must have a Ukrainian display string.
        $script:Lang = "UA"
        Update-UILanguage
        $missingUa = New-Object System.Collections.ArrayList
        foreach ($t in $catalog.Tweaks) {
            $localized = Get-LocalizedTweakDescription -Detail $t
            if ($localized -eq $t.Description) {
                [void]$missingUa.Add($t.Description)
            }
        }
        if ($missingUa.Count -gt 0) {
            [void]$fail.Add("missing UA tweak translation(s): " + (($missingUa | Select-Object -First 5) -join "; "))
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
