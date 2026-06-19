# Changelog

All notable changes to this project are documented in this file.

This project uses a simple versioning style: `vMAJOR.MINOR`.

## [v2.3] - 2026-06-19

### Added

- **Graphical interface** `Win11-25H2-CalmMode-GUI.ps1` (Windows Forms, no external dependencies): a checkbox tree of blocks that expand into individual tweaks. A **Run Audit** button (read-only) and a separate **Apply** button (with confirmation and an Administrator requirement). The GUI contains no policy logic of its own — it reads the engine catalog and writes a config.
- **Launcher `Win11-25H2-CalmMode-GUI.cmd`** to open the GUI with a double-click. It is a plain text `.cmd` (not a compiled `.exe`, no base64/hidden code) on purpose — to keep the project transparent and avoid antivirus/SmartScreen false positives.
- `-ConfigPath <json>` engine parameter: enable/disable blocks and disable individual tweaks via a config file, without editing the `.ps1`. Schema: `{ "blocks": { "<BlockKey>": true|false }, "disabledTweaks": ["<Path>\<Name>"] }`.
- `-ExportCatalog` engine parameter: a read-only mode that prints a JSON catalog of all blocks and tweaks (changes nothing, no report folder/transcript). This is the contract the GUI consumes, keeping the engine the single source of truth.
- Every tweak now has a stable key (`"$Path\$Name"`) and a block tag (`BlockKey`) for config selection and GUI grouping.

### Changed

- A tweak disabled via `-ConfigPath` is reported as `Skipped` ("Disabled via -ConfigPath selection.") and is never read or written.

### Fixed

- Cleaner transcript log: `Get-RegValueSafe` now reads the whole key and looks the value up via `PSObject`, so a missing value name no longer raises a terminating error (previously `-Name ... -ErrorAction Stop` produced dozens of `PS>TerminatingError(Get-ItemProperty)` lines in the log even though the catch handled them correctly). Audit results are unchanged.
- Appx audit without administrator no longer floods the log: `Get-AppxPackage -AllUsers` and `Get-AppxProvisionedPackage -Online` (which always require elevation and threw a terminating `Access is denied` / `requires elevation`) are skipped when the script is not running as administrator. The data is identical (empty), the log is clean.

## [v2.2] - 2026-06-18

### Added

- `-WhatIf` / `-Confirm` support: the script now declares `SupportsShouldProcess`, so `Apply` can be previewed without changing the system.
- `-TelemetryLevel` parameter (`0`–`3`) to control the `AllowTelemetry` diagnostic data policy. Default `1` (Required), which is the minimum actually honored on Home/Pro; the script does not force telemetry fully off.
- New report status `RequiresVerification` for policies whose exact name or behavior is not fully confirmed across builds/editions.
- Real `.gitignore` (previously only a `gitignore-snippet.txt` example existed), so local files and generated reports/backups are not committed by accident.
- Local script `New-ReleaseArchive.ps1` to easily package safe release `.zip` archives without dirty files like `.git`.
- Deeper versioning support via `$MinUBR` (Update Build Revision) checking for strict policies like Windows AI (Recall).
- Fully automated CI/CD checks via GitHub Actions: includes `PSScriptAnalyzer`, a forbidden patterns check, and automated Dry-run Audit mode.
- `-ReportPath` parameter — base directory for the report folder (default: Desktop), so the Desktop is not cluttered.
- `-NoReport` parameter — skip the report folder, transcript, and CSV/HTML/JSON files (console output only). Honored only in read-only modes; in `Apply` it is ignored with a warning because the backup and `rollback.reg` require the folder.

### Changed

- Target Release Version pinning is now **opt-in** via the in-script toggle `$EnableTargetReleaseVersionPin` (default: off). Pinning a feature version can block future feature/security servicing once that release reaches end of service.
- Reclassified `DisableSettingsAgent`, `DisableWidgetsBoard`, and `DisableWidgetsOnLockScreen` from `Official` to `RequiresVerification`.
- Corrected and clarified the `AUOptions=2` description. This manual Windows Update policy is now completely **opt-in**. Use `$EnableManualWindowsUpdateMode = $true` to activate it.
- Edge `PromotionalTabsEnabled` policy is marked as `Deprecated` to reflect Microsoft documentation.
- Appx cleanup for Copilot and Teams is now strictly opt-in (`$false` by default).
- **Architectural change:** the main script was renamed from `Win11-25H2-CalmMode-v2.2.ps1` to a stable `Win11-25H2-CalmMode.ps1` without a hardcoded version string.
- The project version is now stored in a dedicated `VERSION` file, which is dynamically read by the script and CI/CD pipelines during release packaging. This makes future updates cleaner and eliminates the need to rename the file.
- Improved Windows AI and Paint AI policy accuracy by adding strict `MinUBR` checks.
- Enhanced release hygiene: the ZIP hash (`.sha256`) is now generated externally alongside the archive instead of being embedded. Release build scripts now strictly exclude audit reports.
- Release tooling hardening: `New-ReleaseArchive.ps1` computes SHA256 via .NET (no `Get-FileHash` dependency), writes `checksums.txt` and `.sha256` as LF + UTF-8 without BOM, and excludes `.gitignore` from the archive. The CI release workflow now calls this same script as the single source of truth, and CI pins Pester `4.10.1` to match the test syntax.

### Fixed

- `MinUBR` gating no longer reports a false `UnsupportedBuild` when the UBR cannot be read: `$script:UBR` is cast to `[int]` and the check only applies when the UBR is known (`> 0`) — fail-open instead of blocking.
- `Test-ValueEquals` compares DWords via `[long]` instead of `[int]`, so a desired value above 2147483647 no longer overflows Int32.
- The script now returns a result-based exit code: `0` = clean, `2` = at least one `Error`/`VerifyFail` (useful for `Verify` in a scheduler/CI).
- The MAIN body is wrapped in `try/finally`, so the transcript log is closed correctly even on an unexpected error mid-run.
- Empty `catch {}` blocks now write the error to the verbose stream instead of swallowing it silently.
- `Format-RegValueLine` encodes DWords via a `[long] -band 0xffffffff` mask, so large unsigned (`0xFFFFFFFF`) and negative (`-1` → `ffffffff`) values in `rollback.reg` no longer overflow Int32.
- Appx cleanup now captures the reason each package was not removed (previously hidden by `-ErrorAction SilentlyContinue`) and adds it to the report `Message`, while staying best-effort.
- Explorer restart no longer spawns two processes: the script starts `explorer.exe` only if Windows did not relaunch the shell on its own.
- CSV/JSON/HTML reports are written as UTF-8 **without BOM** (via `UTF8Encoding($false)`), making them easier to parse with other tools.
- Minor code hygiene: fixed broken indentation in the `if ($EnableManualWindowsUpdateMode)` block.

### Added (preflight checks)

- "Per-user hive (HKCU)" warning: if the script runs under an account different from the interactive user, per-user (HKCU) settings land in that account's profile — now surfaced honestly as `Warning` in the report.
- "PowerShell bitness" warning: a 32-bit PowerShell host on 64-bit Windows is subject to WOW6432Node redirection for parts of `HKLM\SOFTWARE`; preflight advises re-running 64-bit Windows PowerShell.

### Docs

- Documented the `-TelemetryLevel` parameter and the in-script module toggles in the README.
- Added explicit warnings about Target Release Version pinning and the `AUOptions=2` update behavior.
- Added `SECURITY.md` (private vulnerability reporting, release integrity verification).

## [v2.1] - 2026-05-22

### Fixed

- Fixed a false-positive `VerifyFail` for the `TaskbarDa` registry value.
  - If Widgets are already disabled by policy through `HKLM:\SOFTWARE\Policies\Microsoft\Dsh\AllowNewsAndInterests = 0`, a missing `TaskbarDa` UI value is no longer treated as a failure.
  - This avoids reporting a failure when Widgets are correctly disabled by system policy.
- Improved Windows 11 detection.
  - The script now detects Windows 11 by build number `>= 22000` instead of relying only on `ProductName`.
  - This fixes incorrect warnings on Windows 11 systems where legacy registry fields still report `Windows 10 Pro`.

### Changed

- Improved verification logic for taskbar-related UI settings.
- Reduced unnecessary warnings in the preflight check.

## [v2.0] - 2026-05-10

### Added

- Added three execution modes:
  - `Audit` — checks the current system state without changing anything.
  - `Apply` — applies only settings that are not already configured.
  - `Verify` — checks whether the desired registry and policy values are actually present after configuration.
- Added HTML, CSV, and JSON reports.
- Added registry backup before applying changes.
- Added restore point creation attempt before applying changes.
- Added Windows AI / Recall / Copilot policy configuration.
- Added Widgets / News / Weather policy configuration.
- Added Cloud Content / Consumer Experience / Spotlight configuration.
- Added privacy and diagnostics baseline.
- Added Windows Search quiet mode.
- Added Start Menu and Taskbar cleanup.
- Added Windows Update control:
  - exclude drivers from Windows Update;
  - defer feature updates;
  - defer quality updates;
  - disable optional feature rollout behavior;
  - pin target release to Windows 11 25H2 (made opt-in starting with v2.2).
- Added Delivery Optimization configuration.
- Added Microsoft Edge Quiet Mode:
  - disable Startup Boost;
  - disable background mode;
  - hide first-run experience;
  - reduce promotional Edge behavior.
- Added Developer Mode configuration.
- Added Win32 Long Paths support.
- Added Fast Startup control without disabling hibernation.
- Added Game DVR / Game Bar configuration.
- Added optional Copilot app cleanup.
- Added optional Microsoft Teams personal cleanup.
- Added optional Xbox app cleanup toggle.

### Changed

- Reworked the script into a safer configuration tool instead of a simple one-way tweak script.
- Added status reporting for each setting:
  - `Compliant`;
  - `WouldChange`;
  - `Changed`;
  - `VerifyOK`;
  - `VerifyFail`;
  - `Skipped`;
  - `Warning`;
  - `BestEffort`;
  - `MaybeIgnoredOnEdition`.
- Added clearer separation between official policies, UI preferences, and best-effort tweaks.
- Improved logging and report generation.

### Notes

- The script does not disable Microsoft Defender.
- The script does not disable Windows Firewall.
- The script does not disable the Windows Update service.
- The script does not remove Microsoft Store.
- The script does not remove Edge WebView2 Runtime.
- The script does not remove .NET, Visual C++ Redistributables, certificates, or critical Windows components.

## [v1.0] - 2026-04-15

### Added

- Initial Windows 11 Calm Mode configuration script.
- Added basic registry-based configuration for:
  - Copilot;
  - Widgets;
  - Windows consumer experience;
  - advertising ID;
  - diagnostic data;
  - Windows Search;
  - Windows Update;
  - Delivery Optimization;
  - Taskbar and Start Menu;
  - Game DVR.
- Added basic backup and logging.
