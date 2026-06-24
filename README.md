# Win11 25H2 Calm Mode

<p align="right">
  <a href="README_EN.md"><strong>English</strong></a>
</p>

PowerShell-скрипт для акуратного налаштування Windows 11 25H2 у більш спокійний режим: менше Copilot/AI-функцій, Widgets, реклами, рекомендацій, фонових процесів Edge, автоматичних драйверів через Windows Update і зайвих UI-підказок.

Це **не агресивний debloater**. Скрипт не вимикає Defender, Firewall, Windows Update service, Microsoft Store, WebView2, .NET, сертифікати або критичні системні служби.

> Ідея проста: не ламати Windows, а виставити зрозумілі policy/registry-параметри, зробити backup, показати звіт і залишити шлях відкату.

---

## Швидкий Старт

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
cd "$env:USERPROFILE\Desktop"

# 1. Безпечний аудит: нічого не змінює
.\Win11-25H2-CalmMode.ps1 -Mode Audit

# 2. Застосування: потрібен запуск від імені адміністратора
.\Win11-25H2-CalmMode.ps1 -Mode Apply

# 3. Перевірка після перезавантаження
.\Win11-25H2-CalmMode.ps1 -Mode Verify
```

За замовчуванням режим безпечний: запуск без параметрів дорівнює `-Mode Audit`.

---

## GUI

Найпростіше запустити графічний інтерфейс подвійним кліком:

```text
Win11-25H2-CalmMode-GUI.cmd
```

GUI має двопанельний список **категорії → твіки**, badges для `Official` / `UISetting` / `BestEffort` / `Deprecated`, панель деталей вибраного твіка, кнопку **EN / UA**, безпечний **Audit**, вкладки результатів **Summary / Details / Raw log**, підтверджений **Apply** через UAC після успішного Audit, збереження/завантаження JSON-конфігу і **Undo last Apply** через `rollback.reg`.

---

## Основні Гарантії

- `Audit` і `Verify` read-only.
- `Apply` вимагає Administrator.
- Перед змінами створюються registry backup і `rollback.reg`.
- Restore point створюється, якщо System Protection увімкнений.
- Appx cleanup вимкнений за замовчуванням і працює тільки opt-in.
- Звіти створюються у `HTML`, `CSV`, `JSON`.
- Build/edition limitations чесно позначаються у звіті.

---

## Документація

| Тема | Українською | English |
|---|---|---|
| Використання, параметри, GUI | [docs/USAGE_UA.md](docs/USAGE_UA.md) | [docs/USAGE_EN.md](docs/USAGE_EN.md) |
| Звіти, статуси, rollback, перевірка | [docs/REPORTS_ROLLBACK_UA.md](docs/REPORTS_ROLLBACK_UA.md) | [docs/REPORTS_ROLLBACK_EN.md](docs/REPORTS_ROLLBACK_EN.md) |
| Політики, registry areas, Appx cleanup | [docs/POLICIES_UA.md](docs/POLICIES_UA.md) | [docs/POLICIES_EN.md](docs/POLICIES_EN.md) |
| Release checklist | [docs/RELEASE.md](docs/RELEASE.md) | - |
| Roadmap | [docs/ROADMAP.md](docs/ROADMAP.md) | - |

Також:

- [CHANGELOG_UA.md](CHANGELOG_UA.md)
- [CHANGELOG_EN.md](CHANGELOG_EN.md)
- [SECURITY.md](SECURITY.md)

---

## Перевірка Цілісності

Релізний архів має SHA256:

```powershell
Get-FileHash .\Win11-25H2-CalmMode-v2.11.zip -Algorithm SHA256
```

Файли `checksums.txt` і `<zip>.sha256` створюються скриптом:

```powershell
.\New-ReleaseArchive.ps1
```

---

## Важливе Попередження

Це неофіційний community/scripted конфігуратор. Перед запуском на основній системі краще спочатку зробити `Audit`, переглянути звіт і протестувати у VM або на тестовій інсталяції.
