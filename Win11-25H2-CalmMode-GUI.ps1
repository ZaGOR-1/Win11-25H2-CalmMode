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
        "Header" = "Detected: Build {0}.{1}, edition group {2}. Check the blocks and tweaks you want, then run Audit first (read-only)."
        "FilterLabel" = "Filter:"
        "FilterClear" = "Clear"
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
        "Header" = "Виявлено: Build {0}.{1}, редакція {2}. Позначте потрібні блоки/твіки та запустіть Audit (без змін)."
        "FilterLabel" = "Фільтр:"
        "FilterClear" = "Очистити"
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

    # Refresh tree blocks if needed
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

    # Update current selected description
    if ($tree -and $tree.SelectedNode) {
        # Trigger re-selection logic to update description
        $tmp = $tree.SelectedNode
        $tree.SelectedNode = $null
        $tree.SelectedNode = $tmp
    }
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
$header.Text = (Get-String "Header" @($catalog.Build, $catalog.UBR, $catalog.EditionGroup))

$lblFilter = New-Object System.Windows.Forms.Label
$lblFilter.Text = (Get-String "FilterLabel")
$lblFilter.Location = New-Object System.Drawing.Point(10, 53)
$lblFilter.AutoSize = $true

$txtFilter = New-Object System.Windows.Forms.TextBox
$txtFilter.Location = New-Object System.Drawing.Point(60, 50)
$txtFilter.Size = New-Object System.Drawing.Size(360, 24)
$txtFilter.Anchor = "Top, Left"

$btnFilterClear = New-Object System.Windows.Forms.Button
$btnFilterClear.Text = (Get-String "FilterClear")
$btnFilterClear.Size = New-Object System.Drawing.Size(60, 24)
$btnFilterClear.Location = New-Object System.Drawing.Point(428, 49)
$btnFilterClear.Anchor = "Top, Left"

$topBar.Controls.AddRange(@($header, $lblFilter, $txtFilter, $btnFilterClear))

$btnLanguage = New-Object System.Windows.Forms.Button
$btnLanguage.Text = Get-String "LangToggle"
$btnLanguage.Size = New-Object System.Drawing.Size(65, 24)
$btnLanguage.Location = New-Object System.Drawing.Point(500, 49)
$btnLanguage.Anchor = "Top, Left"
$btnLanguage.Add_Click({
    $script:Lang = if ($script:Lang -eq "EN") { "UA" } else { "EN" }
    Update-UILanguage
})
$topBar.Controls.Add($btnLanguage)

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
        $ed = if ($d.Editions -and $d.Editions.Count -gt 0) { ($d.Editions -join ", ") } else { (Get-String "EditionsAll") }
        $desc.Text = (Get-String "NodeTweakDesc" @(
            (Get-LocalizedTweakDescription -Detail $d),
            $d.Path,
            $d.Name,
            $d.Value,
            $d.Type,
            (Get-LocalizedConfidence $d.Confidence),
            "$($d.MinBuild)$(if ($d.MinUBR -gt 0) { ".$($d.MinUBR)" })",
            $ed
        ))
    } else {
        $desc.Text = (Get-String "NodeBlockDesc" @($tag.Key))
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

$btnSelectAll = Get-ActionButton -Text (Get-String "BtnSelectAll") -X 10 -Width 84
$btnSelectNone = Get-ActionButton -Text (Get-String "BtnSelectNone") -X 98 -Width 84
$btnSave = Get-ActionButton -Text (Get-String "BtnSave") -X 186 -Width 92
$btnLoad = Get-ActionButton -Text (Get-String "BtnLoad") -X 282 -Width 100
$btnAudit = Get-ActionButton -Text (Get-String "BtnAudit") -X 386 -Width 130
$btnApply = Get-ActionButton -Text (Get-String "BtnApply") -X 520 -Width 110
$btnUndo = Get-ActionButton -Text (Get-String "BtnUndo") -X 634 -Width 100
$btnClose = Get-ActionButton -Text (Get-String "BtnClose") -X 738 -Width 80

$panel.Controls.AddRange(@($btnSelectAll, $btnSelectNone, $btnSave, $btnLoad, $btnAudit, $btnApply, $btnUndo, $btnClose))

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

# Show the engine's results in a grid. Defaults to a "Needs attention" view.
function Show-ResultsDialog {
    param([object[]]$Results, [string]$Mode)

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
        $script:PerBlockCounts = $perBlock; $entry.Node.Text = if ($n -gt 0) { $entry.BaseTitle + (Get-String "WouldChangeText" @($n)) } else { $entry.BaseTitle }
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
            $results = @(Get-Content -LiteralPath $jsonPath -Raw -ErrorAction Stop | ConvertFrom-Json)
            $status.Text = (Get-String "StatusComplete" @($Mode, $results.Count, $proc.ExitCode))
            if ($Mode -eq "Audit") { Update-BlockCounts -Results $results }
            Show-ResultsDialog -Results $results -Mode $Mode
        } else {
            $status.Text = (Get-String "StatusNoResults" @($Mode, $proc.ExitCode))
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "$(Get-String "ErrorEngineRun" @($_.Exception.Message))",
            "Win11 25H2 Calm Mode", "OK", "Error") | Out-Null
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
