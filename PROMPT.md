Ти — senior Windows/PowerShell engineer, security reviewer і maintainer open-source інструментів.

Проаналізуй весь мій проєкт повністю. Це Windows 11 tuning / privacy / calm mode інструмент, який має працювати обережно, без агресивного debloat, без вимкнення критичних служб і з можливістю backup/rollback.

Твоє завдання: зробити повний аудит проєкту на баги, ризики, погану архітектуру, небезпечні місця, неточну документацію і можливості покращення.

ВАЖЛИВО:

* Спочатку нічого не змінюй у файлах.
* Не запускай `Apply`, не змінюй систему, не запускай скрипти з правами адміністратора.
* Не видаляй Appx-пакети, не міняй registry, не чіпай Windows services.
* Працюй як reviewer: читай код, README, changelog, CI, конфіги, структуру папок.
* Якщо запускаєш команди, то тільки безпечні: syntax check, lint, grep/search, tree/list files.
* Не пропонуй “агресивний debloat”, вимкнення Defender, Firewall, Windows Update, Store, WebView2, UAC або security-фіч.
* Не вигадуй неіснуючі Microsoft policies. Якщо policy/build support сумнівний — познач це як `BestEffort` або `RequiresVerification`.

Перевір особливо уважно:

1. Безпека

* Чи немає небезпечних дій без підтвердження.
* Чи немає прихованого завантаження коду з інтернету.
* Чи немає encoded/base64 command, eval-подібної логіки, зайвого bypass execution policy.
* Чи не вимикаються критичні security-компоненти Windows.
* Чи достатньо прозоро користувачу пояснюється, що саме зміниться.

2. PowerShell-якість

* Помилки синтаксису.
* Неправильна робота з registry.
* Неправильна обробка `HKLM`, `HKCU`, policy paths.
* Неправильна робота з правами адміністратора.
* Проблеми з `ShouldProcess`, `-WhatIf`, `-Confirm`.
* Проблеми з error handling.
* Проблеми з idempotency: повторний запуск не має ламати систему.
* Проблеми з логами, reports, CSV/JSON/HTML output.
* Місця, де варто додати helper-функції або спростити код.

3. Backup / Rollback

* Чи backup робиться до змін.
* Чи rollback реально відкочує те, що було змінено.
* Чи чесно документація пояснює обмеження rollback.
* Особливо перевір Appx removal: registry rollback не повертає видалені provisioned packages.
* Чи restore point створюється коректно і чи є fallback, якщо він недоступний.

4. Windows 11 / 25H2 / policy correctness

* Чи коректно названі WindowsAI / Recall / Copilot / Widgets / Edge / Update policies.
* Чи є ризик, що деякі registry keys ігноруються в Home/Pro edition.
* Чи є build-dependent policies.
* Чи правильно обробляються unsupported builds.
* Чи треба додати статуси типу `Supported`, `UnsupportedBuild`, `MaybeIgnoredOnEdition`, `BestEffort`.

5. Документація

* Чи README чесний і зрозумілий.
* Чи достатньо попереджень перед Apply.
* Чи зрозуміло, що робить Audit / Apply / Verify / Rollback.
* Чи не обіцяє README більше, ніж реально робить код.
* Чи є нормальна інструкція для запуску.
* Чи є приклади команд.
* Чи є секція “What this tool will NOT do”.
* Чи є секція known limitations.

6. Release hygiene

* Чи не потрапили в архів `.git`, `.claude/settings.local.json`, локальні файли, кеші, тимчасові звіти.
* Чи нормальний `.gitignore`.
* Чи треба додати release checklist.
* Чи треба додати SHA256 hash для release zip.
* Чи варто додати code signing або хоча б інструкцію про перевірку hash.

7. CI / тести

* Чи достатньо GitHub Actions.
* Чи треба додати PSScriptAnalyzer.
* Чи треба додати Pester-тести.
* Які саме функції варто покрити тестами.
* Чи можна додати dry-run тестування без зміни системи.

8. Архітектура

* Чи не занадто великий один `.ps1` файл.
* Чи варто винести policies/config у окремий `.json` або `.psd1`.
* Чи варто розділити core logic, reporting, registry operations, appx operations.
* Чи легко додавати нову policy.
* Чи є дублювання коду.

Формат відповіді:

# Загальна оцінка

Дай оцінку від 1 до 10 і коротко поясни.

# Найкращі сторони проєкту

Список сильних сторін.

# Critical issues

Тільки критичні проблеми, які можуть реально нашкодити системі, безпеці або користувачу.

# High priority issues

Серйозні проблеми, які бажано виправити перед релізом.

# Medium priority improvements

Корисні покращення, але не блокери.

# Low priority / polish

Косметика, стиль, дрібні покращення.

# Документація: що виправити

Конкретно по README / CHANGELOG / LICENSE / comments.

# Код: що виправити

Конкретні файли, функції, місця, логіка.

# Тести і CI

Що саме додати: PSScriptAnalyzer, Pester, syntax checks, release workflow.

# Безпечний план виправлень

Дай покроковий план:

1. Що виправити першим.
2. Що другим.
3. Що можна залишити на потім.

# Готові задачі для GitHub Issues

Створи список issue у форматі:

* Title:
* Priority:
* Description:
* Acceptance criteria:

# Висновок

Скажи чесно, чи готовий проєкт до публічного релізу, чи краще ще допрацювати.
