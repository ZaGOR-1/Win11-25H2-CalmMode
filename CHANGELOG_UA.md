# Журнал змін

У цьому файлі описані основні зміни проєкту.

Проєкт використовує просту схему версій: `vMAJOR.MINOR`.

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

## [v2.0] - 2026-05-22

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
  - фіксація target release на Windows 11 25H2.
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

## [v1.0] - 2026-05-22

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
