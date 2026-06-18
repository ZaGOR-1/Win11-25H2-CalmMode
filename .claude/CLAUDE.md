# CLAUDE.md — інструкції для Claude Code

## Контекст проєкту

Цей репозиторій — **Win11 25H2 Calm Mode**: PowerShell-скрипт для акуратного налаштування Windows 11 25H2 у більш спокійний режим.

Мета проєкту: зменшити нав’язливі AI/Copilot/Widgets/ads/recommendations/Edge background/Windows Update driver behavior, але **не ламати Windows** і не перетворювати скрипт на агресивний debloater.

Скрипт має три основні режими:

- `Audit` — тільки читає стан системи і показує, що було б змінено.
- `Apply` — застосовує зміни, робить backup/restore point, перевіряє записи.
- `Verify` — перевіряє, чи потрібні значення реально присутні після застосування.

За замовчуванням запуск має залишатися безпечним: **`Audit`**, без змін системи.

---

## Головний принцип

Працюй як обережний senior PowerShell/Windows engineer.

Кожна зміна повинна відповідати принципу:

> Спочатку безпека, прозорість, backup, rollback і зрозумілий звіт. Потім — твік.

Не додавай “магічних” оптимізацій, якщо вони можуть зламати Windows, Store, Defender, WebView2, оновлення, сертифікати, мережу, драйвери або системні служби.

---

## Що НЕ можна робити

Ніколи не додавай у цей проєкт:

- вимкнення Microsoft Defender;
- вимкнення Windows Firewall;
- вимкнення Windows Update service;
- видалення Microsoft Store;
- видалення WebView2 Runtime;
- видалення .NET, Visual C++ runtimes, сертифікатів або системних компонентів;
- масове вимкнення служб без чіткого пояснення;
- блокування Microsoft-доменів через `hosts`;
- завантаження і виконання коду з інтернету;
- `Invoke-Expression` для remote code;
- encoded payloads;
- telemetry/privacy “твік”, якщо він реально ламає функціональність системи;
- агресивний Appx cleanup без opt-in або без можливості пропуску;
- зміни, які неможливо пояснити користувачу у README.

Якщо користувач просить “зробити максимально жорсткий debloat”, запропонуй безпечну альтернативу: більше policy-backed налаштувань, `Audit`, `Verify`, opt-in перемикачі, backup і документацію ризиків.

---

## Стиль розробки

Перед зміною коду:

1. Прочитай поточний `.ps1`, `README.md`, `CHANGELOG_UA.md`, `CHANGELOG_EN.md`.
2. Зрозумій, чи зміна належить до:
   - Windows AI / Recall / Copilot;
   - Widgets / Dsh;
   - Cloud Content / ads / recommendations;
   - Privacy;
   - Search / Start / Taskbar;
   - Windows Update;
   - Delivery Optimization;
   - Edge Quiet Mode;
   - Developer Mode / Long Paths;
   - Appx cleanup;
   - Reports / backup / rollback;
   - CI / tests / release hygiene.
3. Не роби повний rewrite без потреби.
4. Внось маленькі, зрозумілі патчі.
5. Після зміни пояснюй, що саме змінилося і чому.

---

## PowerShell правила

Проєкт орієнтований на **Windows PowerShell 5.1 Desktop**.

Пиши код так, щоб він працював у Windows PowerShell 5.1:

- не використовуй PS7-only синтаксис;
- не використовуй залежності, які треба окремо встановлювати для основного скрипта;
- не використовуй aliases у production-коді (`gci`, `?`, `%` тощо);
- не ховай помилки без причини;
- застосовуй `try/catch`, де є ризик помилки доступу, відсутності ключа, Appx або policy;
- параметри мають мати `ValidateSet`, `ValidateRange` або зрозумілі типи;
- `Apply` має вимагати запуск від адміністратора;
- `Audit` і `Verify` не повинні змінювати систему;
- усі зміни мають бути ідемпотентними: повторний запуск не повинен псувати стан.

Бажано зберігати стиль поточного скрипта:

- `Add-Result` для звіту;
- чіткі `Category`, `Item`, `Status`, `CurrentValue`, `DesiredValue`, `Path`, `Name`, `Confidence`, `Support`, `Message`;
- статуси типу `Compliant`, `WouldChange`, `Changed`, `AlreadyConfigured`, `VerifyOK`, `VerifyFail`, `Skipped`, `Warning`, `Error`, `BestEffort`, `MaybeIgnoredOnEdition`, `UnsupportedBuild`, `DeprecatedOrLegacy`, `UISetting`.

---

## Registry / policy правила

Кожен registry-твік повинен мати:

- точний `Path`;
- точний `Name`;
- правильний тип значення (`DWord`, `String`, тощо);
- desired value;
- пояснення, що він робить;
- категорію;
- рівень надійності / підтримки;
- поведінку для `Audit`, `Apply`, `Verify`;
- read-back verification після запису в `Apply`.

Якщо policy може бути build-dependent, edition-limited, deprecated або неофіційною UI-настройкою — це треба чесно позначати у звіті й документації.

Не подавай registry-твік як гарантовано робочий, якщо Windows може його ігнорувати на Home/Pro або на конкретній збірці.

---

## Backup, restore point і rollback

Не ламай існуючу логіку backup/rollback.

Перед змінами в `Apply` має зберігатися backup важливих registry-гілок, якщо це вже передбачено логікою скрипта.

Важливо:

- registry rollback не повертає видалені Appx-пакети;
- Appx cleanup треба документувати окремо;
- якщо додається нова категорія registry-змін, подумай, чи треба додати її у backup list;
- якщо restore point не вдалося створити, це має бути warning, а не прихована помилка.

---

## Appx cleanup правила

Appx cleanup — найризикованіша частина проєкту.

Дотримуйся правил:

- `-NoAppCleanup` має залишатися робочим;
- не видаляй Microsoft Store;
- не видаляй WebView2;
- не видаляй Defender / Security UI;
- не видаляй framework-пакети;
- не видаляй OneDrive або Xbox за замовчуванням, якщо це не було явно вирішено в параметрах;
- будь-яке видалення має бути best-effort і прозоро відображатися у звіті;
- у README треба писати, що rollback `.reg` не повертає Appx-пакети.

Якщо додаєш новий Appx removal pattern, спочатку перевір, чи він не зачіпає системний компонент.

---

## Документація

Якщо змінюється поведінка скрипта, онови документацію.

Оновлюй:

- `README.md` — параметри, приклади, опис політик, ризики;
- `CHANGELOG_UA.md` — коротко українською;
- `CHANGELOG_EN.md` — коротко англійською;
- коментарі в `.ps1`, якщо зміна неочевидна.

README має бути чесним:

- не обіцяй 100% ефекту для build-dependent policies;
- не приховуй edition limitations;
- пояснюй різницю між policy-backed tweak, UI tweak, best-effort tweak і deprecated/legacy tweak;
- для небезпечніших дій радь спочатку VM або тестову інсталяцію.

---

## Release hygiene

Не включай у релізний zip:

- `.git/`;
- `.claude/settings.local.json`;
- локальні логи;
- тимчасові файли;
- backup/report папки;
- secrets, токени, персональні шляхи.

Для релізу бажано мати:

- чистий `.ps1`;
- `README.md`;
- `LICENSE`;
- `CHANGELOG_UA.md`;
- `CHANGELOG_EN.md`;
- SHA256 hash для `.ps1` або zip;
- version bump, якщо змінилася поведінка.

`.claude/settings.local.json` — локальний файл. Його не треба комітити або класти в release archive.

---

## Тестування

Мінімальна перевірка після змін:

```powershell
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile(".\Win11-25H2-CalmMode-v2.1.ps1", [ref]$tokens, [ref]$errors) | Out-Null
$errors
```

Також бажано:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Win11-25H2-CalmMode-v2.1.ps1 -Mode Audit
```

Для серйозних змін:

- перевір `Audit` без адміністратора;
- перевір `Audit` від адміністратора;
- перевір `Apply` у VM;
- після reboot перевір `Verify`;
- перевір HTML/CSV/JSON reports;
- перевір, що rollback-файл створюється;
- перевір, що `-NoAppCleanup` реально пропускає Appx cleanup;
- перевір, що `-NoRestartExplorer` не перезапускає Explorer.

Якщо доступний PSScriptAnalyzer, використовуй його:

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse
```

Якщо доступний Pester — додавай тести для helper-функцій, але не роби Pester обов’язковою runtime-залежністю основного скрипта.

---

## CI / GitHub Actions

CI має хоча б перевіряти PowerShell syntax.

Бажані додаткові перевірки:

- PSScriptAnalyzer;
- контроль, що release archive не містить `.git/` і `.claude/settings.local.json`;
- перевірка на заборонені патерни: `Invoke-Expression`, remote code download execution, encoded payloads;
- генерація SHA256.

---

## Безпека відповідей Claude

Коли пропонуєш зміни, завжди вказуй:

- що зміниться;
- ризик;
- як перевірити;
- як відкотити;
- чи треба admin;
- чи треба reboot;
- чи це policy-backed, UI tweak або best-effort.

Не кажи “це точно вимкне X”, якщо Microsoft/Windows може ігнорувати policy залежно від edition/build.

Краще формулювати так:

- “скрипт виставляє policy/registry value, який має вимкнути…”;
- “на Home/Pro Windows може ігнорувати це значення”;
- “це best-effort, тому результат треба перевірити через Verify/report”.

---

## Мова і стиль

Користувач переважно пише українською.

Відповідай українською, простими словами, але технічно точно.

Стиль:

- без води;
- без перебільшень;
- пояснюй ризики чесно;
- давай готові команди, коли це доречно;
- не приховуй невпевненість;
- не радь запускати небезпечні команди без пояснення.

---

## Коли змінюєш версію

Якщо зміна впливає на поведінку користувача, параметри, Appx cleanup, registry policies або reports — запропонуй bump версії.

Наприклад:

- маленький fix документації: `v2.1.1`;
- зміна параметрів/логіки: `v2.2`;
- велика переробка архітектури: `v3.0`.

Не міняй версію автоматично без пояснення.

---

## Підсумок для Claude

Ти допомагаєш підтримувати Windows-tuning інструмент, який має бути:

- безпечний;
- прозорий;
- відкатний;
- документований;
- неагресивний;
- сумісний із Windows PowerShell 5.1;
- чесний щодо build/edition limitations.

Будь-яка зміна, яка робить скрипт “жорсткішим”, повинна бути opt-in, добре задокументована і мати зрозумілий шлях перевірки або відкату.
