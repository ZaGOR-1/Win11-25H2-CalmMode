# AUDIT — Win11 25H2 CalmMode

**Дата аудиту:** 2026-06-18
**Версія:** v2.2 (`VERSION` = 2.2)
**Тип перевірки:** read-only security / release-engineering review.
Apply не запускався; registry / Appx / services / системні налаштування не торкалися.
Усі дії — читання файлів, `git status/log/ls-files`, `sha256sum`, `unzip -l`, PowerShell parser-check.

---

## Підсумок

Код, release ZIP, checksums, CI і release-скрипт — у стані, придатному до релізу.
Є **один блокер** — брудне git working tree з обнуленим `AUDIT.md`.
Після усунення git-стану можна тегувати й публікувати.

**Вердикт: майже готово (1 blocker). Після фіксу git-стану — GO.**

---

## Перевірка раніше відмічених проблем

| Проблема | Стан | Деталі |
|---|---|---|
| Release ZIP має бути чистим (без `.git` / `.claude/settings.local.json`) | OK | `Win11-25H2-CalmMode-v2.2.zip` містить рівно 7 файлів: README, CHANGELOG_EN/UA, LICENSE, VERSION, `.ps1`, `.Tests.ps1`. Без `.git`, `.claude`, `.reg`, логів, звітів, вкладеного ZIP. |
| Outer/nested ZIP із `.git` | OK | У репозиторії немає вкладеного/зовнішнього ZIP — лише один чистий release-архів. |
| SHA256 має збігатися | OK | Реальний хеш `c4bd8d44…a33` == записаний у `.sha256` і `checksums.txt`. Усі 8 рядків `checksums.txt` (7 файлів + zip) верифіковано — усі OK. |
| git working tree має бути clean | **BLOCKER** | Modified: `AUDIT.md`, `PROMPT.md`. Гілка `main` випереджає `origin/main` на 6 незапушених комітів. |
| `AUDIT.md` не має бути порожнім | **BLOCKER (усувається цим записом)** | Робоча копія була 0 байт; у HEAD — 18171 байт. Файл обнулили локально. Цей звіт повертає контент. |
| README чесно описує `TargetReleaseVersionInfo` | OK | Описано в таблиці параметрів + warning-блок: pin **opt-in** (`$EnableTargetReleaseVersionPin=$false`), ризик EOL-сервісингу, `-TargetReleaseVersionInfo` діє лише коли перемикач увімкнено. |
| README чесно описує `NoAppCleanup` | OK | Параметр у таблиці + приклади `-Mode Apply -NoAppCleanup`. У скрипті реально пропускає Appx (`Skipped/SkippedBySwitch`). |
| WindowsAI / PaintAI policies мають правильний MinUBR | OK (verified) | MinUBR прив'язаний у `Get-Applicability` (спрацьовує лише коли `MinBuild == BuildNumber`). Recall-політики: `26100` + `MinUBR 3915` — підтверджено (Recall активний з build `26100.3915`). Paint `DisableCocreator`: `26100` + `MinUBR 3360` — точний UBR Microsoft публічно не фіксує, але гейт нешкідливий: на 25H2 (26200) він не застосовується (build ≠ 26100), реальний ефект лише на 26100.x. Код міняти не потрібно. |
| Release script не тягне старі audit reports / вкладений ZIP | OK | `New-ReleaseArchive.ps1` копіює whitelist із 7 файлів, не глобить `*-report.md`/`*.zip`, чистить build-папку до і після. |

---

## Issues за пріоритетом

### BLOCKER
1. **Working tree не clean + `AUDIT.md` обнулено.** Перед тегуванням відновити/закомітити AUDIT.md і розібратися з PROMPT.md.
   Фікс: за потреби `git restore AUDIT.md`, далі закомітити цей звіт, запушити 6 комітів.

### HIGH
- немає.

### MEDIUM
2. **Незапушені коміти.** ВИРІШУЄТЬСЯ: робоче дерево комітиться, далі `git push origin main` (потребує підтвердження — shared state). Тег v2.2 має вказувати на запушений коміт, інакше CI `release.yml` і GitHub Release зберуть не той стан.
3. ~~**Точність MinUBR (3915 / 3360).**~~ **RESOLVED.** Звірено: `26100.3915` (Recall) підтверджено публічними джерелами; Paint `3360` Microsoft точно не документує, але гейт нешкідливий (на 25H2/26200 не застосовується). Логіка `Get-Applicability` коректна — зміни коду не потрібні.

### LOW
4. `PROMPT.md`, `AUDIT.md`, `GEMINI.md` трекаються в git, але виключені з release ZIP — на реліз не впливає.
5. `Win11-…zip`, `*.sha256`, `checksums.txt` присутні в робочій папці, але не трекаються (gitignore) — коректно для артефактів.

---

## Підтверджено як добре зроблене

- **Parser:** `ParseFile` — 0 syntax errors.
- **Apply hard-gate:** без адміна `exit 1` (рядки 109–112), не лише warning.
- **Backup/rollback:** registry export + генерація rollback `.reg`, суворо під `Mode -eq Apply`.
- **CI `powershell-check.yml`:** syntax parse → PSScriptAnalyzer (Error+Warning) → Pester 4.10.1 → forbidden-patterns (`Invoke-Expression`, `DownloadString`, `FromBase64`, `-enc`, `Net.WebClient`) → Audit dry-run.
- **CI `release.yml`:** використовує `New-ReleaseArchive.ps1` як єдине джерело правди — локальний і CI-архів ідентичні.
- **Hygiene:** `git ls-files` не містить zip/sha256/checksums.txt/settings.local.json.
- **Build-скрипт:** SHA256 через .NET (не залежить від `Get-FileHash`), LF + UTF-8 no-BOM для крос-платформної верифікації.

---

## Pre-release checklist

```
[ ] git restore AUDIT.md (за потреби) / закомітити цей звіт
[ ] вирішити долю змін у PROMPT.md, закомітити
[ ] git status -> clean working tree
[ ] git push origin main (6 комітів)
[ ] VERSION == 2.2, збігається з ім'ям ZIP та CHANGELOG
[x] MinUBR 3915/3360 звірено (resolved)
[ ] перезібрати архів через .\New-ReleaseArchive.ps1 (НЕ вручну)
[ ] unzip -l: 7 файлів, без .git/.claude/.reg/звітів/вкладеного zip
[ ] sha256 ZIP == значення у .sha256 та checksums.txt
[ ] CI зелений на запушеному коміті
```

---

## Безпечна процедура релізу

1. `git restore AUDIT.md` (за потреби); обробити PROMPT.md; `git add -A && git commit`.
2. `git push origin main` → дочекатися зеленого CI (`powershell-check.yml`).
3. Локально (Windows PowerShell 5.1): `.\New-ReleaseArchive.ps1` — згенерує `Win11-25H2-CalmMode-v2.2.zip`, `.sha256`, `checksums.txt`.
4. Перевірити вміст ZIP і збіг SHA256 (як у checklist).
5. Створити git tag `v2.2` на запушеному коміті → `git push origin v2.2`.
6. GitHub Release для `v2.2`: прикріпити ZIP, `.sha256`, `checksums.txt`. `release.yml` перебудує архів тим самим скриптом — звірити збіг хешу.
