# AUDIT — Win11 25H2 CalmMode v2.6

Стан на 2026-06-20. Внутрішній звіт про готовність до релізу (не входить у release-архів).

## Результат гейтів

| Перевірка | Результат |
|---|---|
| Parse (рушій + GUI + Sign) | OK |
| PSScriptAnalyzer (Error,Warning) | CLEAN |
| Pester | 44 passed / 0 failed |
| Audit dry-run (`-Mode Audit`) | EXIT=0, звіти HTML/CSV/JSON генеруються |
| Forbidden patterns | відсутні |
| `VERSION` | 2.6 |

## Що нового у v2.6 (Фази 5B + 5C)

- **`-Skip` / `-Only`** — швидкий CLI-вибір блоків без конфіга; валідація за `$script:BlockToggleMap`,
  конфлікт/невідомий ключ → exit 1; застосовуються після `-ConfigPath`.
- **`-ThenVerify`** — після `Apply` одразу прогнати `Verify` і дописати результати в той самий звіт.
  GUI передає `-ThenVerify` при Apply.
- **`-RestoreFrom <тека\|.reg>`** — відкат registry-змін через `reg import`; потребує admin,
  `-WhatIf`/`-Confirm`; повертає **лише реєстр**, не Appx. GUI — кнопка **Undo last Apply**.
- **`-EnableSystemProtection`** — opt-in: `Enable-ComputerRestore` перед restore point (Apply-only, off).
- **`Sign-CalmMode.ps1`** — helper Authenticode-підпису **вашим** сертифікатом (репозиторій сертифіката
  не містить; не входить у release-архів; SHA256 лишається основним механізмом цілісності).
- **Тести (44):** `-Skip`/`-Only` (вимкнення, only, конфлікт, невідомий ключ) + `-RestoreFrom`
  error-шляхи (неіснуючий шлях, тека без `.reg` — без реального імпорту).

> Попередні версії (v2.5 підсумок/pending-reboot/HTML; v2.4 GUI-результат у вікні/Save-Load/HiDPI;
> v2.3 GUI + `-ConfigPath`/`-ExportCatalog`) — у `CHANGELOG_UA/EN` і git-історії.

## Перевірено вживу

- Audit на реальній системі (Build 26200.8653, Pro): `Total checks: 112`, `would change on Apply: 59`,
  `Pending reboot: None`; HTML містить `Needs attention (60)` + усі секції в правильному порядку.
  **Жодних змін системи.**
- GUI `-SelfTest`: `blockNodes=19 tweakNodes=110`, round-trip конфіга OK.
- Round-trip конфігу через рушій: вимкнений блок → 0 результатів; вимкнений твік → `Skipped`.

## Відомі обмеження / не підтверджено

- **Apply-шлях не ганявся вживу** (системна зміна): `Apply`, реальний `-RestoreFrom` (`reg import`),
  `-EnableSystemProtection`, GUI «Undo last Apply» перевірені лише **статично + error-шляхи**.
  Рекомендований повний прогін у чистій VM: `Audit` (без/з адміном) → `Apply` → reboot → `Verify`
  → `-RestoreFrom` → повторний `Verify`. (Це пункт 6A нового ROADMAP.)
- **`Sign-CalmMode.ps1`** перевірено лише на parse/валідацію без сертифіката — фактичний підпис
  потребує реального code-signing сертифіката (не виконано).
- Частина policy-твіків **build-/edition-dependent**: на Home/Pro Windows може ігнорувати значення.
  Це чесно позначається статусами (`RequiresVerification`, `MaybeIgnoredOnEdition`,
  `DeprecatedOrLegacy`) у звіті — не «гарантовано вимикає».
- Registry rollback (`rollback.reg`) **не повертає** видалені Appx-пакети — задокументовано в README.

## Гігієна релізу

- `.gitignore` ховає звіти, `*.log`, `*.reg`, ZIP, `*.sha256`, `checksums.txt`, `.vs`,
  `.claude/settings.local.json`.
- `New-ReleaseArchive.ps1` пакує лише: README, CHANGELOG ×2, LICENSE, VERSION, рушій,
  GUI `.ps1` + `.cmd`, Tests; рахує SHA256 через .NET; пише `.sha256` + `checksums.txt` (LF, UTF-8 no-BOM).
