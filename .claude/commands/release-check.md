# Release check

Підготуй release checklist для Win11 25H2 Calm Mode.

Перевір:
- чи немає `.git/` у релізному архіві;
- чи немає `.claude/settings.local.json` у релізному архіві;
- чи немає `.codex/` або `.Codex/settings.local.json` у релізному архіві;
- чи README відповідає фактичним параметрам скрипта;
- чи CHANGELOG_UA.md і CHANGELOG_EN.md оновлені;
- чи основний скрипт і GUI парсяться у Windows PowerShell 5.1;
- чи GUI проходить `-SelfTest`;
- чи немає небезпечних патернів: Invoke-Expression, remote code execution, encoded payloads;
- чи Appx cleanup описаний чесно;
- чи `Audit` лишається дефолтним режимом;
- чи `Apply` вимагає admin;
- чи є SHA256 для релізу.

Не запускай Apply. Дай конкретні команди для локальної перевірки.
