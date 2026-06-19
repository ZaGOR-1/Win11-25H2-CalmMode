# AUDIT - Win11 25H2 CalmMode

**Дата аудиту:** 2026-06-19  
**Версія у `VERSION`:** 2.2  
**Поточний git describe:** `v2.2-1-g6184b9f-dirty`  
**Тип перевірки:** read-only security / release engineering review.  

`Apply` не запускався. Registry, Appx-пакети, Windows services, Defender, Firewall, Windows Update service і системні налаштування не змінювалися. Виконувалися тільки безпечні перевірки: читання файлів, `git status/log/tag`, перегляд ZIP-вмісту, SHA256, PowerShell parser check, PSScriptAnalyzer, grep/search. Pester був запущений як тестова перевірка, але не дійшов до assertions через sandbox/registry-access issue Pester 4.

---

## 1. Загальна оцінка

| Напрям | Оцінка | Коментар |
|---|---:|---|
| Код | 8/10 | Архітектура обережна: `Audit`/`Verify` read-only за логікою, `Apply` gated admin, registry settings мають metadata, Appx cleanup opt-in. Мінус: PSScriptAnalyzer warnings і кілька empty catch. |
| Документація | 8/10 | README чесно описує opt-in Target Release Version, Appx cleanup, rollback limitations, edition/build limitations. Є неточність у короткому описі `-TargetReleaseVersionInfo`. |
| CI | 6/10 | Workflow хороший за задумом, але поточний код не проходить локальний PSScriptAnalyzer при конфігурації "fail on warnings". Pester локально не підтверджений у sandbox. |
| Release hygiene | 7/10 | Release ZIP чистий і checksums валідні, але робоче дерево dirty, ZIP не відповідає поточним файлам, tag `v2.2` не на поточному HEAD. |
| Готовність до релізу | 5/10 | Для beta/preview майже ок, для публічного release треба закрити blockers і перезібрати артефакти. |

---

## 2. Короткий висновок

**Зараз не готовий до публічного релізу.**  

Проєкт технічно сильний і безпечний за напрямком, але release state неконсистентний: є dirty working tree, тег `v2.2` уже існує і вказує не на поточний HEAD, поточний ZIP зібраний зі старіших файлів, а CI, ймовірно, впаде на PSScriptAnalyzer warnings.

Реалістичний статус: **beta/preview або pre-release**, не "масовий" stable release.

---

## 3. Що вже добре

- Дефолтний режим безпечний: `-Mode Audit`.
- `Apply` вимагає Administrator.
- Registry-зміни централізовані через `Add-RegSetting`, з `Category`, `Status`, `Confidence`, `Support`, `MinBuild`, `MinUBR`.
- `Audit` і `Verify` у registry path logic не пишуть значення, а тільки читають і звітують.
- `SupportsShouldProcess` додано на рівні скрипта; registry write, restore point, Appx cleanup, OneDrive uninstall, gpupdate/Explorer refresh проходять через `ShouldProcess`.
- Appx cleanup disabled by default; Copilot, Teams, Xbox, OneDrive removal toggles зараз `$false`.
- Release ZIP чистий: без `.git`, `.claude`, logs, reports, `.reg`, cache/temp, nested ZIP.
- SHA256 для ZIP збігається з `.sha256`; `checksums.txt` збігається з файлами всередині ZIP.
- README чесно попереджає про rollback limitations: `.reg` не повертає Appx/provisioned packages.
- Немає знайдених небезпечних remote execution патернів у головному `.ps1`.

---

## 4. Перевірка попередніх проблем

| Проблема | Статус | Коментар |
|---|---|---|
| Outer ZIP містить `.git` | Не перевірено як ZIP / ризик є | У workspace немає окремого outer archive для перевірки. Але робоча папка містить `.git/`; якщо публікувати архів усієї папки, `.git` потрапить туди. Публікувати треба тільки release ZIP. |
| Outer ZIP містить `.claude/settings.local.json` | Не перевірено як ZIP / ризик є | У workspace файл `.claude/settings.local.json` існує. Він не в release ZIP і є у `.gitignore`, але outer archive всієї папки може його включити. |
| Є окремий release ZIP | OK | Є `Win11-25H2-CalmMode-v2.2.zip`. |
| Release ZIP чистий | OK | ZIP містить тільки `CHANGELOG_EN.md`, `CHANGELOG_UA.md`, `LICENSE`, `README.md`, `VERSION`, `Win11-25H2-CalmMode.ps1`, `Win11-25H2-CalmMode.Tests.ps1`. |
| SHA256 збігається | OK | Реальний hash ZIP: `C4BD8D44D96DD41BFC2419541192D398AF26B78F7E9A8B6BE312E96A3C333A33`; збігається з `.sha256` і `checksums.txt`. |
| `checksums.txt` валідний | OK для ZIP | Усі file hashes у `checksums.txt` відповідають ZIP entries. Але поточні робочі `Win11-25H2-CalmMode.ps1` і tests вже мають інші hashes. |
| Git working tree clean/dirty | BLOCKER | Dirty: `AUDIT.md`, `Win11-25H2-CalmMode.ps1`, `Win11-25H2-CalmMode.Tests.ps1`; untracked: `AGENTS.md`. |
| Branch ahead/behind origin | OK | `origin/main...HEAD` = `0 0`, тобто не ahead/behind. |
| Тег версії існує | Warning | `v2.2` існує, але tag вказує на `50b58c6`, а поточний HEAD `6184b9f` плюс dirty changes. |
| `VERSION` відповідає ZIP | OK | `VERSION` = `2.2`, ZIP name = `Win11-25H2-CalmMode-v2.2.zip`. |
| ZIP зроблений із незакомічених змін | BLOCKER / stale artifact | Поточні `.ps1` і `.Tests.ps1` відрізняються від ZIP: hashes і sizes не збігаються. ZIP не відображає поточний working tree. |
| `AUDIT.md` порожній/заповнений | Виправлено цим файлом | На старті робочий `AUDIT.md` був 0 байт, хоча в git HEAD був попередній audit. Цей аудит заповнює файл заново. |
| README `TargetReleaseVersionInfo` | Mostly OK | README чітко каже, що pinning opt-in через `$EnableTargetReleaseVersionPin = $false`, і попереджає про EOL. Але короткий рядок параметра все ще звучить так, ніби скрипт завжди pin-ить. |
| README `NoAppCleanup` | OK | README каже, що Appx cleanup вимкнений за замовчуванням, toggles треба вмикати вручну, `-NoAppCleanup` є додатковим запобіжником, rollback Appx не повертає. |
| Безпечні дефолти | OK | `$EnableManualWindowsUpdateMode`, `$EnableTargetReleaseVersionPin`, `$EnableDeveloperMode`, `$RemoveCopilotApp`, `$RemoveTeamsPersonal`, `$RemoveXboxApps`, `$RemoveOneDrive` усі `$false`. |
| WindowsAI MinUBR | Mostly OK | `AllowRecallEnablement` і `DisableAIDataAnalysis` мають `MinBuild 26100`, `MinUBR 3915`. Paint AI policies мають `MinUBR 3360`. Preview/build-dependent policies позначені `RequiresVerification`. |
| Release script | OK | `New-ReleaseArchive.ps1` використовує whitelist 7 файлів, бере version з `VERSION`, генерує ZIP, `.sha256`, `checksums.txt`, чистить build folder. |
| CI | BLOCKER | PSScriptAnalyzer локально повертає warnings, а workflow fail-ить на warnings. Pester локально не підтвердився через Pester 4 TestRegistry access у sandbox. |

---

## 5. Critical blockers

### 1. Dirty working tree перед релізом

**Проблема:** `git status` показує modified `AUDIT.md`, `Win11-25H2-CalmMode.ps1`, `Win11-25H2-CalmMode.Tests.ps1` і untracked `AGENTS.md`.

**Чому це ризик:** неможливо чесно сказати, що release ZIP, tag і repo state відповідають одне одному. Можна випадково опублікувати старий ZIP або втратити незакомічені зміни.

**Як виправити:** вирішити долю всіх змін, закомітити або прибрати з release scope. `AGENTS.md` або додати свідомо, або залишити untracked/ігнорувати.

**Як перевірити:**

```powershell
git status --short --branch
```

Очікувано перед релізом: `nothing to commit, working tree clean`.

### 2. `v2.2` tag не відповідає поточному HEAD

**Проблема:** `git describe` показує `v2.2-1-g6184b9f-dirty`; tag `v2.2` існує і вказує на старіший commit `50b58c6`, а поточний HEAD має ще commit `6184b9f` плюс локальні зміни.

**Чому це ризик:** якщо `v2.2` уже публікувався, переписувати tag погано. Якщо release workflow запускається по tag, він збере саме tagged commit, не поточний dirty state.

**Як виправити:** якщо `v2.2` уже був опублікований, не переписувати tag; bump до `2.3`, оновити changelog, закомітити, створити `v2.3`.

**Як перевірити:**

```powershell
git describe --tags --always --dirty
git log --oneline v2.2..HEAD
```

### 3. CI зараз не зелений через PSScriptAnalyzer warnings

**Проблема:** `Invoke-ScriptAnalyzer -Severity Error,Warning` повертає warnings: empty catch blocks, singular noun warnings, WMI fallback warning, `PSReviewUnusedParameter`, `PSShouldProcess`.

**Чому це ризик:** `.github/workflows/powershell-check.yml` завершує job з `exit 1`, якщо є будь-які warnings/errors. Release не має йти з червоним quality gate.

**Як виправити:** або виправити warnings, або додати точкові suppressions у `PSScriptAnalyzerSettings.psd1` для свідомих false positives. Найкраще: виправити empty catch / ShouldProcess, а false positives (`PSReviewUnusedParameter` для script params used inside functions, naming conventions) suppress з поясненням.

**Як перевірити:**

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Settings .\PSScriptAnalyzerSettings.psd1 -Severity Error,Warning
```

Очікувано: порожній результат.

### 4. Поточний release ZIP stale щодо working tree

**Проблема:** ZIP hashes відповідають ZIP, але поточні `Win11-25H2-CalmMode.ps1` і `Win11-25H2-CalmMode.Tests.ps1` мають інші hashes і sizes.

**Чому це ризик:** користувач отримає не той код, який зараз перевіряється. Це особливо погано для security/release audit.

**Як виправити:** після clean commit і зеленого CI перезібрати ZIP тільки через `.\New-ReleaseArchive.ps1`.

**Як перевірити:** переглянути ZIP contents і перерахувати SHA256; `checksums.txt` має збігатися з новим ZIP.

---

## 6. High priority issues

### 1. Pester не підтверджений локально

Pester 4.10.1 доступний, але запуск завершився помилкою до assertions:

```text
ParameterBindingValidationException: Cannot bind argument to parameter 'Root' because it is null.
Requested registry access is not allowed.
```

Це схоже на обмеження sandbox/registry access Pester 4 TestRegistry, а не на зміну системи скриптом. Але для release треба мати зелений Pester у нормальному Windows runner.

**Рекомендація:** перевірити у GitHub Actions або локально у звичайному Windows PowerShell 5.1 без sandbox. Якщо падає і там, переписати tests так, щоб вони не активували Pester TestRegistry або перейти на простий custom assertion runner для pure functions.

### 2. README short description для `-TargetReleaseVersionInfo`

У таблиці параметрів зараз:

```text
Версія Windows, на якій скрипт закріплює систему через Target Release Version
```

Нижче README правильно пояснює opt-in, але цей короткий рядок може збити з пантелику.

**Краще:**

```text
Версія Windows для Target Release Version pinning. Використовується тільки якщо `$EnableTargetReleaseVersionPin = $true`.
```

---

## 7. Medium priority issues

- Empty `catch {}` у кількох місцях краще замінити на короткий `Add-Result`/commented fallback або targeted suppression. Для системного скрипта silent fallback може бути нормальним, але audit trail важливий.
- Inner functions, які викликають `$PSCmdlet.ShouldProcess`, тригерять `PSShouldProcess`. Можна додати `[CmdletBinding(SupportsShouldProcess=$true)]` де доречно або suppress з поясненням, що вони використовують script-level `$PSCmdlet`.
- `PSReviewUnusedParameter` виглядає як analyzer false positive через використання script params всередині функцій. Потрібен suppression, інакше CI завжди падатиме.
- `Get-WmiObject` використовується тільки як fallback після `Get-CimInstance`; це прийнятно для Windows PowerShell 5.1 compatibility, але треба suppress у analyzer settings.
- `.claude/*`, `PROMPT.md`, `GEMINI.md`, `AUDIT.md` tracked у repo, але не в release ZIP. Це не release blocker, проте варто свідомо вирішити, чи ці agent-specific файли мають бути частиною public repo.

---

## 8. Low priority / polish

- `RemoveXboxApps` і `RemoveOneDrive` у README table не мають такого ж явного `**Opt-in.**`, як Copilot/Teams, хоча defaults `$false`. Варто уніфікувати wording.
- `RELEASE.md` хороший, але можна додати окремий пункт: не переписувати існуючий tag, якщо версія вже була опублікована.
- У `.gitignore` release artifacts і checksums ігноруються правильно. Можна додати `AGENTS.md`, якщо це локальний agent-файл і не має бути tracked.
- `README` CI section англійською в українському README; не критично, але можна перекласти або свідомо залишити.

---

## 9. Конкретний план виправлень

1. Закрити CI blocker: виправити або suppress PSScriptAnalyzer warnings так, щоб локальна команда з workflow повертала порожній результат.
2. Вирішити Pester: підтвердити зелений запуск у GitHub Actions/звичайному Windows PowerShell або змінити tests, щоб вони не падали через TestRegistry.
3. Оновити README wording для `-TargetReleaseVersionInfo` і opt-in wording для Xbox/OneDrive Appx cleanup.
4. Вирішити git state: закомітити `AUDIT.md`, зміни в `.ps1`, tests, README; визначити долю `AGENTS.md`.
5. Якщо `v2.2` уже публікувався, bump `VERSION` до `2.3`, оновити changelog dates/notes, створити новий tag `v2.3`.
6. Перезібрати release ZIP через `.\New-ReleaseArchive.ps1`.
7. Перевірити ZIP contents, `.sha256`, `checksums.txt`, і тільки тоді публікувати.

---

## 10. Pre-release checklist

- [ ] `Invoke-ScriptAnalyzer -Path . -Recurse -Settings .\PSScriptAnalyzerSettings.psd1 -Severity Error,Warning` повертає порожній результат.
- [ ] Pester tests проходять у нормальному Windows runner.
- [ ] PowerShell parser check проходить для всіх `.ps1`.
- [ ] `README.md` уточнює `-TargetReleaseVersionInfo`: використовується тільки якщо `$EnableTargetReleaseVersionPin = $true`.
- [ ] Appx cleanup docs однаково позначають Copilot/Teams/Xbox/OneDrive як opt-in.
- [ ] `git status` clean.
- [ ] `VERSION` відповідає changelog і tag.
- [ ] Якщо `v2.2` уже опублікований, зроблено bump до `2.3`, а не переписаний tag.
- [ ] Release ZIP перезібраний через `.\New-ReleaseArchive.ps1`.
- [ ] ZIP містить тільки дозволені файли: README, changelogs, LICENSE, VERSION, main `.ps1`, tests.
- [ ] ZIP не містить `.git/`, `.claude/`, `.Codex/`, `AUDIT.md`, `PROMPT.md`, `GEMINI.md`, reports, logs, `.reg`, cache/temp, nested ZIP.
- [ ] `.sha256` відповідає реальному ZIP.
- [ ] `checksums.txt` відповідає файлам у ZIP і самому ZIP.
- [ ] GitHub Actions green на release commit/tag.

---

## 11. Safe release procedure

Оскільки tag `v2.2` уже існує і не відповідає поточному HEAD, безпечніший шлях - **не переписувати `v2.2`**, а підняти версію.

```powershell
# 1. Після виправлень оновити VERSION до 2.3 і changelog до v2.3
git status

# 2. Закомітити тільки свідомі зміни
git add README.md CHANGELOG_UA.md CHANGELOG_EN.md VERSION AUDIT.md Win11-25H2-CalmMode.ps1 Win11-25H2-CalmMode.Tests.ps1 PSScriptAnalyzerSettings.psd1
git commit -m "Release v2.3"

# 3. Дочекатися чистого дерева і зеленого CI
git status
git push

# 4. Створити новий tag
git tag v2.3
git push --tags

# 5. Зібрати локальний release archive тільки canonical script-ом
.\New-ReleaseArchive.ps1
```

Якщо буде доведено, що `v2.2` ніколи не публікувався, можна обговорити retag, але для open-source release hygiene краще все одно йти через `v2.3`.

---

## 12. Фінальний висновок

**У маси зараз випускати не варто.**  

Сам скрипт рухається в правильному безпечному напрямку: не агресивний debloater, дефолти обережні, Appx cleanup opt-in, небезпечних remote-code/Defender/Firewall/WU-service патернів у головному `.ps1` не знайдено. Але релізний стан неготовий: dirty tree, stale ZIP щодо поточних файлів, tag mismatch і CI/PSScriptAnalyzer blocker.

Після закриття цих пунктів проєкт виглядатиме придатним для публічного release, бажано як `v2.3`, якщо `v2.2` уже десь світився.
