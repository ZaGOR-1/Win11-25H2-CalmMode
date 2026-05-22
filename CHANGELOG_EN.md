# Changelog

All notable changes to this project are documented in this file.

This project uses a simple versioning style: `vMAJOR.MINOR`.

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

## [v2.0] - 2026-05-22

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
  - pin target release to Windows 11 25H2.
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

## [v1.0] - 2026-05-22

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
