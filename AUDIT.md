# AUDIT — Win11 25H2 CalmMode v2.4

Стан на 2026-06-19. Внутрішній звіт про готовність до релізу (не входить у release-архів).

## Результат гейтів

| Перевірка | Результат |
|---|---|
| Parse (рушій + GUI) | OK |
| PSScriptAnalyzer (Error,Warning) | CLEAN |
| Pester | 36 passed / 0 failed |
| Audit dry-run (`-Mode Audit`) | EXIT=0, звіти HTML/CSV/JSON генеруються |
| Forbidden patterns | відсутні |
| `VERSION` | 2.4 |

## Що нового у v2.4

- **GUI: результат прямо у вікні.** Після **Run Audit** і **Apply** GUI читає згенерований JSON-звіт
  і показує його в `DataGridView` («Needs attention» за замовчуванням + перемикач *Show all* +
  зведення по статусах). Audit більше не відкриває окрему консоль.
- **GUI: Save config… / Load config….** Збереження вибору галочок у JSON і завантаження пізніше
  (той самий формат, що й `-ConfigPath`).
- **GUI: базова HiDPI** (`SetProcessDPIAware` + `AutoScaleMode = Dpi`); прибирання temp-конфігів
  після `-Wait`-прогону + чистка залишків на старті.
- **`Get-KnownStatuses`** — єдиний канонічний перелік статусів; `Add-Result` пише у verbose, якщо
  натрапляє на невідомий статус (захист від друкарських помилок). Масову заміну call-site свідомо
  не робили: ті самі літерали означають різне в полях Status/Confidence/Support.
- **Тести (36, було 26):** інтеграційні Pester на `-ExportCatalog`, фільтр `-ConfigPath`
  (вимкнений блок → 0 результатів, вимкнений твік → `Skipped`), «лише відомі статуси», exit 1 на
  битому конфігу, і GUI `-SelfTest` (формування конфіга + round-trip).

## Перевірено вживу

- Audit через GUI на реальній системі (Build 26200.8653, Pro): запуск рушія, генерація звітів,
  результат показано у вікні, **жодних змін системи**, лог чистий.
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
