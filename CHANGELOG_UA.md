# Журнал змін

У цьому файлі описані основні зміни проєкту.

Проєкт використовує просту схему версій: `vMAJOR.MINOR`.

## [v2.3] - 2026-06-19

### Додано

- **Графічний інтерфейс** `Win11-25H2-CalmMode-GUI.ps1` (Windows Forms, без зовнішніх залежностей): дерево з галочками — блоки з розкриттям у окремі твіки. Кнопка **Run Audit** (read-only) і окрема кнопка **Apply** (з підтвердженням і вимогою адміністратора). GUI не містить власної логіки політик — він лише читає каталог рушія і формує конфіг.
- **Лаунчер `Win11-25H2-CalmMode-GUI.cmd`** для запуску GUI подвійним кліком. Це звичайний текстовий `.cmd` (не компільований `.exe`, без base64/прихованого коду) — навмисно, щоб зберегти прозорість і уникнути хибних спрацювань антивірусу/SmartScreen.
- Параметр `-ConfigPath <json>` для рушія: дозволяє вмикати/вимикати блоки і вимикати окремі твіки через конфіг-файл, без редагування `.ps1`. Схема: `{ "blocks": { "<BlockKey>": true|false }, "disabledTweaks": ["<Path>\<Name>"] }`.
- Параметр `-ExportCatalog` для рушія: read-only режим, що друкує JSON-каталог усіх блоків і твіків (нічого не змінює, без теки/transcript). Це «контракт», який споживає GUI — рушій лишається єдиним джерелом істини.
- Кожен твік тепер має стабільний ключ (`"$Path\$Name"`) і тег блоку (`BlockKey`) — для вибору в конфігу й групування в GUI.

### Змінено

- Вимкнений через `-ConfigPath` окремий твік отримує статус `Skipped` («Disabled via -ConfigPath selection.») і не читається/не пишеться.

### Виправлено

- Чистіший transcript-лог: `Get-RegValueSafe` тепер читає ключ цілком і шукає значення через `PSObject`, тож відсутнє значення більше не кидає terminating error (раніше `-Name ... -ErrorAction Stop` спричиняв десятки рядків `PS>TerminatingError(Get-ItemProperty)` у логу, хоча catch їх коректно обробляв). Результати аудиту незмінні.
- Appx-аудит без прав адміністратора більше не засмічує лог: виклики `Get-AppxPackage -AllUsers` і `Get-AppxProvisionedPackage -Online` (які завжди потребують elevation і кидали terminating `Access is denied` / `requires elevation`) пропускаються, коли скрипт запущено не від адміністратора. Дані ті самі (порожньо), лог чистий.

## [v2.2] - 2026-06-18

### Додано

- Підтримка `-WhatIf` / `-Confirm`: скрипт тепер оголошує `SupportsShouldProcess`, тож `Apply` можна попередньо переглянути без змін системи.
- Параметр `-TelemetryLevel` (`0`–`3`) для керування політикою diagnostic data `AllowTelemetry`. За замовчуванням `1` (Required) — мінімум, який реально діє на Home/Pro; скрипт не вимикає телеметрію повністю.
- Новий статус звіту `RequiresVerification` для політик, чия точна назва чи поведінка не повністю підтверджені для всіх build/edition.
- Справжній `.gitignore` (раніше був лише приклад `gitignore-snippet.txt`), щоб локальні файли та згенеровані звіти/бекапи не потрапляли у коміт випадково.
- Спеціальний скрипт `New-ReleaseArchive.ps1` для безпечної генерації чистих `.zip` релізів без сміття.
- Глибша підтримка версіонування політик через перевірку `$MinUBR` (Update Build Revision) для політик типу Windows AI (Recall).
- Автоматизована CI/CD перевірка у GitHub Actions: додано `PSScriptAnalyzer`, Forbidden Patterns Check, і автоматичний Dry-Run Audit.
- Параметр `-ReportPath` — базова тека для звітів (за замовчуванням Робочий стіл), щоб не засмічувати Робочий стіл.
- Параметр `-NoReport` — пропустити теку звіту, transcript і файли CSV/HTML/JSON (вивід лише в консоль). Діє лише в read-only режимах; у `Apply` ігнорується з попередженням, бо backup і `rollback.reg` потребують теки.

### Змінено

- Закріплення Target Release Version тепер **opt-in** через перемикач `$EnableTargetReleaseVersionPin` (за замовчуванням вимкнено). Закріплення feature-версії може заблокувати майбутні feature-/security-оновлення після кінця сервісингу релізу.
- Перекласифіковано `DisableSettingsAgent`, `DisableWidgetsBoard` і `DisableWidgetsOnLockScreen` з `Official` на `RequiresVerification`.
- Виправлено й уточнено опис `AUOptions=2`: він робить оновлення ручними (сповіщення перед завантаженням і встановленням). Тепер це налаштування **вимкнене за замовчуванням**; для активації використовуйте `$EnableManualWindowsUpdateMode = $true`.
- Статус Edge політики `PromotionalTabsEnabled` змінено на `Deprecated`.
- Видалення Copilot і Teams Appx переведено у суворий opt-in (тепер `$false` за замовчуванням).
- **Архітектурна зміна:** основний скрипт перейменовано з `Win11-25H2-CalmMode-v2.2.ps1` на стабільне ім'я `Win11-25H2-CalmMode.ps1`.
- Версія проєкту тепер зберігається в окремому файлі `VERSION`, звідки вона динамічно зчитується скриптом і CI/CD пайплайнами під час збірки релізів. Це робить оновлення простішими та усуває необхідність постійно перейменовувати файл.
- Покращено точність застосування Windows AI та Paint політик (додано точні перевірки `MinUBR`).
- Посилено гігієну релізів: хеш архіву (`.sha256`) тепер генерується окремим файлом поруч із ZIP, замість вкладення всередину. Скрипти збірки тепер суворо виключають файли аудит-звітів.
- Зміцнено release-інструментарій: `New-ReleaseArchive.ps1` рахує SHA256 через .NET (без залежності від `Get-FileHash`), пише `checksums.txt` і `.sha256` з LF + UTF-8 без BOM і не кладе `.gitignore` в архів. CI release-воркфлоу тепер викликає цей самий скрипт як єдине джерело істини, а CI пінить Pester `4.10.1` під синтаксис тестів.

### Виправлено

- Гейтинг за `MinUBR` більше не дає хибний `UnsupportedBuild`, коли UBR прочитати не вдалося: `$script:UBR` приводиться до `[int]`, а перевірка спрацьовує лише за відомого UBR (`> 0`) — fail-open замість блокування.
- `Test-ValueEquals` порівнює DWord через `[long]`, а не `[int]`, щоб desired value > 2147483647 не переповнював Int32.
- Скрипт повертає код виходу за результатами: `0` — чисто, `2` — є хоч один `Error`/`VerifyFail` (корисно для `Verify` у планувальнику/CI).
- Тіло MAIN обгорнуто в `try/finally`, тож transcript-лог коректно закривається навіть при винятку посеред прогону.
- Порожні `catch {}` замінено на запис помилки у verbose-потік (не глушити мовчки).
- `Format-RegValueLine` кодує DWord через маску `[long] -band 0xffffffff`, тож великі беззнакові (`0xFFFFFFFF`) та негативні значення (`-1` → `ffffffff`) у `rollback.reg` більше не переповнюють Int32.
- Appx cleanup тепер фіксує причину кожного незнятого пакета (раніше `-ErrorAction SilentlyContinue` глушив її) і додає в `Message` звіту, лишаючись best-effort.
- Перезапуск Explorer більше не плодить два процеси: скрипт стартує `explorer.exe` лише якщо Windows не перезапустила shell сама.
- Звіти CSV/JSON/HTML пишуться як UTF-8 **без BOM** (через `UTF8Encoding($false)`), що спрощує парсинг сторонніми інструментами.
- Дрібна гігієна коду: виправлено збиті відступи у блоці `if ($EnableManualWindowsUpdateMode)`.

### Додано (preflight-перевірки)

- Попередження «Per-user hive (HKCU)»: якщо скрипт запущено під обліковим записом, відмінним від інтерактивного користувача, per-user (HKCU) налаштування потрапляють у профіль цього акаунта — тепер це чесно видно у звіті як `Warning`.
- Попередження «PowerShell bitness»: 32-bit PowerShell на 64-bit Windows дає WOW6432Node-редирекцію частини `HKLM\SOFTWARE`; preflight радить перезапустити 64-bit Windows PowerShell.

### Документація

- У README задокументовано параметр `-TelemetryLevel` та in-script перемикачі (module toggles).
- Додано явні попередження про закріплення Target Release Version і поведінку оновлень `AUOptions=2`.
- Додано `SECURITY.md` (приватний репортинг вразливостей, перевірка цілісності релізу).

## [v2.1] - 2026-05-22

### Виправлено

- Виправлено хибний `VerifyFail` для registry-значення `TaskbarDa`.
  - Якщо Widgets уже вимкнені політикою через `HKLM:\SOFTWARE\Policies\Microsoft\Dsh\AllowNewsAndInterests = 0`, відсутність UI-значення `TaskbarDa` більше не вважається помилкою.
  - Це прибирає неправильний звіт про помилку, коли Widgets фактично вже вимкнені системною політикою.
- Покращено визначення Windows 11.
  - Скрипт тепер визначає Windows 11 за build number `>= 22000`, а не тільки за `ProductName`.
  - Це виправляє зайві попередження на Windows 11, де старі registry-поля можуть досі показувати `Windows 10 Pro`.

### Змінено

- Покращено логіку перевірки UI-параметрів панелі задач.
- Зменшено кількість зайвих попереджень під час preflight-перевірки.

## [v2.0] - 2026-05-10

### Додано

- Додано три режими запуску:
  - `Audit` — перевіряє поточний стан системи без внесення змін.
  - `Apply` — застосовує тільки ті налаштування, які ще не налаштовані.
  - `Verify` — перевіряє, чи потрібні registry/policy-значення реально присутні після налаштування.
- Додано HTML, CSV і JSON-звіти.
- Додано backup registry перед застосуванням змін.
- Додано спробу створити точку відновлення перед застосуванням змін.
- Додано налаштування політик Windows AI / Recall / Copilot.
- Додано налаштування Widgets / News / Weather.
- Додано налаштування Cloud Content / Consumer Experience / Spotlight.
- Додано базові privacy та diagnostics налаштування.
- Додано тихіший режим Windows Search.
- Додано очищення Start Menu та Taskbar від зайвих рекомендацій.
- Додано контроль Windows Update:
  - виключення драйверів з Windows Update;
  - відкладання feature updates;
  - відкладання quality updates;
  - вимкнення автоматичного отримання optional feature rollout;
  - фіксація target release на Windows 11 25H2 (у v2.2 переведено у режим opt-in).
- Додано налаштування Delivery Optimization.
- Додано Microsoft Edge Quiet Mode:
  - вимкнення Startup Boost;
  - вимкнення background mode;
  - приховування first-run experience;
  - зменшення рекламної/промо-поведінки Edge.
- Додано налаштування Developer Mode.
- Додано підтримку Win32 Long Paths.
- Додано керування Fast Startup без вимкнення гібернації.
- Додано налаштування Game DVR / Game Bar.
- Додано опціональне видалення Copilot app.
- Додано опціональне видалення Microsoft Teams personal.
- Додано опціональний перемикач для Xbox apps cleanup.

### Змінено

- Скрипт перероблено у безпечніший конфігуратор, а не просто одноразовий набір твік-команд.
- Додано статуси для кожного налаштування:
  - `Compliant`;
  - `WouldChange`;
  - `Changed`;
  - `VerifyOK`;
  - `VerifyFail`;
  - `Skipped`;
  - `Warning`;
  - `BestEffort`;
  - `MaybeIgnoredOnEdition`.
- Чіткіше розділено офіційні політики, UI-параметри та best-effort твіки.
- Покращено логування та генерацію звітів.

### Примітки

- Скрипт не вимикає Microsoft Defender.
- Скрипт не вимикає Windows Firewall.
- Скрипт не вимикає службу Windows Update.
- Скрипт не видаляє Microsoft Store.
- Скрипт не видаляє Edge WebView2 Runtime.
- Скрипт не видаляє .NET, Visual C++ Redistributables, сертифікати або критичні компоненти Windows.

## [v1.0] - 2026-04-15

### Додано

- Початкова версія скрипта для налаштування Windows 11 Calm Mode.
- Додано базові registry-based налаштування для:
  - Copilot;
  - Widgets;
  - Windows consumer experience;
  - advertising ID;
  - diagnostic data;
  - Windows Search;
  - Windows Update;
  - Delivery Optimization;
  - Taskbar і Start Menu;
  - Game DVR.
- Додано базовий backup і логування.
