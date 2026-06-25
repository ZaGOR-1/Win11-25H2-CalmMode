# ROADMAP — Win11 25H2 Calm Mode

Це живий список тільки майбутніх задач. Уже виконані релізи, фікси, локалізація, cleanup root-файлів,
розбиття README на `docs/` і GUI фази 1-6 тут більше не зберігаються — вони мають жити в changelog.

Принципи незмінні: безпека, прозорість, backup/rollback, opt-in для ризикових дій, без зовнішніх
runtime-залежностей, основна сумісність із Windows PowerShell 5.1.

Поточний стан на 2026-06-25:

- `VERSION = 2.12.1`;
- `v2.12.1` оформлює launcher/test hygiene fixes після релізу GUI/docs оновлень;
- локально проходили Windows PowerShell 5.1 parse, GUI `-SelfTest`, `git diff --check`;
- повний живий `Apply -> reboot -> Verify -> Restore` у VM ще не задокументований.

Легенда: ✅ варто зробити · ⚠️ опційно · 🟢 низький ризик · 🟡 середній ризик · 🔴 обережно.

---

## 1. Жива довіра до Apply-шляху

- [ ] **VM-валідація повного циклу.** Потрібен документований прогін у чистій Windows 11 25H2 VM:
  `Audit` без admin → `Audit` з admin → `Apply` → повторний `Apply` → reboot → `Verify` →
  `Undo last Apply` / `-RestoreFrom` → повторний `Verify`.

  Очікувані артефакти:
  - HTML/CSV/JSON звіти;
  - короткий документ `docs/VM_VALIDATION_UA.md` або `docs/VM_VALIDATION.md`;
  - список знайдених відмінностей між Audit/Apply/Verify;
  - окреме підтвердження, що rollback registry працює, а Appx cleanup не відновлюється через `.reg`.

  **Чи треба:** ✅ так. Це найбільша реальна прогалина довіри, бо unit/self-test не замінюють живий
  запис у registry, reboot і restore. 🟡

---

## 2. GUI polish, фаза 7

- [ ] **Візуальна перевірка GUI на різних масштабах.** Перевірити 100%, 125%, 150%, мале вікно,
  resize, splitter, UA/EN, довгі назви, вкладки результатів і tooltip-и.

- [ ] **Оновити screenshots у README/docs після стабілізації GUI.** Поточний інтерфейс суттєво
  змінився, тому старі скріншоти або відсутність скріншотів зменшують зрозумілість.

- [ ] **Перевірити UX після реального Apply.** Окремо подивитися, чи status line, Apply gate,
  Summary/Details/Raw і rollback flow зрозумілі після elevated Apply.

  **Чи треба:** ✅ так перед великим публічним релізом GUI. Ризик низький, але потрібна ручна перевірка. 🟢

---

## 3. Безпечний one-command bootstrap без `iex`

- [ ] **Додати безпечний bootstrap/install script.** Мета: дати користувачу коротку команду, яка
  скачує release zip, перевіряє hash, розпаковує в локальну папку і запускає GUI.

  Важливі обмеження:
  - не використовувати `irm ... | iex`;
  - не виконувати remote code напряму;
  - завантажувати тільки release archive;
  - перевіряти SHA256;
  - запускати GUI локально;
  - default flow лишається Audit-first.

  **Чи треба:** ⚠️ корисно для зручності, але тільки якщо реалізовано без `Invoke-Expression` і без
  remote-code execution. 🟡

---

## 4. Reports tooling

- [ ] **`-CompareReports <before.json> <after.json>`.** Read-only режим для порівняння двох JSON-звітів:
  що змінило `Status`, `CurrentValue`, `DesiredValue`, `Support`, `Confidence`.

  Корисні сценарії:
  - Audit до Apply проти Verify після reboot;
  - regression check між версіями скрипта;
  - швидкий текстовий summary для GitHub issue.

  **Чи треба:** ⚠️ корисне полірування, але не критично, бо JSON можна порівнювати вручну. 🟢

---

## 5. Presets

- [ ] **Готові JSON-пресети конфігів.** Наприклад:
  - `presets/minimal.json`;
  - `presets/balanced.json`;
  - `presets/strict.json`.

  GUI може отримати `Load preset`, але це має лишатися тонким шаром над наявним `-ConfigPath`.
  Presets не повинні вмикати ризиковий Appx cleanup без явної назви/попередження.

  **Чи треба:** ⚠️ опційно. Це зручно для користувачів, але частково дублює Save/Load config. 🟢

---

## 6. Майбутні policy-кандидати

Кожен новий твік має проходити окрему перевірку перед додаванням:

- Microsoft Learn / ADMX / Edge policy reference;
- точні `Path`, `Name`, `Type`, desired value;
- `MinBuild` / `MinUBR`;
- edition limitations;
- чесний `Confidence`;
- tests;
- README/docs/changelog.

### 6a. Edge quiet mode — розширення

- [ ] `ShowRecommendationsEnabled=0` — менше рекомендацій/підказок Edge.
- [ ] `EdgeShoppingAssistantEnabled=0` — shopping/coupons UI.
- [ ] `PersonalizationReportingEnabled=0` — менше personalization reporting.
- [ ] `SpotlightExperiencesAndRecommendationsEnabled=0` — Edge spotlight/recommendations.
- [ ] `NewTabPageContentEnabled=0` — MSN/content на новій вкладці; краще opt-in, бо змінює NTP.

**Чи треба:** ⚠️ добрі кандидати, але тільки після повторної звірки з актуальною Edge policy reference. 🟢

### 6b. Activity history / Timeline

- [ ] `EnableActivityFeed=0`;
- [ ] `PublishUserActivities=0`;
- [ ] `UploadUserActivities=0`.

**Чи треба:** ⚠️ добре вписується в privacy/calm, якщо Microsoft docs підтверджують актуальність на 25H2. 🟢

### 6c. Online tips у Settings

- [ ] `AllowOnlineTips=0`.

**Чи треба:** ⚠️ потенційно корисний calm-твік, але треба ще раз підтвердити шлях/edition/build. 🟢

### 6d. Policy-версія taskbar search

- [ ] `ConfigureSearchOnTaskbarMode`.

**Чи треба:** ⚠️ тільки opt-in. Це жорсткіше за UISetting `SearchboxTaskbarMode`, бо може блокувати
перемикач у Settings. 🟡

---

## 7. Не планувати без окремого рішення

Ці напрямки не входять у roadmap, доки не буде дуже чіткої причини:

- повне вимкнення Windows Search або індексації;
- вимкнення Defender, Firewall або Windows Update service;
- видалення Store, WebView2, .NET, VC++ runtimes, сертифікатів;
- блокування Microsoft-доменів у `hosts`;
- `Invoke-Expression`, encoded payloads або remote-code execution;
- агресивний Appx cleanup за замовчуванням;
- переписування рушія на модулі без конкретної користувацької користі;
- компільований `.exe`, якщо він погіршує прозорість/довіру.
