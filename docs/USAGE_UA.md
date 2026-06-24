# Використання

[← README](../README.md) · [English](USAGE_EN.md)

## Вимоги

- Windows 11 25H2 або близька збірка Windows 11.
- Windows PowerShell 5.1 Desktop.
- Для `Apply` потрібен запуск від імені адміністратора.
- Перед застосуванням на основній системі бажано зробити `Audit` і протестувати у VM.

Перевірити Windows:

```powershell
winver
```

Перевірити PowerShell:

```powershell
$PSVersionTable.PSVersion
```

## Режими

| Режим | Що робить | Чи змінює систему |
|---|---|---|
| `Audit` | Читає стан і показує, що було б змінено | Ні |
| `Apply` | Застосовує відсутні або неправильні значення | Так |
| `Verify` | Перевіряє, чи бажані значення присутні | Ні |

За замовчуванням використовується `Audit`.

## Приклади

```powershell
# Безпечний аудит
.\Win11-25H2-CalmMode.ps1 -Mode Audit

# Застосувати налаштування
.\Win11-25H2-CalmMode.ps1 -Mode Apply

# Перевірити після перезавантаження
.\Win11-25H2-CalmMode.ps1 -Mode Verify
```

```powershell
# Звіти в окрему теку
.\Win11-25H2-CalmMode.ps1 -Mode Audit -ReportPath C:\Temp\CalmMode

# Без створення файлів звіту, тільки консоль
.\Win11-25H2-CalmMode.ps1 -Mode Audit -NoReport

# Apply і одразу Verify у тому ж звіті
.\Win11-25H2-CalmMode.ps1 -Mode Apply -ThenVerify
```

## Параметри

| Параметр | Default | Опис |
|---|---:|---|
| `-Mode` | `Audit` | `Audit`, `Apply` або `Verify` |
| `-TargetReleaseVersionInfo` | `25H2` | Версія для Target Release Version pinning; діє лише коли `$EnableTargetReleaseVersionPin = $true` |
| `-FeatureUpdateDeferralDays` | `90` | На скільки днів відкладати feature updates |
| `-QualityUpdateDeferralDays` | `7` | На скільки днів відкладати quality updates |
| `-ActiveHoursStart` | `10` | Початок active hours |
| `-ActiveHoursEnd` | `2` | Кінець active hours |
| `-SearchMode` | `Icon` | Вигляд пошуку на панелі задач: `Hidden`, `Icon`, `Box` |
| `-TelemetryLevel` | `1` | Рівень diagnostic data для `AllowTelemetry`; `0` реально поважається лише Enterprise/Education/IoT |
| `-SetTaskbarLeft` | `$true` | Вирівняти taskbar ліворуч |
| `-ReportPath` | Desktop | Базова тека для звітів |
| `-NoReport` | off | Не створювати HTML/CSV/JSON/log у read-only режимах |
| `-OpenReport` | off | Відкрити HTML-звіт після завершення |
| `-ConfigPath` | none | JSON-конфіг вибору блоків/твікiв |
| `-ExportCatalog` | off | Read-only JSON-каталог для GUI/інструментів |
| `-Skip` | none | Вимкнути перелічені блоки, наприклад `-Skip Widgets,Gaming` |
| `-Only` | none | Увімкнути лише перелічені блоки, наприклад `-Only WindowsAI` |
| `-ThenVerify` | off | Після `Apply` одразу виконати `Verify` |
| `-RestoreFrom` | none | Імпортувати `rollback.reg` із теки звіту або прямий `.reg` файл |
| `-EnableSystemProtection` | off | Opt-in: увімкнути System Protection перед restore point |
| `-SkipRestorePoint` | off | Не створювати restore point у `Apply` |
| `-NoAppCleanup` | off | Пропустити Appx cleanup |
| `-NoRestartExplorer` | off | Не перезапускати Explorer після `Apply` |

## GUI

Запуск:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Win11-25H2-CalmMode-GUI.ps1
```

Або подвійний клік:

```text
Win11-25H2-CalmMode-GUI.cmd
```

GUI:

- читає каталог із рушія через `-ExportCatalog`;
- показує блоки й окремі твіки як дерево з галочками;
- має перемикач **EN / UA** для кнопок, блоків, твікiв, описів і таблиці результатів;
- дозволяє зберегти/завантажити вибір як JSON-конфіг;
- запускає `Audit` без змін;
- запускає `Apply` через UAC;
- може виконати **Undo last Apply** через `rollback.reg`.

GUI не містить власної логіки політик. Єдине джерело істини - `Win11-25H2-CalmMode.ps1`.

## Module Toggles

На початку `.ps1` є змінні для цілих блоків. Основні:

| Toggle | Default | Що вмикає |
|---|---:|---|
| `$EnableWindowsAIBlock` | `$true` | Windows AI / Recall / Copilot |
| `$EnableWidgetsBlock` | `$true` | Widgets / News and Interests |
| `$EnableCloudContentBlock` | `$true` | Cloud Content / ads / recommendations |
| `$EnablePrivacyBlock` | `$true` | Advertising ID / diagnostics / feedback |
| `$EnableSearchBlock` | `$true` | Windows Search quiet mode |
| `$EnableStartTaskbarBlock` | `$true` | Start / Taskbar / Explorer |
| `$EnableWindowsUpdateBlock` | `$true` | Windows Update deferral / active hours |
| `$EnableManualWindowsUpdateMode` | `$false` | Opt-in ручний режим оновлень (`AUOptions=2`) |
| `$EnableTargetReleaseVersionPin` | `$false` | Opt-in pin feature version |
| `$EnableDeveloperMode` | `$false` | Opt-in Developer Mode / sideloading |
| `$RemoveCopilotApp` | `$false` | Opt-in Appx cleanup: Copilot |
| `$RemoveTeamsPersonal` | `$false` | Opt-in Appx cleanup: Teams personal |
| `$RemoveXboxApps` | `$false` | Opt-in Appx cleanup: Xbox |
| `$RemoveOneDrive` | `$false` | Opt-in OneDrive uninstall |
