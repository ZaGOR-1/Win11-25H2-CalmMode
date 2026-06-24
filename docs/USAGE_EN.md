# Usage

[← README](../README_EN.md) · [Українською](USAGE_UA.md)

## Requirements

- Windows 11 25H2 or a nearby Windows 11 build.
- Windows PowerShell 5.1 Desktop.
- `Apply` must be run as Administrator.
- Run `Audit` first and preferably test in a VM before applying on a main system.

Check Windows:

```powershell
winver
```

Check PowerShell:

```powershell
$PSVersionTable.PSVersion
```

## Modes

| Mode | What it does | Changes the system |
|---|---|---|
| `Audit` | Reads current state and shows what would change | No |
| `Apply` | Applies missing or incorrect values | Yes |
| `Verify` | Checks whether desired values are present | No |

Default mode is `Audit`.

## Examples

```powershell
# Safe audit
.\Win11-25H2-CalmMode.ps1 -Mode Audit

# Apply settings
.\Win11-25H2-CalmMode.ps1 -Mode Apply

# Verify after reboot
.\Win11-25H2-CalmMode.ps1 -Mode Verify
```

```powershell
# Reports in a custom folder
.\Win11-25H2-CalmMode.ps1 -Mode Audit -ReportPath C:\Temp\CalmMode

# No report files, console only
.\Win11-25H2-CalmMode.ps1 -Mode Audit -NoReport

# Apply and immediately Verify in the same report
.\Win11-25H2-CalmMode.ps1 -Mode Apply -ThenVerify
```

## Parameters

| Parameter | Default | Description |
|---|---:|---|
| `-Mode` | `Audit` | `Audit`, `Apply`, or `Verify` |
| `-TargetReleaseVersionInfo` | `25H2` | Version used for Target Release Version pinning; only when `$EnableTargetReleaseVersionPin = $true` |
| `-FeatureUpdateDeferralDays` | `90` | Days to defer feature updates |
| `-QualityUpdateDeferralDays` | `7` | Days to defer quality updates |
| `-ActiveHoursStart` | `10` | Active hours start |
| `-ActiveHoursEnd` | `2` | Active hours end |
| `-SearchMode` | `Icon` | Taskbar search mode: `Hidden`, `Icon`, `Box` |
| `-TelemetryLevel` | `1` | Diagnostic data level for `AllowTelemetry`; `0` is honored only on Enterprise/Education/IoT |
| `-SetTaskbarLeft` | `$true` | Align taskbar left |
| `-ReportPath` | Desktop | Base report folder |
| `-NoReport` | off | Do not create HTML/CSV/JSON/log files in read-only modes |
| `-OpenReport` | off | Open HTML report after completion |
| `-ConfigPath` | none | JSON config for block/tweak selection |
| `-ExportCatalog` | off | Read-only JSON catalog for GUI/tools |
| `-Skip` | none | Disable listed blocks, for example `-Skip Widgets,Gaming` |
| `-Only` | none | Enable only listed blocks, for example `-Only WindowsAI` |
| `-ThenVerify` | off | Run `Verify` immediately after `Apply` |
| `-RestoreFrom` | none | Import `rollback.reg` from a report folder or a direct `.reg` file |
| `-EnableSystemProtection` | off | Opt-in: enable System Protection before restore point |
| `-SkipRestorePoint` | off | Do not create a restore point in `Apply` |
| `-NoAppCleanup` | off | Skip Appx cleanup |
| `-NoRestartExplorer` | off | Do not restart Explorer after `Apply` |

## GUI

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Win11-25H2-CalmMode-GUI.ps1
```

Or double-click:

```text
Win11-25H2-CalmMode-GUI.cmd
```

The GUI:

- reads the engine catalog through `-ExportCatalog`;
- shows blocks and individual tweaks as a checkbox tree;
- has an **EN / UA** toggle for buttons, blocks, tweak names, descriptions, and results grid labels;
- can save/load the selection as JSON config;
- runs safe `Audit`;
- runs `Apply` through UAC;
- can run **Undo last Apply** through `rollback.reg`.

The GUI contains no policy logic of its own. The single source of truth is `Win11-25H2-CalmMode.ps1`.

## Module Toggles

At the top of `.ps1`, whole blocks can be enabled/disabled through variables:

| Toggle | Default | Enables |
|---|---:|---|
| `$EnableWindowsAIBlock` | `$true` | Windows AI / Recall / Copilot |
| `$EnableWidgetsBlock` | `$true` | Widgets / News and Interests |
| `$EnableCloudContentBlock` | `$true` | Cloud Content / ads / recommendations |
| `$EnablePrivacyBlock` | `$true` | Advertising ID / diagnostics / feedback |
| `$EnableSearchBlock` | `$true` | Windows Search quiet mode |
| `$EnableStartTaskbarBlock` | `$true` | Start / Taskbar / Explorer |
| `$EnableWindowsUpdateBlock` | `$true` | Windows Update deferral / active hours |
| `$EnableManualWindowsUpdateMode` | `$false` | Opt-in manual update mode (`AUOptions=2`) |
| `$EnableTargetReleaseVersionPin` | `$false` | Opt-in feature version pinning |
| `$EnableDeveloperMode` | `$false` | Opt-in Developer Mode / sideloading |
| `$RemoveCopilotApp` | `$false` | Opt-in Appx cleanup: Copilot |
| `$RemoveTeamsPersonal` | `$false` | Opt-in Appx cleanup: Teams personal |
| `$RemoveXboxApps` | `$false` | Opt-in Appx cleanup: Xbox |
| `$RemoveOneDrive` | `$false` | Opt-in OneDrive uninstall |
