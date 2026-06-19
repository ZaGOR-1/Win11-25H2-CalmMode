# Changelog

All notable changes to this project are documented in this file.

This project uses a simple versioning style: `vMAJOR.MINOR`.

## [v2.9] - 2026-06-20

### Added

- **Engine support for new registry value types:** `QWord`, `ExpandString`, `MultiString` (in
  addition to `DWord`/`String`). Touches `Add-RegSetting`, `Test-ValueEquals`, the write path in
  `Invoke-RegSetting`, and `rollback.reg` encoding (`hex(b)`/`hex(2)`/`hex(7)`). This is
  **infrastructure** for future policies — no existing tweak uses these types yet and current
  behavior is unchanged.

### Changed

- **Per-run `Get-ItemProperty` cache** (`Get-RegValueSafe`): each key is read once instead of once
  per value (e.g. ContentDeliveryManager reads ~17 values from one key). Writes invalidate the cache
  via `Clear-RegKeyCache`, so the Apply read-back always sees fresh data.

### Tests

- `Test-ValueEquals` for `QWord`/`ExpandString`/`MultiString`; `Format-RegValueLine` encoding of the
  new types (exact hex vectors); cache invariant (`Clear-RegKeyCache`); **idempotency** — a repeated
  `Apply` on an already-correct value yields `AlreadyConfigured` (no write). **68** total.

## [v2.8] - 2026-06-20

### Added

- **GUI: a "Filter" box** — narrows the tree by substring match on block titles or tweak labels
  (with a **Clear** button); the selection is never lost (the filter is a view; the canonical model
  keeps the checkbox state).
- **GUI: "(N would change)" counts on blocks** after an Audit — shows where the changes are.
- **GUI: impact preview before Apply** — a quick hidden Audit runs before the UAC prompt and shows
  roughly how many items would change.
- **GUI: "Export CSV..." button** in the results window — saves the shown rows (honoring the
  *Show all* toggle) to CSV.
- **GUI: "Undo last Apply" fallback** — if no `…-Apply-…` folder is on the Desktop (custom
  `-ReportPath`, redirected Desktop), the user can browse to a folder containing `rollback.reg`.
- **`-OpenReport`** engine switch — opt-in: open the HTML report in the browser after writing reports
  (ignored together with `-NoReport`).

### Changed

- **The GUI reads the selection from the canonical block/tweak model**, not the current (possibly
  filtered) tree, so `Save config`, `Apply`, and `Select all/none` stay correct while filtering.

### Tests

- `-SelfTest` extended: a filter hides non-matching nodes but does not change the canonical selection,
  and clearing the filter restores all blocks. Parse of `-OpenReport` (`Audit -NoReport -OpenReport`
  → exit 0). **58** total.

## [v2.7] - 2026-06-20

### Added

- **`Run configuration` preflight row in the report.** Every run now records the effective
  configuration: which blocks were enabled, which individual tweaks were disabled, and where the
  selection came from (`-ConfigPath`/`-Skip`/`-Only`/script defaults). Lands in CSV/JSON/HTML, making
  reports reproducible.
- **Pending-reboot banner in the HTML report** — if a reboot is already pending, a prominent warning
  appears at the top (some policies fully apply only after a restart).
- **The catalog (`-ExportCatalog`) now exposes a `Title` per block and `AttentionStatuses`** — a single
  source of truth in the engine.

### Changed

- **Removed engine/GUI duplication.** The "attention" status list (row highlighting) and the
  human-readable block titles now have a single source in the engine; the GUI reads them from the
  catalog and keeps its own copies only as a fallback for older versions. Less drift risk on future edits.

### Tests

- `Get-AttentionStatuses` (membership, no duplicates, subset of known statuses); the catalog contains a
  `Title` for every block and a non-empty `AttentionStatuses`; the `Run configuration` preflight row
  reflects a disabled block and disabled tweaks. **57** total.

## [v2.6.1] - 2026-06-20

### Fixed

- **Aligned `Audit`/`Verify` with `Apply` for non-applicable policies.** If a policy does not apply to
  the current edition/build (i.e. `Apply` would skip it), read-only modes now report `Skipped` instead
  of `WouldChange`/`VerifyFail`. Previously this could produce a false `VerifyFail` during
  `Apply -ThenVerify` and therefore exit code `2` after an otherwise clean `Apply` (a latent trap for
  future edition-limited tweaks with `ApplyIfMaybeUnsupported = $false`).

### Documentation

- README: new **"Exit codes"** section (`0`/`1`/`2`) noting that a pre-reboot `Apply -ThenVerify`
  confirms only the registry write, not the UI effect.

### Tests

- Regression for `Get-RegValueSafe`: a missing value/key returns `Exists=$false`, `Error=$null` with no
  terminating error.
- Regression for the fix above: an edition-skipped tweak reports `Skipped` (not `VerifyFail`/`WouldChange`)
  in both `Verify` and `Audit`; an applicable-but-missing tweak still reports `VerifyFail`. **49** tests total.

## [v2.6] - 2026-06-20

### Added

- **`-Skip` / `-Only`** — a quick CLI alternative to `-ConfigPath` for whole-block selection. `-Skip Widgets,Gaming` turns the listed blocks off; `-Only WindowsAI` keeps only the listed blocks and turns the rest off. Keys are validated against `$script:BlockToggleMap`; combining `-Skip`+`-Only` or an unknown key is an error (exit 1). Applied after `-ConfigPath`, so they can refine a loaded config.
- **`-ThenVerify`** — after a successful `Apply`, immediately run a `Verify` pass and append its results to the same report (confirms the registry values landed; it does not prove Windows UI honors a policy before a reboot). Ignored unless `-Mode Apply`.
- **GUI:** Apply now passes `-ThenVerify`, so the results window shows the Verify rows right after applying.
- **`-RestoreFrom <folder|.reg>`** — undo registry changes by importing `rollback.reg` (`reg import`) from a report folder or a direct `.reg` file. Requires Administrator; supports `-WhatIf`/`-Confirm`. Restores REGISTRY only, not Appx packages. The GUI adds an **Undo last Apply** button (finds the latest `…-Apply-…` folder on the Desktop, with confirmation and UAC).
- **`-EnableSystemProtection`** — opt-in system change: turns System Protection on for the system drive before creating the restore point (otherwise the restore point is silently skipped). Apply-only, off by default.
- **`Sign-CalmMode.ps1`** — helper to Authenticode-sign the scripts with YOUR certificate (none is shipped; SHA256 stays the primary integrity mechanism).
- Pester tests for `-Skip`/`-Only` and for `-RestoreFrom` error paths (missing path, folder with no `.reg`) — 44 total.

## [v2.5] - 2026-06-20

### Added

- **End-of-run summary.** After every run (Audit/Apply/Verify, even with `-NoReport`) a "Summary" block prints the total number of checks and per-status counts (`Compliant`, `WouldChange`, `Skipped`, `Warning`, …). In Audit it also reports how many items "would change on Apply" (respecting `-WhatIf`).
- **Pending reboot detection** (read-only preflight). Checks `Component Based Servicing\RebootPending`, `WindowsUpdate\Auto Update\RebootRequired`, and `PendingFileRenameOperations`; if a restart is already queued it is shown as `Warning`. Nothing is rebooted automatically — many policies only fully take effect after a restart.
- **Improved HTML report.** A **"Needs attention"** section at the top (Warning / VerifyFail / Error / RequiresVerification / MaybeIgnoredOnEdition / WouldChange / WouldRemove / UnsupportedBuild) and a **"By confidence"** summary.
- Tests for the new helpers `Get-ResultSummary` and `Test-PendingReboot` (38 total).

### Changed

- HTML report reordered: "Needs attention" → "Status summary" → "By confidence" → "Detailed results".

## [v2.4] - 2026-06-19

### Added

- **GUI: results shown in-window.** After **Run Audit** (and **Apply**) the GUI reads the generated JSON report and shows it in a grid with a "Needs attention" filter (default; a *Show all* toggle reveals everything) plus a per-status summary. Audit no longer opens a separate console.
- **GUI: Save config… / Load config….** Save the current checkbox selection to JSON and load it later (the same format as `-ConfigPath`).
- **GUI: basic HiDPI support** (`SetProcessDPIAware` + `AutoScaleMode = Dpi`) so text and controls are not blurry on scaled displays.
- `Get-KnownStatuses` — a single canonical list of report statuses; `Add-Result` now writes to the verbose stream when it sees an unknown status (typo guard). The 40+ call sites are intentionally not machine-rewritten to constants: the same literals mean different things across the Status/Confidence/Support fields, so a blind replace would be unsafe.
- Pester tests for the config mechanism: `-ExportCatalog` structure, `-ConfigPath` filtering (disabled block → 0 results, disabled tweak → `Skipped`), that Audit emits only known statuses, the exit-1 path on a missing config, and the GUI `-SelfTest` (config formation + round-trip). 36 tests total.

### Changed

- **GUI: temp config cleanup.** Temporary `Win11-CalmMode-GUI-config-*.json` files are removed after a run (the engine is now launched with `-Wait`), and leftovers from previous crashed runs are cleaned up on GUI start.
- GUI: `-SelfTest` extended — besides building the tree it now verifies config formation and a load round-trip.

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
