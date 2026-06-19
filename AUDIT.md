# AUDIT — Win11 25H2 CalmMode v2.3

Стан на 2026-06-19. Внутрішній звіт про готовність до релізу (не входить у release-архів).

## Результат гейтів

| Перевірка | Результат |
|---|---|
| Parse (рушій + GUI) | OK |
| PSScriptAnalyzer (Error,Warning) | CLEAN |
| Pester | 26 passed / 0 failed |
| Audit dry-run (`-Mode Audit`) | EXIT=0, звіти HTML/CSV/JSON генеруються |
| Forbidden patterns | відсутні |
| `VERSION` | 2.3 |

## Що нового у v2.3

- **GUI** `Win11-25H2-CalmMode-GUI.ps1` (WinForms, без зовнішніх залежностей): дерево блоків з
  розкриттям у твіки, окремі кнопки **Run Audit** (read-only) і **Apply** (підтвердження + адмін).
- **Лаунчер** `Win11-25H2-CalmMode-GUI.cmd` (звичайний текст, не `.exe`, без base64 — заради
  прозорості й уникнення хибних спрацювань AV/SmartScreen).
- **`-ConfigPath <json>`** — вмикання/вимикання блоків і окремих твіків без редагування `.ps1`.
- **`-ExportCatalog`** — read-only JSON-каталог блоків і твіків (контракт для GUI; рушій лишається
  єдиним джерелом істини).
- Стабільний `Key` (`"$Path\$Name"`) і тег `BlockKey` для кожного твіка.
- Чистіший transcript: відсутні registry-значення більше не дають `TerminatingError`, а Appx-аудит
  без адміна не засмічує лог `Access is denied`/`requires elevation`.

## Перевірено вживу

- Audit через GUI на реальній системі (Build 26200.8653, Pro): запуск рушія, генерація звітів,
  **жодних змін системи**, лог чистий.
- Round-trip конфігу: вимкнений блок → 0 результатів по блоку; вимкнений твік → `Skipped`.

## Відомі обмеження / не підтверджено

- **Apply через GUI** не запускався в бойовому режимі в цій ітерації (системна зміна). Логіку
  перевірено статично + round-trip конфігу. Рекомендований повний прогін у VM:
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
