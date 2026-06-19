# ROADMAP — Win11 25H2 CalmMode

План розвитку, згрупований по фазах за пріоритетом. Кожен пункт лишається в рамках філософії
проєкту: **безпека, прозорість, відкатність, opt-in для ризикованого, без зовнішніх залежностей,
сумісність із Windows PowerShell 5.1**.

Легенда ризику: 🟢 низький · 🟡 середній · 🔴 потребує обережності/дизайну.

> Статус (2026-06-20): `VERSION = 2.6` (в розробці; останній реліз — тег `v2.5`). Зроблено 5A + 5B.
> Гейти зелені — parse (рушій + GUI), PSScriptAnalyzer CLEAN, Pester **42/42**, Audit `EXIT=0`,
> forbidden patterns відсутні. Лишилось **5C** (+ закрити реліз v2.6).

---

## ✅ Зроблено (стисло)

- **Фаза 0 — коректність:** UBR fail-open, preflight (HKCU hive, PowerShell bitness), no-silent-catch, PSSA 0 findings.
- **Фаза 1 — фікси (HIGH):** result-based exit code (`2`/`0`), MAIN у `try/finally`, DWord через `[long]`.
- **Фаза 2 — прозорість:** `-ReportPath`/`-NoReport`, Appx-причини незнятих пакетів, без подвійного Explorer, звіти UTF-8 без BOM, `Format-RegValueLine` для великих/негативних DWord.
- **Фаза 3.1 — конфіг + GUI:** `-ConfigPath`, `-ExportCatalog`, `Key`/`BlockKey`, WinForms-GUI + `.cmd`-лаунчер.
- **Фаза 4 — якість (v2.4):** Pester на конфіг-механізм (36 тестів), результат Audit/Apply **у вікні** GUI, Save/Load config, прибирання temp, базова HiDPI, `Get-KnownStatuses` + guard.
- **Реліз R — v2.3:** закомічено, `AUDIT.md` згенеровано, ZIP зібрано, тег `v2.3` запушено.

> Деталі попередніх фаз — у git-історії та `CHANGELOG_UA/EN`.

---

## ✅ Реліз v2.4 (виконано 2026-06-19)

- [x] **Запушено `main`** на origin (`8833216..53a548b`).
- [x] **`AUDIT.md` оновлено** під v2.4 (GUI-результат у вікні, Save/Load, тести 36, HiDPI).
- [x] **ZIP зібрано й перевірено** — `Win11-25H2-CalmMode-v2.4.zip`, 9 файлів, без сміття; SHA256 `6B2C1E84…E9BC2`.
- [x] **Тег `v2.4`** створено й запушено (release-воркфлоу запускається по тегу; `v2.2`/`v2.3` не чіпали).

---

## Фаза 5 — нові фічі

Згруповано за темами. Порядок усередині — за співвідношенням цінність/ризик.

### ✅ 5A. Зручність потоку (виконано 2026-06-20, v2.5)

- [x] **5.1 Підсумок наприкінці прогону** — блок «Summary» (total + лічильники по статусах) у всіх режимах, навіть з `-NoReport`; в Audit — «would change on Apply» (з урахуванням `-WhatIf`). Винесено в `Get-ResultSummary`/`Write-RunSummary`.
- [x] **5.2 Виявлення pending reboot** — `Test-PendingReboot` (read-only): CBS RebootPending, WU RebootRequired, PendingFileRenameOperations → `Warning` у preflight. Нічого не перезавантажує.
- [x] **5.3 Покращений HTML-звіт** — секція «Needs attention» угорі + зведення «By confidence»; порядок: Needs attention → Status summary → By confidence → Detailed results.

### ✅ 5B. Гнучкість запуску (виконано 2026-06-20, v2.6)

- [x] **5.4 CLI-перемикачі `-Skip` / `-Only`** — `-Skip` вимикає перелічені блоки, `-Only` лишає лише їх; валідація за `$script:BlockToggleMap`, конфлікт/невідомий ключ → exit 1; застосовуються після `-ConfigPath`. Pester: вимкнення блоку, only-режим, конфлікт, невідомий ключ.
- [x] **5.5 Авто-`Verify` після `Apply`** — прапор `-ThenVerify`: після Apply re-eval усього в Verify-режимі, результати дописуються в той самий звіт. GUI передає `-ThenVerify` при Apply → Verify-рядки одразу у вікні.

### 5C. Rollback і цілісність (потребує обережності)

- [ ] **5.6 Зручний rollback `-RestoreFrom <reportFolder>`** 🟡 *(колишнє 5.4)*
  - Імпорт згенерованого `rollback.reg` (`reg import`) без ручного пошуку файлу. У GUI — кнопка «Undo last Apply».
  - ⚠️ Чесно документувати: rollback повертає **лише registry**, не Appx-пакети. Вимагає admin. Підтвердження перед імпортом.

- [ ] **5.7 Opt-in `Enable-ComputerRestore`** 🔴
  - Прапор `-EnableSystemProtection`: якщо System Protection вимкнено, увімкнути перед створенням restore point (інакше точка тихо не створюється).
  - Системна зміна → **лише за явним прапором**, з попередженням і документацією ризику.

- [ ] **5.8 Authenticode-підпис `.ps1`** 🟡
  - Дати змогу перевірити цілісність скрипта (доповнює SHA256). Відкриває шлях до «легітимного» підписаного `.exe`-лаунчера без AV/SmartScreen-проблем.
  - Потребує сертифіката для підпису — інфраструктурне рішення, не лише код.

---

## Рекомендований порядок

1. ~~**Закрити реліз v2.4**~~ ✅ виконано (тег `v2.4` запушено).
2. ~~**5A (5.1 → 5.2 → 5.3)**~~ ✅ виконано (v2.5).
3. ~~**Реліз v2.5**~~ ✅ виконано (тег `v2.5` запушено).
4. ~~**5B (5.4, 5.5)**~~ ✅ виконано (v2.6, ще не зарелізено).
5. **Реліз v2.6** — закомітити, оновити AUDIT.md, ZIP, тег `v2.6`. ← наступне
6. **5C (5.6 → 5.7 → 5.8)** — обережно, з документацією, opt-in і підтвердженнями.

> Будь-яка зміна, що впливає на параметри/поведінку/звіти, має супроводжуватись оновленням
> `README.md` + `CHANGELOG_UA/EN` і, за потреби, bump версії. GUI лишається тонким шаром: уся
> логіка політик — у рушії `Win11-25H2-CalmMode.ps1` (єдине джерело істини).
>
> Незмінні «не можна» (з CLAUDE.md): не вимикати Defender/Firewall/Windows Update service, не
> видаляти Store/WebView2/.NET/VC++/сертифікати, без `Invoke-Expression`/remote code/encoded
> payloads, Appx cleanup лише opt-in і best-effort, чесність щодо build/edition-обмежень.
