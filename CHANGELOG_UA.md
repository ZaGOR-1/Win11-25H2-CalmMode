# Журнал змін

У цьому файлі описані основні зміни проєкту.

Проєкт використовує просту схему версій: `vMAJOR.MINOR`.

## [v2.2] - 2026-06-18

### Додано

- Підтримка `-WhatIf` / `-Confirm`: скрипт тепер оголошує `SupportsShouldProcess`, тож `Apply` можна попередньо переглянути без змін системи.
- Параметр `-TelemetryLevel` (`0`–`3`) для керування політикою diagnostic data `AllowTelemetry`. За замовчуванням `1` (Required) — мінімум, який реально діє на Home/Pro; скрипт не вимикає телеметрію повністю.
- Новий статус звіту `RequiresVerification` для політик, чия точна назва чи поведінка не повністю підтверджені для всіх build/edition.
- Справжній `.gitignore` (раніше був лише приклад `gitignore-snippet.txt`), щоб локальні файли та згенеровані звіти/бекапи не потрапляли у коміт випадково.
- Спеціальний скрипт `New-ReleaseArchive.ps1` для безпечної генерації чистих `.zip` релізів без сміття.
- Глибша підтримка версіонування політик через перевірку `$MinUBR` (Update Build Revision) для політик типу Windows AI (Recall).
- Автоматизована CI/CD перевірка у GitHub Actions: додано `PSScriptAnalyzer`, Forbidden Patterns Check, і автоматичний Dry-Run Audit.

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

### Документація

- У README задокументовано параметр `-TelemetryLevel` та in-script перемикачі (module toggles).
- Додано явні попередження про закріплення Target Release Version і поведінку оновлень `AUOptions=2`.

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
