# Win11 25H2 Calm Mode v2.3

PowerShell-скрипт для акуратного налаштування Windows 11 25H2 у більш “спокійний” режим: менше Copilot/AI-функцій, Widgets, реклами, нав’язливих рекомендацій, фонових процесів Edge, автоматичних драйверів через Windows Update і зайвих UI-підказок.

Скрипт **не є агресивним debloater-ом**. Він не вимикає Microsoft Defender, Firewall, Windows Update service, Microsoft Store, WebView2, .NET, сертифікати або критичні системні служби.

> Основна ідея: не ламати Windows, а виставити локальні policy/registry-параметри, які роблять систему тихішою і більш контрольованою.

---

## Що вміє скрипт

- Працює у трьох режимах: `Audit`, `Apply`, `Verify`.
- Має простий **графічний інтерфейс** (`Win11-25H2-CalmMode-GUI.ps1`) з галочками по блоках і окремих твіках.
- Перед змінами робить backup важливих гілок реєстру.
- У `Apply`-режимі створює restore point, якщо System Protection увімкнений.
- Перевіряє, чи значення вже налаштоване, і не перезаписує зайве.
- Наприкінці прогону друкує **підсумок** (лічильники по статусах; в Audit — скільки зміниться на Apply).
- Попереджає, якщо в системі вже **заплановане перезавантаження** (частина політик діє лише після reboot).
- Створює звіти у `HTML`, `CSV`, `JSON`; HTML має секцію **«Needs attention»** угорі.
- Позначає політики, які можуть бути build-dependent, deprecated, UI-only або edition-limited.
- Не приховує сумнівні місця: якщо Windows може ігнорувати політику на певній редакції, у звіті буде відповідний статус.

---

## Вимоги

- Windows 11 25H2 або близька збірка Windows 11.
- Windows PowerShell 5.1.
- Для `Apply`-режиму потрібен запуск **від імені адміністратора**.
- Найкраще тестувати спочатку у VM або на тестовій інсталяції.

Перевірити версію Windows:

```powershell
winver
```

Перевірити PowerShell:

```powershell
$PSVersionTable.PSVersion
```

---

## Швидкий старт

### 1. Audit: подивитися, що буде змінено

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
cd "$env:USERPROFILE\Desktop"
.\Win11-25H2-CalmMode.ps1 -Mode Audit
```

`Audit` нічого не змінює. Він тільки читає поточні значення і створює звіт.

### 2. Apply: застосувати налаштування

```powershell
.\Win11-25H2-CalmMode.ps1 -Mode Apply
```

Після завершення бажано перезавантажити комп’ютер.

### 3. Verify: перевірити після перезавантаження

```powershell
.\Win11-25H2-CalmMode.ps1 -Mode Verify
```

---

## Режими роботи

| Режим | Що робить | Чи змінює систему |
|---|---|---|
| `Audit` | Читає поточний стан і показує, що було б змінено | Ні |
| `Apply` | Застосовує відсутні або неправильні значення | Так |
| `Verify` | Перевіряє, чи бажані значення реально присутні | Ні |

За замовчуванням використовується `Audit`, тому випадковий запуск без параметрів не змінює систему.

```powershell
.\Win11-25H2-CalmMode.ps1
```

це те саме, що:

```powershell
.\Win11-25H2-CalmMode.ps1 -Mode Audit
```

---

## Параметри запуску

| Параметр | Значення за замовчуванням | Опис |
|---|---:|---|
| `-Mode` | `Audit` | `Audit`, `Apply` або `Verify` |
| `-TargetReleaseVersionInfo` | `25H2` | Версія Windows для закріплення через Target Release Version. **Діє лише** коли увімкнено `$EnableTargetReleaseVersionPin = $true` (за замовчуванням off) |
| `-FeatureUpdateDeferralDays` | `90` | На скільки днів відкладати feature updates |
| `-QualityUpdateDeferralDays` | `7` | На скільки днів відкладати quality updates |
| `-ActiveHoursStart` | `10` | Початок active hours |
| `-ActiveHoursEnd` | `2` | Кінець active hours |
| `-SearchMode` | `Icon` | Вигляд пошуку на панелі задач: `Hidden`, `Icon`, `Box` |
| `-TelemetryLevel` | `1` | Рівень diagnostic data для політики `AllowTelemetry`: `0` = Security/Off (поважається лише на Enterprise/Education/IoT, на Home/Pro ігнорується), `1` = Required (мінімум, який реально діє на Home/Pro), `2` = Enhanced, `3` = Full. За замовчуванням `1`, тобто скрипт **не вимикає** діагностику повністю на Home/Pro |
| `-SetTaskbarLeft` | `$true` | Вирівняти taskbar ліворуч |
| `-ReportPath` | Робочий стіл | Базова тека, де створюється тека звіту з міткою часу. Якщо порожньо — Робочий стіл (із fallback на `%TEMP%`) |
| `-NoReport` | off | Не створювати теку звіту, transcript і файли CSV/HTML/JSON (вивід лише в консоль). Діє тільки в read-only режимах `Audit`/`Verify`; у `Apply` ігнорується з попередженням, бо backup і `rollback.reg` потребують теки |
| `-ConfigPath` | (немає) | Шлях до JSON-конфігу, що вмикає/вимикає блоки і вимикає окремі твіки без редагування `.ps1`. Зазвичай формується графічним інтерфейсом. Схема: `{ "blocks": { "<BlockKey>": true\|false }, "disabledTweaks": ["<Path>\<Name>"] }` |
| `-ExportCatalog` | off | Read-only: друкує JSON-каталог усіх блоків і твіків і виходить. Нічого не змінює, не створює теку. Використовується графічним інтерфейсом |
| `-Skip` | (немає) | Швидка альтернатива `-ConfigPath`: список ключів блоків, які **вимкнути** (напр. `-Skip Widgets,Gaming`). Ключі — як у каталозі/конфігу. Не поєднується з `-Only` |
| `-Only` | (немає) | Залишити увімкненими **лише** перелічені блоки, решту вимкнути (напр. `-Only WindowsAI`). Не поєднується з `-Skip` |
| `-ThenVerify` | off | Після `Apply` одразу прогнати `Verify` і дописати його результати в той самий звіт (підтверджує, що значення записались). Діє лише в `Apply` |
| `-SkipRestorePoint` | off | Не створювати restore point у `Apply` |
| `-NoAppCleanup` | off | Пропустити видалення Appx-пакетів |
| `-NoRestartExplorer` | off | Не перезапускати Explorer після `Apply` |

Приклади:

```powershell
.\Win11-25H2-CalmMode.ps1 -Mode Audit -SearchMode Hidden
```

```powershell
.\Win11-25H2-CalmMode.ps1 -Mode Apply -FeatureUpdateDeferralDays 120 -QualityUpdateDeferralDays 7
```

```powershell
.\Win11-25H2-CalmMode.ps1 -Mode Apply -NoAppCleanup
```

```powershell
# Звіти в окрему теку замість Робочого столу
.\Win11-25H2-CalmMode.ps1 -Mode Audit -ReportPath C:\Temp\CalmMode
```

```powershell
# Швидкий аудит без створення тек/файлів звіту (вивід лише в консоль)
.\Win11-25H2-CalmMode.ps1 -Mode Audit -NoReport
```

```powershell
# Швидкий вибір блоків без конфіг-файлу
.\Win11-25H2-CalmMode.ps1 -Mode Audit -Skip Widgets,Gaming     # усе, крім Widgets і Gaming
.\Win11-25H2-CalmMode.ps1 -Mode Audit -Only WindowsAI          # лише блок Windows AI
```

```powershell
# Apply і одразу Verify у тому ж звіті
.\Win11-25H2-CalmMode.ps1 -Mode Apply -ThenVerify
```

---

## Графічний інтерфейс (галочки)

Якщо не хочеться правити `.ps1` чи передавати параметри вручну, є простий GUI.

**Найпростіше — подвійний клік на `Win11-25H2-CalmMode-GUI.cmd`** (лежить поруч зі скриптами). Це звичайний текстовий лаунчер — він лише відкриває вікно GUI, нічого не змінюючи; жодного компільованого `.exe` чи прихованого коду.

Або вручну:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Win11-25H2-CalmMode-GUI.ps1
```

Що він робить:

- показує дерево з галочками: **блоки** (Windows AI, Widgets, Cloud Content, …), кожен **розкривається** в окремі твіки;
- зняття галочки з блоку пропускає весь блок; зняття галочки з окремого твіка пропускає лише його;
- кнопка **Run Audit (safe)** — read-only прогін: нічого не змінює; результат показується **прямо у вікні** (таблиця «Needs attention» з фільтром *Show all*), без окремої консолі;
- кнопка **Apply…** — запитує підтвердження і запускає застосування **від адміністратора** (UAC); перед змінами рушій робить backup і restore point; результат так само показується у вікні, а звіт і `rollback.reg` зберігаються на Робочому столі;
- кнопки **Save config… / Load config…** — зберегти поточний вибір у JSON-файл і завантажити його пізніше (той самий формат, що й `-ConfigPath`);
- кнопка **Close** — вийти.

Важливо: GUI **не містить власної логіки політик**. Він читає каталог рушія (`-ExportCatalog`), а вибір передає назад через тимчасовий `-ConfigPath`-конфіг. Тобто єдиним джерелом істини лишається `Win11-25H2-CalmMode.ps1`. Залежностей немає — Windows Forms входить у Windows PowerShell 5.1.

> Порада: спершу **Run Audit**, перегляньте звіт, і лише потім **Apply**. Як і для CLI, безпечніше тестувати у VM.

---

## Перемикачі всередині скрипта (module toggles)

Крім параметрів командного рядка, на початку `.ps1` є набір булевих перемикачів, якими можна вмикати/вимикати цілі блоки. Щоб змінити поведінку, відредагуй відповідний рядок у скрипті перед запуском.

| Перемикач | Default | Що вмикає |
|---|---:|---|
| `$EnableWindowsAIBlock` | `$true` | Windows AI / Recall / Click to Do / Paint AI |
| `$EnableWidgetsBlock` | `$true` | Widgets / News and Interests |
| `$EnableCloudContentBlock` | `$true` | Cloud Content / Spotlight / suggestions |
| `$EnablePrivacyBlock` | `$true` | Advertising ID / diagnostics / feedback |
| `$EnableSearchBlock` | `$true` | Windows Search quiet mode |
| `$EnableStartTaskbarBlock` | `$true` | Start / Taskbar / Explorer UI |
| `$EnableWindowsUpdateBlock` | `$true` | Windows Update deferral та active hours |
| `$EnableManualWindowsUpdateMode` | `$false` | **Opt-in.** Вмикає `AUOptions=2` (ручне сповіщення перед завантаженням та встановленням) |
| `$EnableTargetReleaseVersionPin` | `$false` | **Opt-in.** Закріплення feature-версії (Target Release Version). Див. попередження нижче |
| `$EnableDeliveryOptimization` | `$true` | Вимкнення peer-to-peer Delivery Optimization |
| `$EnableEdgeQuietMode` | `$true` | Edge Quiet Mode |
| `$EnableDeveloperMode` | `$false` | **Opt-in.** Developer Mode / sideloading. Див. попередження нижче |
| `$EnableLongPaths` | `$true` | Win32 long paths |
| `$DisableFastStartup` | `$true` | Вимкнення Fast Startup (не hibernation) |
| `$EnableGamingTweaks` | `$true` | Game DVR / Game Bar / Game Mode |
| `$RemoveCopilotApp` | `$false` | **Opt-in.** Appx cleanup: Copilot |
| `$RemoveTeamsPersonal` | `$false` | **Opt-in.** Appx cleanup: Teams personal |
| `$RemoveXboxApps` | `$false` | Appx cleanup: Xbox |
| `$RemoveOneDrive` | `$false` | Видалення OneDrive |

> **Target Release Version pinning тепер opt-in.** За замовчуванням `$EnableTargetReleaseVersionPin = $false`, тому скрипт **не** закріплює feature-версію. Закріплення (`TargetReleaseVersion`, `ProductVersion`, `TargetReleaseVersionInfo`) має сенс лише якщо ти свідомо хочеш залишитися на конкретному релізі. Ризик: коли цей реліз досягне кінця сервісингу, система перестане отримувати feature- і security-оновлення, поки пінінг не зняти. `-TargetReleaseVersionInfo` впливає на закріплення тільки коли перемикач увімкнений.

> **Developer Mode та sideloading тепер opt-in.** За замовчуванням `$EnableDeveloperMode = $false`. Вмикання sideloading та Developer Mode дозволяє встановлювати непідписані застосунки, що розширює поверхню атаки (security trade-off). Вмикайте лише якщо це дійсно необхідно для розробки.

---

## Звіти

Після кожного запуску створюється папка на робочому столі:

```text
Win11-25H2-CalmMode-v<version>-<Mode>-YYYY-MM-DD_HH-MM-SS
```

У ній будуть:

```text
Win11-25H2-CalmMode-v<version>-report.html
Win11-25H2-CalmMode-v<version>-results.csv
Win11-25H2-CalmMode-v<version>-results.json
Win11-25H2-CalmMode-v<version>.log
```

У `Apply`-режимі також зберігаються `.reg` backup-файли для важливих гілок реєстру.

---

## Значення статусів у звіті

| Статус | Значення |
|---|---|
| `Compliant` | Значення вже було правильним у `Audit` |
| `WouldChange` | У `Audit` скрипт показує, що це значення було б змінено |
| `WouldRemove` | У `Audit` показує, що пакет був би видалений |
| `AlreadyConfigured` | У `Apply` значення вже правильне, запис не виконувався |
| `Changed` | У `Apply` значення було записане і прочитане назад успішно |
| `VerifyOK` | У `Verify` бажане значення присутнє |
| `VerifyFail` | У `Verify` бажане значення відсутнє або інше |
| `Skipped` | Пункт пропущено через параметри або конфігурацію |
| `Warning` | Некритичне попередження |
| `Error` | Помилка запису або перевірки |
| `UnsupportedBuild` | Політика не підходить для поточної збірки |
| `MaybeIgnoredOnEdition` | Ключ можна записати, але Windows може ігнорувати його на цій редакції |
| `BestEffort` | Параметр застосовується як best-effort, поведінка може залежати від build/package state |
| `RequiresVerification` | Назва/поведінка policy не повністю підтверджена для всіх build/edition. Записується, але результат варто перевірити через `Verify` / `gpresult` |
| `DeprecatedOrLegacy` | Старий або deprecated policy, залишений для сумісності |
| `UISetting` | Користувацький UI-твік, не завжди офіційна device policy |

---

# Які саме параметри змінює скрипт

Нижче наведені основні registry/policy-параметри, які скрипт перевіряє і може застосувати.

> Увага: деякі параметри Microsoft документує тільки для Enterprise/Education/IoT Enterprise. На Windows 11 Pro вони можуть записатися в реєстр, але бути проігнорованими системою. Скрипт позначає такі випадки у звіті.

---

## 1. Windows AI / Recall / Click to Do / Paint AI

| Registry path | Name | Desired value | Призначення |
|---|---|---:|---|
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI` | `AllowRecallEnablement` | `0` | Робить Recall optional component недоступним для ввімкнення, де підтримується |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI` | `DisableAIDataAnalysis` | `1` | Вимикає Recall snapshots / AI data analysis |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI` | `DisableAIDataAnalysis` | `1` | User-scoped вимкнення Recall snapshots |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI` | `AllowRecallExport` | `0` | Блокує export Recall data, де підтримується |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI` | `DisableClickToDo` | `1` | Вимикає Click to Do |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI` | `DisableClickToDo` | `1` | User-scoped вимкнення Click to Do |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI` | `DisableSettingsAgent` | `1` | Вимикає AI agent/search у Settings, де підтримується |
| `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint` | `DisableCocreator` | `1` | Вимикає Paint Cocreator |
| `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint` | `DisableGenerativeFill` | `1` | Вимикає Paint Generative Fill |
| `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint` | `DisableImageCreator` | `1` | Вимикає Paint Image Creator |

---

## 2. Copilot

| Registry path | Name | Desired value | Призначення |
|---|---|---:|---|
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot` | `TurnOffWindowsCopilot` | `1` | Вимикає legacy Windows Copilot policy. Позначено як deprecated/legacy |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `ShowCopilotButton` | `0` | Приховує кнопку Copilot на taskbar, якщо вона є |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI` | `RemoveMicrosoftCopilotApp` | `1` | Best-effort запит на видалення Copilot app, де підтримується |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI` | `RemoveMicrosoftCopilotApp` | `1` | User-scoped best-effort запит на видалення Copilot app |

Також Appx cleanup намагається видалити пакети:

```text
*Copilot*
Microsoft.Copilot*
```

---

## 3. Widgets / News / Weather

| Registry path | Name | Desired value | Призначення |
|---|---|---:|---|
| `HKLM:\SOFTWARE\Policies\Microsoft\Dsh` | `AllowNewsAndInterests` | `0` | Вимикає Widgets / News and Interests policy-backed способом |
| `HKLM:\SOFTWARE\Policies\Microsoft\Dsh` | `DisableWidgetsBoard` | `1` | Вимикає Widgets board, де підтримується |
| `HKLM:\SOFTWARE\Policies\Microsoft\Dsh` | `DisableWidgetsOnLockScreen` | `1` | Вимикає Widgets на lock screen, де підтримується |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `TaskbarDa` | `0` | Ховає кнопку Widgets на taskbar |

Примітка: якщо `AllowNewsAndInterests = 0`, Widgets уже вимкнені політикою. На деяких збірках `TaskbarDa` може бути відсутній, і це не обов’язково означає, що Widgets активні.

---

## 4. Cloud Content / Spotlight / Suggestions

| Registry path | Name | Desired value | Призначення |
|---|---|---:|---|
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent` | `DisableWindowsConsumerFeatures` | `1` | Вимикає Windows consumer experiences |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent` | `DisableSoftLanding` | `1` | Вимикає soft landing tips/prompts |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent` | `DisableCloudOptimizedContent` | `1` | Вимикає cloud optimized content |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent` | `DisableConsumerAccountStateContent` | `1` | Вимикає Microsoft account state consumer content |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent` | `DisableWindowsSpotlightFeatures` | `1` | Вимикає Windows Spotlight features |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent` | `DisableWindowsSpotlightOnActionCenter` | `1` | Вимикає Spotlight в Action Center |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent` | `DisableWindowsSpotlightOnSettings` | `1` | Вимикає Spotlight suggestions у Settings |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent` | `DisableWindowsSpotlightWindowsWelcomeExperience` | `1` | Вимикає welcome experience після оновлень |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent` | `DisableThirdPartySuggestions` | `1` | Вимикає third-party suggestions |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent` | `DisableTailoredExperiencesWithDiagnosticData` | `1` | Вимикає tailored experiences з diagnostic data |

### ContentDeliveryManager UI-параметри

Усі значення нижче ставляться у `0`:

```text
HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\ContentDeliveryAllowed
HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\OemPreInstalledAppsEnabled
HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\PreInstalledAppsEnabled
HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\PreInstalledAppsEverEnabled
HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SilentInstalledAppsEnabled
HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SystemPaneSuggestionsEnabled
HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SoftLandingEnabled
HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\RotatingLockScreenEnabled
HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\RotatingLockScreenOverlayEnabled
HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SubscribedContentEnabled
HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SubscribedContent-310093Enabled
HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SubscribedContent-338387Enabled
HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SubscribedContent-338388Enabled
HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SubscribedContent-338389Enabled
HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SubscribedContent-338393Enabled
HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SubscribedContent-353694Enabled
HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SubscribedContent-353696Enabled
```

Також:

| Registry path | Name | Desired value | Призначення |
|---|---|---:|---|
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement` | `ScoobeSystemSettingEnabled` | `0` | Вимикає “Get even more out of Windows” post-OOBE prompt |

---

## 5. Privacy / Diagnostics / Advertising ID

| Registry path | Name | Desired value | Призначення |
|---|---|---:|---|
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo` | `DisabledByGroupPolicy` | `1` | Вимикає Advertising ID політикою |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo` | `Enabled` | `0` | Вимикає Advertising ID для поточного користувача |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection` | `AllowTelemetry` | `1` | Ставить diagnostic data у Required на Pro/Home |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy` | `TailoredExperiencesWithDiagnosticDataEnabled` | `0` | Вимикає tailored experiences |
| `HKCU:\Software\Microsoft\Siuf\Rules` | `NumberOfSIUFInPeriod` | `0` | Вимикає feedback frequency prompts |
| `HKCU:\Software\Microsoft\Siuf\Rules` | `PeriodInNanoSeconds` | `0` | Вимикає feedback prompt period |

---

## 6. Windows Search

| Registry path | Name | Desired value | Призначення |
|---|---|---:|---|
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search` | `EnableDynamicContentInWSB` | `0` | Вимикає Search highlights / dynamic content |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search` | `AllowCloudSearch` | `0` | Вимикає cloud search integration |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search` | `AllowSearchToUseLocation` | `0` | Вимикає location-aware Windows Search |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search` | `DisableWebSearch` | `1` | Вимикає web search, де політика підтримується |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search` | `DoNotUseWebResults` | `1` | Забороняє web results у Search, де підтримується |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer` | `DisableSearchBoxSuggestions` | `1` | Вимикає search box suggestions у Explorer/Start |

---

## 7. Start Menu / Taskbar / Explorer

| Registry path | Name | Desired value | Призначення |
|---|---|---:|---|
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer` | `HideRecommendedSection` | `1` | Ховає Recommended section у Start, де підтримується |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer` | `HideRecommendedSection` | `1` | User-scoped варіант |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer` | `HideRecommendedPersonalizedSites` | `1` | Ховає recommended personalized sites |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer` | `HideRecommendedPersonalizedSites` | `1` | User-scoped варіант |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer` | `HideRecentlyAddedApps` | `1` | Ховає recently added apps |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer` | `HideRecentlyAddedApps` | `1` | User-scoped варіант |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer` | `HideFrequentlyUsedApps` | `1` | Ховає frequently used apps |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer` | `HideFrequentlyUsedApps` | `1` | User-scoped варіант |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `TaskbarAl` | `0` | Вирівнює taskbar ліворуч |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `SearchboxTaskbarMode` | залежить від `-SearchMode` | `Hidden=0`, `Icon=1`, `Box=2` |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `ShowTaskViewButton` | `0` | Ховає Task View button |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `TaskbarDa` | `0` | Ховає Widgets button |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `TaskbarMn` | `0` | Ховає Chat/Teams consumer button, якщо є |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `Start_TrackDocs` | `0` | Не відстежувати recent documents |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `Start_TrackProgs` | `0` | Не відстежувати frequently used programs |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `Start_IrisRecommendations` | `0` | Вимикає Start recommendations UI toggle, де підтримується |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `HideFileExt` | `0` | Показує розширення файлів |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `ShowSyncProviderNotifications` | `0` | Вимикає sync provider notifications у Explorer |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `LaunchTo` | `1` | Відкривати Explorer у This PC |

---

## 8. Windows Update

| Registry path | Name | Desired value | Призначення |
|---|---|---:|---|
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU` | `NoAutoUpdate` | `0` | Не вимикає Windows Update |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU` | `AUOptions` | `2` | **Opt-in** (`$EnableManualWindowsUpdateMode`, default off). Ручний режим оновлень |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU` | `NoAutoRebootWithLoggedOnUsers` | `1` | Уникати auto-restart, поки користувач залогінений |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` | `ExcludeWUDriversInQualityUpdate` | `1` | Не включати драйвери у Windows Updates |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` | `SetAllowOptionalContent` | `0` | Не отримувати optional updates / gradual feature rollouts автоматично |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` | `DeferFeatureUpdates` | `1` | Увімкнути deferral feature updates |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` | `DeferFeatureUpdatesPeriodInDays` | default `90` | Відкласти feature updates |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` | `DeferQualityUpdates` | `1` | Увімкнути deferral quality updates |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` | `DeferQualityUpdatesPeriodInDays` | default `7` | Відкласти quality updates |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` | `ManagePreviewBuilds` | `0` | Вимкнути user-management Insider preview builds |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` | `SetActiveHours` | `1` | Увімкнути manual active hours |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` | `ActiveHoursStart` | default `10` | Початок active hours |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` | `ActiveHoursEnd` | default `2` | Кінець active hours |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` | `TargetReleaseVersion` | `1` | **Opt-in** (`$EnableTargetReleaseVersionPin`, default off). Увімкнути target release version pinning |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` | `ProductVersion` | `Windows 11` | **Opt-in.** Target product version |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` | `TargetReleaseVersionInfo` | default `25H2` | **Opt-in.** Закріпити Windows feature version |
| `HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings` | `IsContinuousInnovationOptedIn` | `0` | Вимкнути UI toggle “Get latest updates as soon as available” |

> **Увага щодо Windows Update.** `AUOptions = 2` робить оновлення ручними: Windows лише повідомляє про них, але не завантажує і не встановлює автоматично, тому security-патчі не ставляться, поки користувач не підтвердить. Це **не** вимикає Windows Update і його службу — змінюється лише автоматизація. Закріплення версії (`TargetReleaseVersion*`) за замовчуванням вимкнене; вмикається перемикачем `$EnableTargetReleaseVersionPin`. Закріплення на EOL-релізі з часом блокує оновлення.

---

## 9. Delivery Optimization

| Registry path | Name | Desired value | Призначення |
|---|---|---:|---|
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization` | `DODownloadMode` | `0` | Вимикає peer-to-peer Delivery Optimization. HTTP only |

---

## 10. Microsoft Edge Quiet Mode

| Registry path | Name | Desired value | Призначення |
|---|---|---:|---|
| `HKLM:\SOFTWARE\Policies\Microsoft\Edge` | `StartupBoostEnabled` | `0` | Вимикає Edge Startup Boost |
| `HKLM:\SOFTWARE\Policies\Microsoft\Edge` | `BackgroundModeEnabled` | `0` | Не тримати Edge background apps після закриття |
| `HKLM:\SOFTWARE\Policies\Microsoft\Edge` | `HideFirstRunExperience` | `1` | Ховає first-run experience |
| `HKLM:\SOFTWARE\Policies\Microsoft\Edge` | `LaunchEdgeOnWindowsStartupEnabled` | `0` | Забороняє Edge запускатися при старті Windows |
| `HKLM:\SOFTWARE\Policies\Microsoft\Edge` | `PromotionalTabsEnabled` | `0` | Вимикає promotional tabs |
| `HKLM:\SOFTWARE\Policies\Microsoft\Edge` | `HubsSidebarEnabled` | `0` | Вимикає Edge sidebar/hubs, де підтримується |

---

## 11. Developer Mode / Long Paths

**Увага (Security trade-off):** Вмикання Developer Mode та sideloading (через змінну `$EnableDeveloperMode = $true`) дозволяє розгортання та запуск непідписаних/sideloaded застосунків, що розширює поверхню атаки. Використовуйте лише якщо це необхідно для розробки. За замовчуванням вимкнено.

| Registry path | Name | Desired value | Призначення |
|---|---|---:|---|
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Appx` | `AllowDevelopmentWithoutDevLicense` | `1` | Developer Mode policy |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Appx` | `AllowAllTrustedApps` | `1` | Дозволяє trusted apps / sideloading policy |
| `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock` | `AllowDevelopmentWithoutDevLicense` | `1` | UI compatibility key для Developer settings |
| `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock` | `AllowAllTrustedApps` | `1` | UI compatibility key для trusted apps |
| `HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem` | `LongPathsEnabled` | `1` | Вмикає Win32 long paths для застосунків, які підтримують `longPathAware` |

---

## 12. Fast Startup / Power

| Registry path | Name | Desired value | Призначення |
|---|---|---:|---|
| `HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power` | `HiberbootEnabled` | `0` | Вимикає Fast Startup локально |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\System` | `HiberbootEnabled` | `0` | Не вимагати Fast Startup policy-backed способом |

Скрипт **не вимикає hibernation повністю**. Він вимикає саме Fast Startup / Hybrid Boot.

---

## 13. Gaming / Game DVR

| Registry path | Name | Desired value | Призначення |
|---|---|---:|---|
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR` | `AppCaptureEnabled` | `0` | Вимикає background capture / Game DVR |
| `HKCU:\System\GameConfigStore` | `GameDVR_Enabled` | `0` | Вимикає Game DVR у GameConfigStore |
| `HKCU:\Software\Microsoft\GameBar` | `ShowStartupPanel` | `0` | Ховає Game Bar startup panel |

---

## 14. Appx Cleanup

За замовчуванням Appx cleanup вимкнений. Щоб увімкнути видалення конкретних пакетів, треба вручну змінити відповідний toggle у скрипті:

| Target | Patterns | Default |
|---|---|---:|
| Microsoft Copilot app | `*Copilot*`, `Microsoft.Copilot*` | disabled |
| Microsoft Teams personal | `MSTeams*`, `MicrosoftTeams*` | disabled |
| Xbox apps | `Microsoft.Xbox*`, `Microsoft.GamingApp*`, `Microsoft.XboxGamingOverlay*`, `Microsoft.XboxGameOverlay*`, `Microsoft.XboxIdentityProvider*`, `Microsoft.XboxSpeechToTextOverlay*` | disabled |
| OneDrive | `OneDriveSetup.exe /uninstall` | disabled |

Щоб пропустити Appx cleanup:

```powershell
.\Win11-25H2-CalmMode.ps1 -Mode Apply -NoAppCleanup
```

---

## Що скрипт НЕ робить

Скрипт навмисно **не робить** цього:

```text
- не вимикає Microsoft Defender;
- не вимикає Windows Firewall;
- не вимикає Windows Update service;
- не видаляє Microsoft Store;
- не видаляє Edge або WebView2;
- не видаляє .NET;
- не видаляє Visual C++ Redistributables;
- не блокує Microsoft domains через hosts;
- не вимикає UAC;
- не вимикає сертифікати або cryptographic services;
- не вимикає системні служби пачками.
```

---

## Відомі нюанси

### `ProductName=Windows 10 Pro` на Windows 11

На деяких збірках Windows 11 старий registry-параметр `ProductName` може показувати `Windows 10 Pro`. Скрипт додатково дивиться на `DisplayVersion`, `Build`, `EditionId` і `EditionGroup`.

### `TaskbarDa` може бути відсутній

Якщо Widgets вимкнені через policy:

```text
HKLM:\SOFTWARE\Policies\Microsoft\Dsh\AllowNewsAndInterests = 0
```

то відсутній `TaskbarDa` не завжди означає проблему. Це UI-setting, який Windows може не створювати або прибирати залежно від build/state.

### Registry verification не гарантує UI behavior

`VerifyOK` означає, що registry/policy value присутній. Це не завжди гарантує, що Windows UI на 100% поважає policy, особливо якщо вона edition-limited або build-dependent. Для таких пунктів скрипт показує `MaybeIgnoredOnEdition`, `BestEffort`, `DeprecatedOrLegacy` або `UISetting`.

---

## Як відкотити зміни

У `Apply`-режимі скрипт створює backup важливих registry-гілок у папці звіту.

Щоб вручну імпортувати backup:

```powershell
reg import "C:\Path\To\Backup.reg"
gpupdate /force
```

Також можна скористатися System Restore, якщо restore point був створений успішно.

> **Зверніть увагу:** Відновлення реєстру через rollback.reg або System Restore не відновлює автоматично видалені Appx-пакети. Їх потрібно буде встановити вручну через Microsoft Store.

---

## Перевірка вручну

Перевірити Windows AI policies:

```powershell
Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
```

Перевірити Windows Update policies:

```powershell
Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
```

Перевірити Widgets:

```powershell
Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
```

Створити Group Policy report:

```powershell
gpresult /h "$env:USERPROFILE\Desktop\gpresult.html"
```

---

## Рекомендований порядок використання

```powershell
# 1. Подивитися, що буде змінено
.\Win11-25H2-CalmMode.ps1 -Mode Audit

# 2. Застосувати
.\Win11-25H2-CalmMode.ps1 -Mode Apply

# 3. Перезавантажити ПК
Restart-Computer

# 4. Перевірити
.\Win11-25H2-CalmMode.ps1 -Mode Verify
```

---

## Official references

- WindowsAI Policy CSP: https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-windowsai
- Update Policy CSP: https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-update
- News and Interests / Widgets Policy CSP: https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-newsandinterests
- Experience Policy CSP: https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-experience
- Microsoft Edge browser policies: https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies
- Edge StartupBoostEnabled policy: https://learn.microsoft.com/en-us/deployedge/microsoft-edge-browser-policies/startupboostenabled
- Edge BackgroundModeEnabled policy: https://learn.microsoft.com/en-us/deployedge/microsoft-edge-browser-policies/backgroundmodeenabled
- Win32 maximum path length / LongPathsEnabled: https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation
- Windows Developer Mode: https://learn.microsoft.com/en-us/windows/advanced-settings/developer-mode
- ADMX WinInit / Hiberboot policy: https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-admx-wininit

---

## Disclaimer

Це неофіційний community/scripted конфігуратор. Використовуй на власний ризик. Перед запуском на основній системі бажано протестувати у VM, зробити backup важливих даних і запустити `-Mode Audit`.

---

## GitHub Actions / CI

The repository uses GitHub Actions to run a full quality gate on every push and pull request.

The workflow file is located here:

```text
.github/workflows/powershell-check.yml
```

The workflow performs the following automated checks:
- **Syntax Check:** Parses `.ps1` files and fails if PowerShell syntax errors are found.
- **PSScriptAnalyzer:** Runs static code analysis and fails on Warnings or Errors.
- **Pester Tests:** Runs unit tests for internal functions.
- **Forbidden Patterns:** Scans for dangerous patterns like `Invoke-Expression`, `DownloadString`, base64, etc.
- **Dry-run Audit:** Executes the script in `Audit` mode to ensure it runs correctly without modifying the runner configuration.
