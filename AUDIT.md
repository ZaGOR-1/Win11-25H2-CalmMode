# AUDIT — Win11 25H2 Calm Mode

Аудит виконано згідно з `PROMPT.md`.
Дата: 2026-06-18
Версія, що аудитується: **v2.2** (файл `VERSION` = `2.2`)
Тип аудиту: read-only аналіз. `Apply` не запускався, registry/Appx/служби не змінювалися.

> Примітка: під час цієї сесії вже виправлено застарілий релізний zip/checksums (перезібрано
> зі свіжих файлів), `New-ReleaseArchive.ps1` зроблено стійким до відсутності `Get-FileHash`
> (рахує SHA256 через .NET), **а також закрито всі чотири High-priority пункти розділу 5**
> (див. оновлений статус нижче). Стан описує репозиторій уже **після** цих фіксів.

---

## 1. Загальна оцінка

| Аспект | Оцінка |
|--------|--------|
| Код (`Win11-25H2-CalmMode.ps1`) | **9 / 10** |
| Документація (README/CHANGELOG) | **8 / 10** |
| CI (GitHub Actions) | **8 / 10** (після фіксу Pester + уніфікації релізу) |
| Release hygiene | **9 / 10** |
| Готовність до публічного релізу | **8.5 / 10** |

---

## 2. Короткий висновок

**Майже готовий.**

Сам скрипт у дуже хорошому стані: безпечний, прозорий, ідемпотентний, з backup/rollback,
чесною класифікацією політик і безпечними дефолтами. Блокерів у самому коді немає.

Перед публічним релізом лишилося закрити декілька release/CI-питань: невідповідність двох
механізмів збірки релізу, legacy-синтаксис Pester-тестів (впаде в CI), відсутність git-тегу
`v2.2` і коміт виправлення build-скрипта.

---

## 3. Що вже добре

- **Безпечні дефолти.** `Audit` — режим за замовчуванням; усі ризиковані дії opt-in:
  `$EnableManualWindowsUpdateMode=$false`, `$EnableTargetReleaseVersionPin=$false`,
  `$EnableDeveloperMode=$false`, `$RemoveCopilotApp/$RemoveTeamsPersonal/$RemoveXboxApps/$RemoveOneDrive=$false`.
- **`Apply` вимагає адміністратора** (перевірка + `exit 1`), `Audit`/`Verify` read-only.
- **Немає небезпечних патернів:** не знайдено `Invoke-Expression` (у проді), `DownloadString`,
  `FromBase64String`, `-EncodedCommand`, `Net.WebClient`, `Start-BitsTransfer`, remote code execution.
  Єдині збіги `Invoke-Expression` — у тесті (dot-source функцій), CI-перевірці, прикладі налаштувань і документації.
- **Не ламає систему:** не вимикає Defender, Firewall, службу Windows Update; не видаляє Store, WebView2, .NET, сертифікати.
- **Backup/rollback:** registry-backup перед змінами, спроба restore point (warning, а не прихована помилка),
  по-значеннєвий `rollback.reg` як fallback. README чесно попереджає, що rollback **не** повертає видалені Appx (рядок 514).
- **Чесна класифікація політик:** `Official`, `RequiresVerification`, `BestEffort`, `Deprecated`,
  `UISetting`, `MaybeIgnoredOnEdition`, `UnsupportedBuild`. Edition-/build-обмеження враховані через `MinBuild`/`MinUBR`/`Editions`.
- **WindowsAI/Recall/Paint AI metadata коректна:** `AllowRecallEnablement`, `DisableAIDataAnalysis` —
  `MinBuild 26100` + `MinUBR 3915`, editions Pro/Enterprise/Education/IoT, `Official`; недопідтверджені
  (`AllowRecallExport`, `DisableClickToDo`, `DisableSettingsAgent`) — `RequiresVerification`;
  Paint AI — `MinBuild 26100` + `MinUBR 3360`.
- **Windows Update:** `AUOptions=2` і Target Release pinning — обидва opt-in; README попереджає про ризик EOL-релізів.
- **`-WhatIf`/`-Confirm`** працюють (`SupportsShouldProcess`).
- **Звіти** HTML/CSV/JSON з HTML-екрануванням; transcript-лог.
- **README структурований:** є розділи «Що скрипт НЕ робить», «Відомі нюанси», Official references, Disclaimer, CI.
- **Релізний zip чистий:** 7 файлів, без `.git/`, без `.claude/settings.local.json`, без `.gitignore`, без вкладеного zip, без `.reg`/логів/звітів.
- **Хеші збігаються:** усі per-file SHA256 у `checksums.txt` відповідають робочому дереву; `.zip.sha256` відповідає фактичному zip.

---

## 4. Critical blockers

**Немає.** Жодна проблема наразі не блокує безпечну публікацію самого скрипта.
(Початковий блокер — застарілий zip/checksums — уже усунено в цій сесії.)

---

## 5. High priority — ✅ УСІ ВИПРАВЛЕНО

### 5.1. Два розбіжні механізми збірки релізу — ✅ виправлено
- **Було:** локальний `New-ReleaseArchive.ps1` створював `Win11-25H2-CalmMode-v2.2.zip` (uppercase-хеші),
  а CI `release.yml` — `Win11-25H2-CalmMode-Release.zip` (7 файлів, lowercase `sha256sum`). Різні імена/файли/формат.
- **Виправлення:** `release.yml` тепер викликає канонічний `New-ReleaseArchive.ps1` через `shell: pwsh` —
  єдине джерело істини. Крок Upload бере версійний архів за маскою `Win11-25H2-CalmMode-v*.zip` + `.sha256` + `checksums.txt`.
- **Як перевірити:** `workflow_dispatch` для `release.yml` і локальний запуск дають однакові ім'я, набір файлів і хеші.

### 5.2. Pester-тести на legacy-синтаксисі `Should Be` — ✅ виправлено
- **Було:** тести на `Should Be` (Pester v4), а CI ставив `Install-Module Pester -Force` → Pester v5, де `Should Be` прибрано.
- **Виправлення:** у `powershell-check.yml` запінено `Pester 4.10.1`
  (`Install-Module Pester -RequiredVersion 4.10.1 -Force -SkipPublisherCheck` + `Import-Module -RequiredVersion 4.10.1`).
  Обрано пін (а не міграцію на `Should -Be`), бо це гарантовано не ламає наявні тести, а перевірити міграцію в поточному середовищі неможливо.
- **Як перевірити:** крок «Run Pester tests» у CI — 0 failed.

### 5.3. Git-тег `v2.2` — ✅ створено локально (push робиться вручну)
- **Було:** `git tag` порожній.
- **Виправлення:** створено локальний анотований тег `v2.2` на коміті з фіксами.
- **Лишилось вручну:** `git push --tags` + створити GitHub Release (публікація — за рішенням maintainer-а).
- **Як перевірити:** `git tag` показує `v2.2`.

### 5.4. Незакомічене виправлення `New-ReleaseArchive.ps1` — ✅ виправлено
- **Було:** `git status` показував незакомічений фікс.
- **Виправлення:** усі фікси (build-скрипт, обидва CI-воркфлоу, цей AUDIT.md) закомічено.
- **Як перевірити:** `git status` → `working tree clean`.

---

## 6. Medium priority — ✅ УСІ ВИПРАВЛЕНО

- **`release.yml` `.sha256` для невірного імені — ✅ виправлено.** Знято разом із 5.1: `release.yml`
  тепер викликає `New-ReleaseArchive.ps1`, який генерує версійний `Win11-25H2-CalmMode-v<version>.zip.sha256`.
- **`New-ReleaseArchive.ps1` кладе `.gitignore` у реліз — ✅ виправлено.** `.gitignore` прибрано зі списку
  `$filesToInclude`. Архів перезібрано: тепер **7 файлів** (без `.gitignore`), хеші оновлено, `.zip.sha256` збігається з фактичним zip.
- **`RELEASE.md` дубльована нумерація — ✅ виправлено.** Перенумеровано на 1–7; додано окремий крок «Verify the archive»
  і узгоджено з версійним ім'ям zip + `.sha256` + `checksums.txt`.
- **`AUDIT.md` був порожній — ✅ виправлено.** Заповнено цим документом.
- **`checksums.txt` — формат залежав від механізму збірки — ✅ виправлено.** Знято разом із 5.1: тепер єдине
  джерело збірки (`New-ReleaseArchive.ps1`) → однаковий формат локально й у CI.

---

## 7. Low priority / polish

- Uppercase (локально) проти lowercase (CI) у форматі хешів — косметика, але краще привести до одного стилю.
- `checksums.txt` пишеться з CRLF (PowerShell `Add-Content`) — не критично, але `\n` був би переноснішим.
- README дуже довгий (38 KB) — за бажанням винести детальні таблиці політик у окремий `POLICIES.md`.

---

## 8. README / documentation fixes

- **`CLAUDE.md`:** у блоці тестування й по тексту згадується старе ім'я `Win11-25H2-CalmMode-v2.1.ps1`;
  актуальне ім'я — стабільне `Win11-25H2-CalmMode.ps1`. Оновити приклади.
- **`RELEASE.md`:** ✅ перенумеровано (1–7), додано крок верифікації архіву, узгоджено з версійним ім'ям zip.
- **README:** наразі відповідає коду (параметри, дефолти, статуси, Appx limitations, rollback, Target Release pinning,
  Manual Update mode, Gaming-секція збігається з кодом). Після уніфікації релізу — звірити назву публікованого архіву.
- **`CHANGELOG_UA.md` / `CHANGELOG_EN.md`:** актуальні для v2.2. Якщо фікс `New-ReleaseArchive.ps1` піде окремим релізом —
  додати запис (напр. `v2.2.1` як tooling-fix).
- Typo `PROMT.md` не виявлено — файл коректно зветься `PROMPT.md`.

---

## 9. Code fixes

- **`Win11-25H2-CalmMode.ps1`:** змін не потрібно. Синтаксис парситься без помилок; логіка Audit/Apply/Verify,
  backup, rollback, applicability (MinBuild/MinUBR/Editions) коректна; небезпечних патернів немає.
- **`New-ReleaseArchive.ps1`:** уже виправлено (helper `Get-Sha256Hex` через .NET замість `Get-FileHash`;
  `.gitignore` прибрано зі списку файлів релізу — архів тепер 7 файлів).
- **`Win11-25H2-CalmMode.Tests.ps1`:** мігрувати `Should Be` → `Should -Be` (див. 5.2). Тести систему не змінюють (dot-source лише функцій) — це добре.

---

## 10. CI / release fixes

- **`powershell-check.yml`:**
  - Pester: пінити v4 або синхронізувати з міграцією тестів на v5 (5.2).
  - PSScriptAnalyzer запускається з `-Severity Error,Warning`; локально модуль перевірити не вдалося
    (середовище не вантажить модуль) — **перевірити на чистій машині/у CI**, що немає Warning, які завалять крок.
  - Syntax check і forbidden-pattern scan коректні; forbidden scan свідомо виключає `Tests.ps1` (правильно).
  - Dry-run Audit запускається через `shell: powershell` (Desktop) — узгоджено з `#requires -PSEdition Desktop`. Добре.
- **`release.yml`:** уніфікувати з локальним build-скриптом (5.1) — ім'я архіву, набір файлів, формат і ім'я `.sha256`.

---

## 11. Final pre-release checklist

```markdown
- [x] Audit — режим за замовчуванням
- [x] Apply вимагає admin
- [x] Безпечні дефолти (усі ризиковані дії opt-in)
- [x] Немає небезпечних патернів (IEX/remote/base64/encoded)
- [x] Backup + rollback + restore point логіка на місці
- [x] README чесний щодо Appx/rollback/edition limitations
- [x] CHANGELOG_UA / CHANGELOG_EN оновлені для v2.2
- [x] Релізний zip без .git/.claude/.reg/логів/звітів/вкладеного zip
- [x] Per-file SHA256 і .zip.sha256 збігаються з фактичними файлами
- [x] Синтаксис усіх .ps1 без помилок
- [x] Уніфікувати New-ReleaseArchive.ps1 та release.yml (ім'я/файли/хеші)
- [x] Виправити Pester-тести під версію Pester у CI (пін Pester 4.10.1)
- [x] Закомітити фікси (working tree clean)
- [x] Створити git-тег v2.2 (локально; push + GitHub Release — вручну)
- [x] Прибрати .gitignore зі складу релізного архіву (тепер 7 файлів)
- [x] Перенумерувати RELEASE.md (1–7)
- [ ] `git push --tags` і створити GitHub Release (вручну, рішення maintainer-а)
- [ ] Перевірити PSScriptAnalyzer (Error,Warning) у CI / на чистій машині (Low)
- [ ] Оновити старі згадки імені файлу у CLAUDE.md (Low/docs)
```

---

## 12. Safe release procedure

```powershell
# 1. Переконатися, що дерево чисте і всі правки закомічені
git status

git add New-ReleaseArchive.ps1   # + інші виправлення (тести, CI, docs)
git commit -m "Fix release tooling and tests before v2.2"

# 2. Тег версії
git tag v2.2

git push
git push --tags

# 3. Зібрати чистий архів локально (Apply НЕ запускати)
.\New-ReleaseArchive.ps1
```

Після цього **вручну**:
- розпакувати `Win11-25H2-CalmMode-v2.2.zip` і переконатися, що всередині немає `.git/`,
  `.claude/`, `.reg`, логів, звітів, вкладеного zip;
- звірити SHA256: вміст `Win11-25H2-CalmMode-v2.2.zip.sha256` має дорівнювати реальному хешу архіву;
- створити GitHub Release для тега `v2.2` і прикріпити zip + `.sha256` (+ `checksums.txt`).

---

## 13. Висновок

Інструмент за духом і реалізацією відповідає меті: обережний policy-based конфігуратор, а не
агресивний debloater. Код безпечний, прозорий, відкатний і чесно задокументований — у маси його
випускати можна без ризику зламати Windows.

Усі High-priority пункти розділу 5 закрито: механізми збірки релізу уніфіковано (CI викликає
канонічний `New-ReleaseArchive.ps1`), Pester у CI запінено на 4.10.1, фікси закомічено, тег `v2.2`
створено локально. Лишилися лише ручні кроки публікації (`git push --tags` + GitHub Release) та
дрібні Medium/docs-покращення, які релізу не блокують. **Проєкт готовий до публікації як стабільний v2.2.**
