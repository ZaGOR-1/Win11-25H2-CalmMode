Ти — senior Windows/PowerShell engineer, security reviewer, release engineer і maintainer open-source проєктів.

Проаналізуй поточний стан проєкту **Win11 25H2 CalmMode** повністю.

Це Windows 11 tuning / privacy / calm mode інструмент. Він має бути обережним policy-based конфігуратором, а не агресивним debloater.

Твоє завдання — зробити повний аудит поточного стану проєкту і окремо перевірити проблеми, які вже були знайдені раніше.

---

# Важливі правила безпеки

* Нічого не змінюй у системі.
* Не запускай `Apply`.
* Не змінюй registry.
* Не видаляй Appx-пакети.
* Не змінюй Windows services.
* Не запускай команди з правами адміністратора.
* Не вимикай Defender, Firewall, Windows Update, Store, WebView2, UAC.
* Не пропонуй агресивний debloat.
* Не запускай невідомі скрипти, які можуть змінити систему.
* Працюй як reviewer/release engineer.

Можна запускати тільки безпечні команди:

* перегляд структури файлів;
* `git status`;
* `git log --oneline -5`;
* перевірка ZIP-вмісту;
* перевірка SHA256;
* PowerShell syntax check;
* PSScriptAnalyzer;
* Pester tests, якщо вони не змінюють систему;
* grep/search по коду.

---

# Що треба проаналізувати

## 1. Загальний стан проєкту

Перевір:

* структуру файлів;
* основний PowerShell-скрипт;
* README;
* CHANGELOG;
* LICENSE;
* VERSION;
* RELEASE.md;
* AUDIT.md;
* PROMPT.md;
* GEMINI.md;
* `.claude`;
* `.github/workflows`;
* `New-ReleaseArchive.ps1`;
* release ZIP;
* checksums;
* тести.

Дай оцінку:

* код;
* документація;
* CI;
* release hygiene;
* готовність до публічного релізу.

---

# Обов’язково перевір попередньо знайдені проблеми

## 1. Outer ZIP vs real release ZIP

У попередньому аналізі було знайдено, що outer archive, тобто архів робочої папки, містив:

```text
.git/
.claude/settings.local.json
```

Але всередині був окремий чистий release ZIP:

```text
Win11-25H2-CalmMode-v2.2.zip
Win11-25H2-CalmMode-v2.2.zip.sha256
checksums.txt
```

Перевір:

* чи досі outer ZIP містить `.git/`;
* чи досі outer ZIP містить `.claude/settings.local.json`;
* чи є всередині окремий release ZIP;
* чи саме release ZIP чистий;
* чи не треба публікувати тільки release ZIP, а не весь outer archive;
* чи немає в release ZIP локальних файлів, `.git`, `.claude`, audit reports, logs, `.reg`, cache/temp.

Очікуваний нормальний release ZIP має містити тільки щось типу:

```text
CHANGELOG_EN.md
CHANGELOG_UA.md
LICENSE
README.md
VERSION
Win11-25H2-CalmMode.ps1
Win11-25H2-CalmMode.Tests.ps1
```

---

## 2. Git state / dirty working tree

У попередньому аналізі було знайдено, що git state був неготовий до релізу:

```text
branch is ahead of origin/main
changes not staged for commit
modified files
```

Перевір:

```powershell
git status
git log --oneline -5
git tag
```

Дай відповідь:

* чи clean working tree;
* чи є uncommitted changes;
* чи є untracked files;
* чи branch ahead/behind origin;
* чи існує тег версії;
* чи тег відповідає фактичному ZIP;
* чи `VERSION` відповідає назві release ZIP;
* чи не зроблений релізний ZIP із незакомічених змін.

Для нормального релізу має бути:

```text
nothing to commit, working tree clean
```

Якщо `v2.2` уже публікувався, не радь переписувати тег. Краще запропонуй підняти версію до `v2.3`.

---

## 3. SHA256 / checksums

У попередньому аналізі SHA256 для release ZIP збігався.

Перевір ще раз:

* чи `.sha256` відповідає реальному ZIP;
* чи `checksums.txt` валідний;
* чи `checksums.txt` не застарів;
* чи hash самого ZIP створений окремим файлом поруч із ZIP;
* чи не намагається скрипт записати hash ZIP всередину ZIP після створення.

Очікувано мають бути:

```text
Win11-25H2-CalmMode-v2.2.zip
Win11-25H2-CalmMode-v2.2.zip.sha256
checksums.txt
```

---

## 4. New-ReleaseArchive.ps1

Перевір release script:

```text
New-ReleaseArchive.ps1
```

Особливо:

* чи він не копіює всі `*.md` без розбору;
* чи він не затягує старі audit reports;
* чи він не затягує `.git`;
* чи він не затягує `.claude/settings.local.json`;
* чи він не затягує вкладені ZIP;
* чи версія береться з `VERSION`;
* чи назва ZIP правильна;
* чи `.sha256` створюється поруч із ZIP;
* чи `checksums.txt` валідний;
* чи build folder чиститься після створення релізу.

---

## 5. AUDIT.md

У попередньому аналізі `AUDIT.md` був порожній.

Перевір:

* чи `AUDIT.md` досі 0 байт;
* чи його треба заповнити;
* чи його краще прибрати з репозиторію/release.

Якщо він порожній, запропонуй такий мінімальний зміст:

```markdown
# Safety Audit

- No remote code download.
- No encoded payloads.
- No Defender/Firewall/UAC disable.
- Apply requires Administrator.
- Appx cleanup is opt-in.
- Target release pinning is opt-in.
- Manual Windows Update mode is opt-in.
- Rollback limitations documented.
```

---

## 6. README: Target Release Version

У попередньому аналізі README трохи неточно описував параметр:

```text
-TargetReleaseVersionInfo
```

Перевір, чи README ясно пояснює, що Target Release Version pinning **вимкнений за замовчуванням** і використовується тільки якщо:

```powershell
$EnableTargetReleaseVersionPin = $true
```

Правильне формулювання приблизно таке:

```text
Версія Windows для Target Release Version pinning. Використовується тільки якщо `$EnableTargetReleaseVersionPin = $true`.
```

Також перевір, чи README попереджає, що pinning на EOL-релізі може з часом блокувати feature updates.

---

## 7. README: NoAppCleanup

У попередньому аналізі була потенційна плутанина з прикладом:

```powershell
.\Win11-25H2-CalmMode.ps1 -Mode Apply -NoAppCleanup
```

Бо Appx cleanup уже disabled by default.

Перевір, чи README пояснює:

* Appx cleanup вимкнений за замовчуванням;
* `-NoAppCleanup` — це додатковий запобіжник;
* Appx cleanup спрацює тільки якщо відповідні toggles вручну ввімкнені;
* rollback registry не повертає видалені Appx/provisioned packages.

---

## 8. Безпечні дефолти

Перевір у коді, що ці значення досі `$false`:

```powershell
$EnableManualWindowsUpdateMode = $false
$EnableTargetReleaseVersionPin = $false
$EnableDeveloperMode = $false

$RemoveCopilotApp = $false
$RemoveTeamsPersonal = $false
$RemoveXboxApps = $false
$RemoveOneDrive = $false
```

Якщо щось із цього стало `$true`, поясни ризик.

---

## 9. WindowsAI / Recall / Paint AI metadata

Перевір, що виправлені metadata для WindowsAI policies:

* `AllowRecallEnablement` має правильний `MinUBR`;
* `DisableAIDataAnalysis` має правильний `MinUBR`;
* Paint AI policies мають правильний `MinUBR`;
* `AllowRecallExport`, `DisableClickToDo`, `DisableSettingsAgent` не позначені занадто впевнено як стабільні, якщо вони Insider/preview/build-dependent;
* використовується `RequiresVerification`, `BestEffort`, `UnsupportedBuild`, `MaybeIgnoredOnEdition`, якщо треба.

Особливо перевір:

```text
AllowRecallEnablement
DisableAIDataAnalysis
AllowRecallExport
DisableClickToDo
DisableSettingsAgent
DisableCocreator
DisableGenerativeFill
DisableImageCreator
```

Не вигадуй Microsoft policies. Якщо не впевнений — познач як `RequiresVerification`.

---

## 10. PowerShell safety scan

Перевір головний `.ps1` на небезпечні патерни:

```text
DownloadString
Invoke-WebRequest
Start-BitsTransfer
FromBase64String
EncodedCommand
Invoke-Expression
Set-MpPreference
DisableRealtimeMonitoring
DisableAntiSpyware
mpssvc
wuauserv
UsoSvc
bits
hosts
ExecutionPolicy Bypass
```

Поясни, чи є реальний ризик, чи це false positive.

Особливо важливо: проєкт не має:

* вимикати Defender;
* вимикати Firewall;
* вимикати Windows Update service;
* ламати Store;
* ламати WebView2;
* блокувати Microsoft domains;
* виконувати remote scripts.

---

## 11. Audit / Apply / Verify / Rollback

Перевір:

* `Audit` не змінює систему;
* `Verify` не змінює систему;
* `Apply` вимагає admin;
* backup створюється перед змінами;
* rollback файл створюється;
* restore point створюється або чесно показується warning;
* rollback documentation не обіцяє більше, ніж реально може;
* `-WhatIf` / `-Confirm` працюють;
* повторний запуск не має ламати систему.

---

## 12. CI / tests

Перевір:

```text
.github/workflows/powershell-check.yml
.github/workflows/release.yml
Win11-25H2-CalmMode.Tests.ps1
PSScriptAnalyzerSettings.psd1
```

Перевір:

* чи syntax check працюватиме;
* чи dry-run Audit запускається через правильний shell;
* чи PSScriptAnalyzer не падає на `Write-Host`, якщо це дозволено через settings;
* чи Pester tests не змінюють систему;
* чи release workflow створює правильний ZIP;
* чи release workflow завантажує ZIP, `.sha256`, `checksums.txt`.

---

# Формат відповіді

Відповідай так:

## 1. Загальна оцінка

Оціни від 1 до 10:

* код;
* документація;
* CI;
* release hygiene;
* готовність до релізу.

## 2. Короткий висновок

Скажи прямо:

* готовий до релізу;
* майже готовий;
* тільки beta/preview;
* не готовий.

## 3. Що вже добре

Список сильних сторін.

## 4. Перевірка попередніх проблем

Зроби таблицю:

```markdown
| Проблема | Статус | Коментар |
|---|---|---|
```

Обов’язково включи:

* outer ZIP містить `.git`;
* outer ZIP містить `.claude/settings.local.json`;
* release ZIP чистий;
* SHA256 збігається;
* git working tree clean/dirty;
* AUDIT.md порожній/заповнений;
* README TargetReleaseVersionInfo;
* README NoAppCleanup;
* WindowsAI MinUBR;
* release script;
* CI.

## 5. Critical blockers

Тільки те, що реально блокує публічний реліз.

Для кожного пункту:

* проблема;
* чому це ризик;
* як виправити;
* як перевірити.

## 6. High priority issues

Серйозні проблеми перед релізом.

## 7. Medium priority issues

Корисні покращення.

## 8. Low priority / polish

Косметика.

## 9. Конкретний план виправлень

Покроково:

1. Що виправити першим.
2. Що другим.
3. Що третім.
4. Що можна залишити на потім.

## 10. Pre-release checklist

Дай checkbox checklist:

```markdown
- [ ] ...
```

## 11. Safe release procedure

Напиши безпечну процедуру:

```powershell
git status
git add .
git commit -m "Finalize v2.2 release"
git tag v2.2
git push
git push --tags
.\New-ReleaseArchive.ps1
```

Але якщо `v2.2` уже був опублікований, запропонуй краще:

```powershell
# bump VERSION to 2.3
git add .
git commit -m "Release v2.3"
git tag v2.3
git push
git push --tags
.\New-ReleaseArchive.ps1
```

## 12. Фінальний висновок

Скажи чесно, чи можна зараз випускати в маси, чи ще треба доробити.
