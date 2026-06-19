# AUDIT — Win11 25H2 CalmMode v2.5

Стан на 2026-06-20. Внутрішній звіт про готовність до релізу (не входить у release-архів).

## Результат гейтів

| Перевірка | Результат |
|---|---|
| Parse (рушій + GUI) | OK |
| PSScriptAnalyzer (Error,Warning) | CLEAN |
| Pester | 38 passed / 0 failed |
| Audit dry-run (`-Mode Audit`) | EXIT=0, звіти HTML/CSV/JSON генеруються |
| Forbidden patterns | відсутні |
| `VERSION` | 2.5 |

## Що нового у v2.5 (Фаза 5A)

- **Підсумок наприкінці прогону.** Блок «Summary»: total + лічильники по статусах (у всіх режимах,
  навіть з `-NoReport`); в Audit — скільки пунктів «would change on Apply» (з урахуванням `-WhatIf`).
  Винесено у `Get-ResultSummary` / `Write-RunSummary`.
- **Виявлення pending reboot** (`Test-PendingReboot`, read-only preflight): CBS `RebootPending`,
  WU `RebootRequired`, `PendingFileRenameOperations` → `Warning`, якщо reboot уже заплановано.
  Нічого не перезавантажує автоматично.
- **Кращий HTML-звіт:** секція «Needs attention» угорі + зведення «By confidence»; порядок —
  Needs attention → Status summary → By confidence → Detailed results.
- **Тести (38, було 36):** додано `Get-ResultSummary` і `Test-PendingReboot`.

> Попередні версії (v2.4 GUI-результат у вікні, Save/Load, HiDPI, `Get-KnownStatuses`;
> v2.3 GUI + `-ConfigPath`/`-ExportCatalog`) — у `CHANGELOG_UA/EN` і git-історії.

## Перевірено вживу

- Audit на реальній системі (Build 26200.8653, Pro): `Total checks: 112`, `would change on Apply: 59`,
  `Pending reboot: None`; HTML містить `Needs attention (60)` + усі секції в правильному порядку.
  **Жодних змін системи.**
- GUI `-SelfTest`: `blockNodes=19 tweakNodes=110`, round-trip конфіга OK.
- Round-trip конфігу через рушій: вимкнений блок → 0 результатів; вимкнений твік → `Skipped`.

## Відомі обмеження / не підтверджено

- **Apply через GUI** не запускався в бойовому режимі в цій ітерації (системна зміна). Логіку
  перевірено статично + усі read-only шляхи. Рекомендований повний прогін у VM:
  `Audit` без адміна → `Audit` від адміна → `Apply` → reboot → `Verify`.
- Частина policy-твіків **build-/edition-dependent**: на Home/Pro Windows може ігнорувати значення.
  Це чесно позначається статусами (`RequiresVerification`, `MaybeIgnoredOnEdition`,
  `DeprecatedOrLegacy`) у звіті — не «гарантовано вимикає».
- Registry rollback (`rollback.reg`) **не повертає** видалені Appx-пакети — задокументовано в README.

## Гігієна релізу

- `.gitignore` ховає звіти, `*.log`, `*.reg`, ZIP, `*.sha256`, `checksums.txt`, `.vs`,
  `.claude/settings.local.json`.
- `New-ReleaseArchive.ps1` пакує лише: README, CHANGELOG ×2, LICENSE, VERSION, рушій,
  GUI `.ps1` + `.cmd`, Tests; рахує SHA256 через .NET; пише `.sha256` + `checksums.txt` (LF, UTF-8 no-BOM).
