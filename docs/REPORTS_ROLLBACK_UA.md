# Звіти, Статуси І Відкат

[← README](../README.md) · [English](REPORTS_ROLLBACK_EN.md)

## Звіти

Після запуску створюється папка:

```text
Win11-25H2-CalmMode-v<version>-<Mode>-YYYY-MM-DD_HH-MM-SS
```

У ній:

```text
Win11-25H2-CalmMode-v<version>-report.html
Win11-25H2-CalmMode-v<version>-results.csv
Win11-25H2-CalmMode-v<version>-results.json
Win11-25H2-CalmMode-v<version>.log
rollback.reg                 # тільки Apply
```

HTML-звіт має секцію **Needs attention**, яка враховує `Status`, `Support` і `Confidence`.

## Статуси

| `Status` | Значення |
|---|---|
| `Compliant` | Значення вже правильне в `Audit` |
| `WouldChange` | У `Audit` значення було б змінено |
| `WouldRemove` | У `Audit` пакет був би видалений |
| `AlreadyConfigured` | У `Apply` запис не потрібен |
| `Changed` | У `Apply` значення записане й перевірене |
| `VerifyOK` | У `Verify` значення присутнє |
| `VerifyFail` | У `Verify` значення відсутнє або інше |
| `Skipped` | Пропущено через параметри, конфіг або applicability |
| `Warning` | Некритичне попередження |
| `Error` | Помилка запису або перевірки |

| `Support` / `Confidence` | Значення |
|---|---|
| `UnsupportedBuild` | Не підходить для поточної збірки |
| `MaybeIgnoredOnEdition` | Windows може ігнорувати це на поточній редакції |
| `BestEffort` | Best-effort поведінка залежить від build/package state |
| `RequiresVerification` | Потрібна перевірка після Apply |
| `DeprecatedOrLegacy` | Застарілий або legacy policy |
| `UISetting` | UI-твік, не повноцінна device policy |

## Коди Виходу

| Код | Значення |
|---:|---|
| `0` | Немає критичних помилок; `Verify` пройшов |
| `1` | Помилка параметрів або preflight |
| `2` | `Verify` знайшов `VerifyFail` |

## Rollback

У `Apply` скрипт створює `rollback.reg`. Для відкату:

```powershell
.\Win11-25H2-CalmMode.ps1 -RestoreFrom "C:\Path\To\ReportFolder"
```

Якщо передано теку, у ній має бути саме `rollback.reg`. Довільний `.reg` можна імпортувати лише прямим шляхом:

```powershell
.\Win11-25H2-CalmMode.ps1 -RestoreFrom "C:\Path\To\backup.reg"
```

Відкат повертає **лише registry values**. Він не повертає видалені Appx/provisioned packages.

## Ручна Перевірка

```powershell
Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
gpresult /h "$env:USERPROFILE\Desktop\gpresult.html"
```

`VerifyOK` означає, що registry/policy value присутній. Це не завжди гарантує, що Windows UI на 100% поважає policy, особливо для edition/build-limited пунктів.
