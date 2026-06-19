# ROADMAP — Win11 25H2 CalmMode

План покращень основного скрипта `Win11-25H2-CalmMode.ps1`, згрупований по фазах за пріоритетом.
Кожен пункт лишається в рамках філософії проєкту: безпека, прозорість, відкатність, opt-in для ризикованого.

Легенда ризику: 🟢 низький · 🟡 середній · 🔴 потребує обережності/дизайну.

---

## ✅ Фаза 0 — зроблено (ця сесія)

- [x] UBR-гейтинг: fail-open при невідомому UBR + `[int]`-каст `$script:UBR`.
- [x] Preflight-попередження «Per-user hive (HKCU)» — коли скрипт запущено під обліковим записом, відмінним від інтерактивного користувача.
- [x] Порожні `catch {}` → `catch { Write-Verbose ... }` (не глушити помилки мовчки).
- [x] PSScriptAnalyzer: 0 findings (обґрунтовані виключення false-positive/стильових правил у `PSScriptAnalyzerSettings.psd1`).
- [x] +3 регресійні тести на `Get-Applicability` (UBR known-below / meets / unknown).

---

## Фаза 1 — швидкі безпечні фікси коректності (HIGH) — ✅ ЗРОБЛЕНО

Маленькі точкові патчі, велика віддача для надійності/автоматизації. Не торкаються системи.

- [x] **1.1 Код виходу за результатами** 🟢 ✅
  - Наприкінці MAIN: `exit 2`, якщо є хоч один `Error`/`VerifyFail`; інакше `exit 0`. Обчислюється після закриття transcript.
  - Перевірено: чистий Audit → код `0`.

- [x] **1.2 Transcript у try/finally** 🟢 ✅
  - Тіло MAIN обгорнуто в `try { … } finally { Stop-Transcript }` — лог закривається навіть при винятку посеред прогону.

- [x] **1.3 Warning для 32-bit PowerShell на 64-bit Windows** 🟢 ✅
  - Preflight-рядок «PowerShell bitness»: `Warning` + пояснення про WOW6432Node, якщо `-not Is64BitProcess -and Is64BitOperatingSystem`.

- [x] **1.4 `Test-ValueEquals` для великих DWord** 🟢 ✅
  - Порівняння через `[long]` замість `[int]` (REG_DWORD беззнаковий 32-біт). Додано регрес-тест із `0xFFFFFFFF`.

---

## Фаза 2 — прозорість і якість (MEDIUM) — ✅ ЗРОБЛЕНО

- [x] **2.1 Параметр `-ReportPath` (+ `-NoReport`)** 🟡 ✅
  - Додано `-ReportPath` (база теки звіту, дефолт — Desktop) і `-NoReport` (без теки/transcript/файлів, лише консоль).
  - `-NoReport` діє тільки в read-only режимах; у `Apply` примусово вимикається з попередженням, бо backup і `rollback.reg` потребують теки.
  - Перевірено: `Audit -ReportPath C:\Temp\…` пише туди; `Audit -NoReport` не створює папку (EXIT=0).

- [x] **2.2 Захоплення причин помилок Appx** 🟡 ✅
  - `Remove-Appx*` тепер у `try/catch` з `-ErrorAction Stop`; кожна причина незнятого пакета збирається і додається в `Message` звіту. Best-effort збережено (одна помилка не зриває весь target).

- [x] **2.3 Подвійний Explorer** 🟢 ✅
  - Після `Stop-Process explorer` скрипт стартує `explorer.exe` лише якщо shell не перезапустився сам (`Get-Process explorer`).

- [x] **2.4 UTF-8 без BOM для CSV/JSON/HTML** 🟢 ✅
  - Звіти пишуться через `UTF8Encoding($false)` (`WriteAllLines`/`WriteAllText`). Перевірено hex: перші байти CSV `22 54 69` (`"Ti`), без `EF BB BF`.

- [x] **2.5 Розширити тести** 🟢 ✅
  - Додано: `Format-RegValueLine` з великим (`0xFFFFFFFF`) і негативним (`-1`) DWord; `Get-Applicability` для `MaybeIgnoredOnEdition` + `ApplyIfMaybeUnsupported=$false` (CanApply=$false). Pester: 26/26.

- [x] **2.6 Дрібна гігієна коду** 🟢 ✅ (частково)
  - Виправлено збиті відступи у блоці `if ($EnableManualWindowsUpdateMode)`.
  - Принагідно виправлено реальний баг: `Format-RegValueLine` кодував DWord через `[int]` → переповнення для значень > 2147483647; тепер маска `[long] -band 0xffffffff`.
  - Винесення магічних рядків статусів у константи **свідомо відкладено**: це зачіпає 40+ call-site `Add-Result` і суперечить принципу «малі патчі, без rewrite». Кандидат для окремої задачі.

---

## Фаза 3 — нові фічі (за пріоритетом цінності)

- [ ] **3.1 Конфіг без редагування скрипта** 🔴 *(найбільша user-facing цінність)*
  - Проблема: усі toggles (`$Enable*`, `$Remove*`) — змінні в коді; користувач мусить правити `.ps1`.
  - Фікс: `-ConfigPath config.json` та/або CLI-перемикачі (`-Skip Widgets,Gaming` / `-Only WindowsAI`).
  - Ризик: дизайн параметрів і валідація; зберегти безпечні дефолти.
  - Перевірка: запуск із config-файлом vs без — однаковий результат для дефолтів.

- [ ] **3.2 Авто-`Verify` після `Apply`** 🟢
  - Прапор `-ThenVerify` або `-Mode All`. Зараз — два ручні запуски.

- [ ] **3.3 Виявлення pending reboot** 🟢
  - Перевіряти `Component Based Servicing\RebootPending`, `WindowsUpdate\...\RebootRequired`, `PendingFileRenameOperations`; показувати у звіті (багато політик «доїжджають» після reboot).

- [ ] **3.4 Зручний rollback** 🟡
  - Прапор `-RestoreFrom <reportFolder>` — імпорт згенерованого `rollback.reg` (`reg import`), щоб не шукати файл вручну.
  - Перевірка: `Apply` → `-RestoreFrom` повертає попередні значення.

- [ ] **3.5 Покращений HTML-звіт** 🟢
  - Секція «Needs attention» угорі (Warning / VerifyFail / RequiresVerification / MaybeIgnoredOnEdition) + зведення по `Confidence`.

- [ ] **3.6 Підсумок наприкінці** 🟢
  - Друк лічильників (`WouldChange=N, Compliant=M, …`); для `-WhatIf` — скільки б змінилось.

- [ ] **3.7 Opt-in `Enable-ComputerRestore`** 🔴
  - Прапор `-EnableSystemProtection`: якщо System Protection вимкнено, увімкнути його перед restore point (інакше точка тихо не створюється).
  - Ризик: системна зміна → лише за явним прапором, з документацією.

- [ ] **3.8 Authenticode-підпис `.ps1` / catalog** 🟡
  - Дати користувачам перевірити цілісність скрипта (доповнює наявний SHA256).

---

## Рекомендований порядок виконання

1. **Фаза 1** цілком (1.1–1.4) — дрібні, безпечні, одразу корисні.
2. **3.1** — найбільша цінність для користувачів (але потребує дизайну).
3. **3.3 + 2.1** — помітно покращують прозорість.
4. Решта Фази 2 — гігієна/якість.
5. Решта Фази 3 — за бажанням; 3.1, 3.7 робити обережно й документувати.

> Будь-яка зміна, що впливає на параметри/поведінку/звіти, має супроводжуватись оновленням README + CHANGELOG_UA/EN і, за потреби, bump версії.
