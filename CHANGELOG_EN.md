# Changelog

All notable changes to this project are documented in this file.

This project uses a simple versioning style: `vMAJOR.MINOR`.

## [v2.2] - 2026-06-18

### Added

- `-WhatIf` / `-Confirm` support: the script now declares `SupportsShouldProcess`, so `Apply` can be previewed without changing the system.
- `-TelemetryLevel` parameter (`0`–`3`) to control the `AllowTelemetry` diagnostic data policy. Default `1` (Required), which is the minimum actually honored on Home/Pro; the script does not force telemetry fully off.
- New report status `RequiresVerification` for policies whose exact name or behavior is not fully confirmed across builds/editions.
- Real `.gitignore` (previously only a `gitignore-snippet.txt` example existed), so local files and generated reports/backups are not committed by accident.
- Local script `New-ReleaseArchive.ps1` to easily package safe release `.zip` archives without dirty files like `.git`.
- Deeper versioning support via `$MinUBR` (Update Build Revision) checking for strict policies like Windows AI (Recall).
- Fully automated CI/CD checks via GitHub Actions: includes `PSScriptAnalyzer`, a forbidden patterns check, and automated Dry-run Audit mode.

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

### Docs

- Documented the `-TelemetryLevel` parameter and the in-script module toggles in the README.
- Added explicit warnings about Target Release Version pinning and the `AUOptions=2` update behavior.

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
