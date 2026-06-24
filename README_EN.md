# Win11 25H2 Calm Mode

<p align="right">
  <a href="README.md"><strong>Українська</strong></a>
</p>

A PowerShell script for carefully tuning Windows 11 25H2 into a calmer mode: fewer Copilot/AI features, Widgets, ads, recommendations, Edge background processes, automatic Windows Update drivers, and noisy UI prompts.

This script is **not an aggressive debloater**. It does not disable Microsoft Defender, Windows Firewall, the Windows Update service, Microsoft Store, WebView2, .NET, certificates, or critical system services.

> Core idea: do not break Windows; set local policy/registry values that make the system quieter and more predictable.

---

## What It Does

- Works in three modes: `Audit`, `Apply`, `Verify`.
- Includes a simple **graphical interface** (`Win11-25H2-CalmMode-GUI.ps1`) with checkboxes for blocks and individual tweaks.
- Backs up important registry branches before changes.
- Creates a restore point in `Apply` mode if System Protection is enabled.
- Checks whether a value is already configured and avoids unnecessary writes.
- Prints an end-of-run **summary**: status counters and, in Audit mode, how many items would change on Apply.
- Warns if a **pending reboot** already exists, because some policies take full effect only after a reboot.
- Creates `HTML`, `CSV`, and `JSON` reports; the HTML report has a **Needs attention** section at the top.
- Marks policies that may be build-dependent, deprecated, UI-only, or edition-limited.
- Does not hide uncertainty: if Windows may ignore a policy on a given edition, the report says so.

---

## Requirements

- Windows 11 25H2 or a nearby Windows 11 build.
- Windows PowerShell 5.1.
- `Apply` mode must be run **as Administrator**.
- Testing first in a VM or on a test installation is strongly recommended.

Check Windows version:

```powershell
winver
```

Check PowerShell:

```powershell
$PSVersionTable.PSVersion
```

---

## Quick Start

### 1. Audit: see what would change

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
cd "$env:USERPROFILE\Desktop"
.\Win11-25H2-CalmMode.ps1 -Mode Audit
```

`Audit` changes nothing. It only reads current values and creates a report.

### 2. Apply: apply the settings

```powershell
.\Win11-25H2-CalmMode.ps1 -Mode Apply
```

Rebooting after Apply is recommended.

### 3. Verify: check after reboot

```powershell
.\Win11-25H2-CalmMode.ps1 -Mode Verify
```

---

## Modes

| Mode | What it does | Changes the system |
|---|---|---|
| `Audit` | Reads current state and shows what would change | No |
| `Apply` | Applies missing or incorrect values | Yes |
| `Verify` | Checks whether desired values are present | No |

The default mode is `Audit`, so accidentally running the script without parameters does not change the system.

```powershell
.\Win11-25H2-CalmMode.ps1
```

is the same as:

```powershell
.\Win11-25H2-CalmMode.ps1 -Mode Audit
```

---

## Parameters

| Parameter | Default | Description |
|---|---:|---|
| `-Mode` | `Audit` | `Audit`, `Apply`, or `Verify` |
| `-TargetReleaseVersionInfo` | `25H2` | Windows version used for Target Release Version pinning. **Only applies** when `$EnableTargetReleaseVersionPin = $true` is enabled. Default is off |
| `-FeatureUpdateDeferralDays` | `90` | Number of days to defer feature updates |
| `-QualityUpdateDeferralDays` | `7` | Number of days to defer quality updates |
| `-ActiveHoursStart` | `10` | Active hours start |
| `-ActiveHoursEnd` | `2` | Active hours end |
| `-SearchMode` | `Icon` | Taskbar search appearance: `Hidden`, `Icon`, `Box` |
| `-TelemetryLevel` | `1` | Diagnostic data level for `AllowTelemetry`: `0` = Security/Off, honored only on Enterprise/Education/IoT and ignored on Home/Pro; `1` = Required, the minimum level Home/Pro actually honor; `2` = Enhanced; `3` = Full. Default is `1`, so the script does **not** fully turn off diagnostics on Home/Pro |
| `-SetTaskbarLeft` | `$true` | Align taskbar to the left |
| `-ReportPath` | Desktop | Base folder for the timestamped report directory. Empty means Desktop, with fallback to `%TEMP%` |
| `-NoReport` | off | Do not create a report folder, transcript, CSV/HTML/JSON files. Console output only. Honored only in read-only modes `Audit`/`Verify`; ignored in `Apply`, because backup and `rollback.reg` require a report folder |
| `-OpenReport` | off | Open the HTML report in the default browser after writing reports. Opt-in; ignored with `-NoReport` |
| `-ConfigPath` | none | Path to a JSON config that enables/disables blocks and individual tweaks without editing `.ps1`. Usually created by the GUI. Schema: `{ "blocks": { "<BlockKey>": true\|false }, "disabledTweaks": ["<Path>\<Name>"] }` |
| `-ExportCatalog` | off | Read-only: prints a JSON catalog of all blocks and tweaks, then exits. Changes nothing and creates no folder. Used by the GUI |
| `-Skip` | none | Quick alternative to `-ConfigPath`: block keys to turn **off**, for example `-Skip Widgets,Gaming`. Cannot be combined with `-Only` |
| `-Only` | none | Enable **only** the listed blocks and turn all others off, for example `-Only WindowsAI`. Cannot be combined with `-Skip` |
| `-ThenVerify` | off | After `Apply`, immediately run `Verify` and append its results to the same report. Applies only in `Apply` |
| `-RestoreFrom` | none | Undo registry changes: if a report folder is passed, imports its `rollback.reg`; for any other `.reg`, pass a direct file path. Requires **Administrator**. Restores **registry only**, not Appx packages |
| `-EnableSystemProtection` | off | **Opt-in system change:** if System Protection is disabled, enable it before creating a restore point. Applies only in `Apply` |
| `-SkipRestorePoint` | off | Do not create a restore point in `Apply` |
| `-NoAppCleanup` | off | Skip Appx package removal |
| `-NoRestartExplorer` | off | Do not restart Explorer after `Apply` |

Examples:

```powershell
.\Win11-25H2-CalmMode.ps1 -Mode Audit -SearchMode Hidden
```

```powershell
.\Win11-25H2-CalmMode.ps1 -Mode Apply -FeatureUpdateDeferralDays 120 -QualityUpdateDeferralDays 7
```

```powershell
.\Win11-25H2-CalmMode.ps1 -Mode Apply -NoAppCleanup
```

```powershell
# Put reports in a custom folder instead of Desktop
.\Win11-25H2-CalmMode.ps1 -Mode Audit -ReportPath C:\Temp\CalmMode
```

```powershell
# Quick audit without report files or folders; console output only
.\Win11-25H2-CalmMode.ps1 -Mode Audit -NoReport
```

```powershell
# Quick block selection without a config file
.\Win11-25H2-CalmMode.ps1 -Mode Audit -Skip Widgets,Gaming     # everything except Widgets and Gaming
.\Win11-25H2-CalmMode.ps1 -Mode Audit -Only WindowsAI          # only Windows AI
```

```powershell
# Apply and immediately Verify in the same report
.\Win11-25H2-CalmMode.ps1 -Mode Apply -ThenVerify
```

```powershell
# Restore registry changes from a previous Apply report folder; requires Administrator
.\Win11-25H2-CalmMode.ps1 -RestoreFrom "C:\Users\<you>\Desktop\Win11-25H2-CalmMode-v2.6-Apply-2026-06-20_12-00-00"
```

---

## Graphical Interface

If you do not want to edit `.ps1` or pass parameters manually, use the simple GUI.

The easiest way is to double-click `Win11-25H2-CalmMode-GUI.cmd` next to the scripts. It is a plain text launcher: it only opens the GUI window and changes nothing. There is no compiled `.exe` or hidden payload.

Or run it manually:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Win11-25H2-CalmMode-GUI.ps1
```

What it does:

- shows a checkbox tree: **blocks** such as Windows AI, Widgets, Cloud Content, etc.; each block expands into individual tweaks;
- the **EN / UA** button switches the GUI language: blocks, all tweak names, selected-tweak details, and the results grid have English and Ukrainian versions;
- the **Filter** box narrows the tree by block or tweak name; checkbox selections are preserved while filtering;
- unchecking a block skips the whole block; unchecking a single tweak skips only that tweak;
- **Run Audit (safe)** starts a read-only run: nothing is changed; results are shown directly in the GUI, without a separate console. After Audit, each block shows an approximate **(N would change)** count;
- **Apply...** first runs a quick internal Audit and shows roughly how many items would change, then asks for confirmation and starts Apply as Administrator via UAC. Before changes, the engine creates backup and a restore point where possible;
- **Save config... / Load config...** saves and reloads the current selection as JSON, using the same format as `-ConfigPath`;
- **Undo last Apply** finds the latest `...-Apply-...` report folder on the Desktop and imports its `rollback.reg` with confirmation and UAC. It restores **registry only**, not Appx packages. If the folder is not on the Desktop, the GUI lets you browse to a folder containing `rollback.reg`;
- **Close** exits the GUI.

Important: the GUI contains **no policy logic of its own**. It reads the engine catalog through `-ExportCatalog` and passes the selection back through a temporary `-ConfigPath` config. The single source of truth remains `Win11-25H2-CalmMode.ps1`. There are no extra dependencies: Windows Forms is included with Windows PowerShell 5.1.

> Tip: run **Audit** first, review the report, and only then use **Apply**. As with the CLI, testing in a VM is safer.

---

## Integrity and Signing

The primary integrity mechanism is **SHA256**. `checksums.txt` and `<zip>.sha256` are generated by `New-ReleaseArchive.ps1` next to the release archive.

Optionally, you can sign the scripts with your own **Authenticode** certificate. The repository does not include a certificate; a self-signed certificate is trusted only on machines that trust it.

```powershell
# Sign with your own code-signing certificate from the certificate store
.\Sign-CalmMode.ps1 -Thumbprint <CERT_THUMBPRINT>

# Verify signature
Get-AuthenticodeSignature .\Win11-25H2-CalmMode.ps1 | Format-List Status, SignerCertificate
```

---

## In-Script Module Toggles

In addition to command-line parameters, the top of `.ps1` has boolean toggles for whole blocks. To change behavior, edit the corresponding line before running the script.

| Toggle | Default | Enables |
|---|---:|---|
| `$EnableWindowsAIBlock` | `$true` | Windows AI / Recall / Click to Do / Paint AI |
| `$EnableWidgetsBlock` | `$true` | Widgets / News and Interests |
| `$EnableCloudContentBlock` | `$true` | Cloud Content / Spotlight / suggestions |
| `$EnablePrivacyBlock` | `$true` | Advertising ID / diagnostics / feedback |
| `$EnableSearchBlock` | `$true` | Windows Search quiet mode |
| `$EnableStartTaskbarBlock` | `$true` | Start / Taskbar / Explorer UI |
| `$EnableWindowsUpdateBlock` | `$true` | Windows Update deferral and active hours |
| `$EnableManualWindowsUpdateMode` | `$false` | **Opt-in.** Enables `AUOptions=2`: notify before download and install |
| `$EnableTargetReleaseVersionPin` | `$false` | **Opt-in.** Target Release Version pinning. See warning below |
| `$EnableDeliveryOptimization` | `$true` | Disable peer-to-peer Delivery Optimization |
| `$EnableEdgeQuietMode` | `$true` | Edge Quiet Mode |
| `$EnableDeveloperMode` | `$false` | **Opt-in.** Developer Mode / sideloading. See warning below |
| `$EnableLongPaths` | `$true` | Win32 long paths |
| `$DisableFastStartup` | `$true` | Disable Fast Startup, not hibernation |
| `$EnableGamingTweaks` | `$true` | Game DVR / Game Bar / Game Mode |
| `$RemoveCopilotApp` | `$false` | **Opt-in.** Appx cleanup: Copilot |
| `$RemoveTeamsPersonal` | `$false` | **Opt-in.** Appx cleanup: Teams personal |
| `$RemoveXboxApps` | `$false` | Appx cleanup: Xbox |
| `$RemoveOneDrive` | `$false` | OneDrive removal |

> **Target Release Version pinning is opt-in.** By default, `$EnableTargetReleaseVersionPin = $false`, so the script does **not** pin the feature version. Pinning (`TargetReleaseVersion`, `ProductVersion`, `TargetReleaseVersionInfo`) makes sense only if you deliberately want to stay on a specific release. Risk: once that release reaches end of servicing, the system can stop receiving feature and security updates until the pin is removed.

> **Developer Mode and sideloading are opt-in.** By default, `$EnableDeveloperMode = $false`. Enabling sideloading and Developer Mode allows installing unsigned/sideloaded apps and expands the attack surface. Enable only when genuinely needed for development.

---

## Reports

Each run creates a folder on the Desktop:

```text
Win11-25H2-CalmMode-v<version>-<Mode>-YYYY-MM-DD_HH-MM-SS
```

It contains:

```text
Win11-25H2-CalmMode-v<version>-report.html
Win11-25H2-CalmMode-v<version>-results.csv
Win11-25H2-CalmMode-v<version>-results.json
Win11-25H2-CalmMode-v<version>.log
```

In `Apply` mode, registry backup `.reg` files are also saved for important branches.

Each report additionally includes:

- **Run configuration** in Preflight: records enabled blocks, disabled individual tweaks, and the selection source (`-ConfigPath`, `-Skip`, `-Only`, or script defaults).
- **Pending reboot** banner in HTML: if Windows already has a pending reboot, the report shows it at the top.

---

## Report Status Fields

`Status` says what happened to an item during the current mode. `Support` and `Confidence` separately explain whether the item is supported by the current Windows build/edition and how well its behavior is confirmed. The HTML **Needs attention** block checks all three fields.

| `Status` | Meaning |
|---|---|
| `Compliant` | The value was already correct in `Audit` |
| `WouldChange` | In `Audit`, this value would be changed |
| `WouldRemove` | In `Audit`, this package would be removed |
| `AlreadyConfigured` | In `Apply`, the value was already correct; no write was performed |
| `Changed` | In `Apply`, the value was written and verified |
| `VerifyOK` | In `Verify`, the desired value is present |
| `VerifyFail` | In `Verify`, the desired value is missing or different |
| `Skipped` | Item skipped by parameters or config |
| `Warning` | Non-critical warning |
| `Error` | Write or verification error |

| `Support` / `Confidence` marker | Meaning |
|---|---|
| `UnsupportedBuild` | Policy does not apply to the current build |
| `MaybeIgnoredOnEdition` | Value can be written, but Windows may ignore it on this edition |
| `BestEffort` | Best-effort setting; behavior may depend on build/package state |
| `RequiresVerification` | Policy name/behavior is not fully confirmed for every build/edition; verify after Apply |
| `DeprecatedOrLegacy` | Old or deprecated policy kept for compatibility |
| `UISetting` | User UI tweak, not always an official device policy |

> If a policy is not applicable to the current edition/build and Apply would skip it, Audit/Verify also mark it as `Skipped`, not `WouldChange`/`VerifyFail`.

## Exit Codes

| Code | Meaning |
|---:|---|
| `0` | No critical errors; `Audit`/`Apply` completed; `Verify` passed |
| `1` | Parameter or preflight error, such as invalid config, missing `-RestoreFrom`, or Apply without admin |
| `2` | `Verify` found one or more `VerifyFail` items |

---

## Registry Backup and Rollback

In `Apply` mode the script exports backup `.reg` files for important registry branches to the report folder.

It also writes:

```text
rollback.reg
```

`rollback.reg` stores per-value rollback data for registry changes made by this script. It restores registry values only. It does **not** restore removed Appx/provisioned packages.

To restore from a report folder:

```powershell
.\Win11-25H2-CalmMode.ps1 -RestoreFrom "C:\Path\To\ReportFolder"
```

For a folder path, the script requires `rollback.reg` specifically. If you want to import a different `.reg`, pass the direct file path:

```powershell
.\Win11-25H2-CalmMode.ps1 -RestoreFrom "C:\Path\To\SomeBackup.reg"
```

---

## Policy and Registry Areas

The sections below document the main registry/policy areas. Some policies are edition/build-limited; the report marks those honestly.

### 1. Windows AI / Recall / Copilot

| Registry path | Name | Desired value | Purpose |
|---|---|---:|---|
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI` | `AllowRecallEnablement` | `0` | Prevents users from enabling Recall where supported |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI` | `DisableAIDataAnalysis` | `1` | Disables Recall snapshot saving / AI data analysis |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI` | `DisableAIDataAnalysis` | `1` | User-scoped Recall snapshot control |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI` | `AllowRecallExport` | `0` | Blocks Recall export where supported |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI` | `DisableClickToDo` | `1` | Disables Click to Do |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI` | `DisableClickToDo` | `1` | User-scoped Click to Do control |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI` | `DisableSettingsAgent` | `1` | Disables AI agent/search in Settings where supported |
| `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint` | `DisableCocreator` | `1` | Disables Paint Cocreator |
| `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint` | `DisableGenerativeFill` | `1` | Disables Paint Generative Fill |
| `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint` | `DisableImageCreator` | `1` | Disables Paint Image Creator |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot` | `TurnOffWindowsCopilot` | `1` | Legacy Copilot policy |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `ShowCopilotButton` | `0` | Hides Copilot taskbar button if present |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI` | `RemoveMicrosoftCopilotApp` | `1` | Best-effort request to remove Copilot app where supported |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI` | `RemoveMicrosoftCopilotApp` | `1` | User-scoped best-effort request to remove Copilot app |

### 2. Widgets / News and Interests

| Registry path | Name | Desired value | Purpose |
|---|---|---:|---|
| `HKLM:\SOFTWARE\Policies\Microsoft\Dsh` | `AllowNewsAndInterests` | `0` | Disables Widgets / News and Interests |
| `HKLM:\SOFTWARE\Policies\Microsoft\Dsh` | `DisableWidgetsBoard` | `1` | Disables Widgets board where supported |
| `HKLM:\SOFTWARE\Policies\Microsoft\Dsh` | `DisableWidgetsOnLockScreen` | `1` | Disables Widgets on lock screen where supported |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `TaskbarDa` | `0` | Hides Widgets taskbar button |

### 3. Cloud Content / Spotlight / Ads

| Registry path | Name | Desired value | Purpose |
|---|---|---:|---|
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent` | `DisableWindowsConsumerFeatures` | `1` | Disables consumer experiences |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent` | `DisableSoftLanding` | `1` | Disables soft landing tips/prompts |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent` | `DisableCloudOptimizedContent` | `1` | Disables cloud optimized content |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent` | `DisableConsumerAccountStateContent` | `1` | Disables Microsoft account state consumer content |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent` | `DisableWindowsSpotlightFeatures` | `1` | Disables Windows Spotlight features |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent` | `DisableWindowsSpotlightOnActionCenter` | `1` | Disables Spotlight in Action Center |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent` | `DisableWindowsSpotlightOnSettings` | `1` | Disables Spotlight suggestions in Settings |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent` | `DisableWindowsSpotlightWindowsWelcomeExperience` | `1` | Disables Windows welcome experience after updates |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent` | `DisableThirdPartySuggestions` | `1` | Disables third-party suggestions |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent` | `DisableTailoredExperiencesWithDiagnosticData` | `1` | Disables tailored experiences with diagnostic data |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\*` | various values | `0` | Disables ContentDeliveryManager suggestions/Spotlight toggles |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement` | `ScoobeSystemSettingEnabled` | `0` | Disables "Get even more out of Windows" post-OOBE prompt |

### 4. Privacy / Diagnostics / Advertising ID

| Registry path | Name | Desired value | Purpose |
|---|---|---:|---|
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo` | `DisabledByGroupPolicy` | `1` | Disables Advertising ID by policy |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo` | `Enabled` | `0` | Disables Advertising ID for current user |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection` | `AllowTelemetry` | `1` | Sets diagnostic data to Required on Pro/Home |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy` | `TailoredExperiencesWithDiagnosticDataEnabled` | `0` | Disables tailored experiences |
| `HKCU:\Software\Microsoft\Siuf\Rules` | `NumberOfSIUFInPeriod` | `0` | Disables feedback frequency prompts |
| `HKCU:\Software\Microsoft\Siuf\Rules` | `PeriodInNanoSeconds` | `0` | Disables feedback prompt period |

### 5. Windows Search

| Registry path | Name | Desired value | Purpose |
|---|---|---:|---|
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search` | `EnableDynamicContentInWSB` | `0` | Disables Search highlights / dynamic content |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search` | `AllowCloudSearch` | `0` | Disables cloud search integration |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search` | `AllowSearchToUseLocation` | `0` | Disables location-aware Windows Search |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search` | `DisableWebSearch` | `1` | Disables web search where supported |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search` | `ConnectedSearchUseWeb` | `0` | Blocks web results in Search where supported |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer` | `DisableSearchBoxSuggestions` | `1` | Disables Search box suggestions in Explorer/Start |

### 6. Start Menu / Taskbar / Explorer

| Registry path | Name | Desired value | Purpose |
|---|---|---:|---|
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer` | `HideRecommendedSection` | `1` | Hides Recommended section in Start where supported |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer` | `HideRecommendedSection` | `1` | User-scoped variant |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer` | `HideRecommendedPersonalizedSites` | `1` | Hides recommended personalized sites |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer` | `HideRecommendedPersonalizedSites` | `1` | User-scoped variant |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer` | `HideRecentlyAddedApps` | `1` | Hides recently added apps |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer` | `HideRecentlyAddedApps` | `1` | User-scoped variant |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer` | `HideFrequentlyUsedApps` | `1` | Hides frequently used apps |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer` | `HideFrequentlyUsedApps` | `1` | User-scoped variant |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `TaskbarAl` | `0` | Aligns taskbar to the left |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Search` | `SearchboxTaskbarMode` | depends on `-SearchMode` | `Hidden=0`, `Icon=1`, `Box=2` |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `ShowTaskViewButton` | `0` | Hides Task View button |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `TaskbarDa` | `0` | Hides Widgets button |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `TaskbarMn` | `0` | Hides Chat/Teams consumer button if present |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `Start_TrackDocs` | `0` | Stops tracking recent documents |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `Start_TrackProgs` | `0` | Stops tracking frequently used programs |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `Start_IrisRecommendations` | `0` | Disables Start recommendations UI toggle where supported |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\AccountNotifications` | `DisableAccountNotifications` | `1` | **Policy** (24H2/26100+, Pro and above): removes account/subscription nags on the Start user tile. Ignored on Home; the UI toggle below covers Home |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `Start_AccountNotifications` | `0` | **UISetting**: Settings → Personalization → Start "Show account-related notifications" |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `HideFileExt` | `0` | Shows file extensions |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `ShowSyncProviderNotifications` | `0` | Disables sync provider notifications in Explorer |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `LaunchTo` | `1` | Opens Explorer to This PC |

### 7. Windows Update

| Registry path | Name | Desired value | Purpose |
|---|---|---:|---|
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU` | `NoAutoUpdate` | `0` | Does not disable Windows Update |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU` | `AUOptions` | `2` | **Opt-in** (`$EnableManualWindowsUpdateMode`, default off). Manual update mode |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU` | `NoAutoRebootWithLoggedOnUsers` | `1` | Avoids auto-restart while a user is logged on |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` | `ExcludeWUDriversInQualityUpdate` | `1` | Excludes drivers from Windows Updates |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` | `SetAllowOptionalContent` | `0` | Does not automatically receive optional updates / gradual rollouts |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` | `DeferFeatureUpdates` | `1` | Enables feature update deferral |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` | `DeferFeatureUpdatesPeriodInDays` | default `90` | Defers feature updates |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` | `DeferQualityUpdates` | `1` | Enables quality update deferral |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` | `DeferQualityUpdatesPeriodInDays` | default `7` | Defers quality updates |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` | `ManagePreviewBuilds` | `0` | Disables user management of Insider preview builds |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` | `SetActiveHours` | `1` | Enables manual active hours |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` | `ActiveHoursStart` | default `10` | Active hours start |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` | `ActiveHoursEnd` | default `2` | Active hours end |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` | `TargetReleaseVersion` | `1` | **Opt-in** (`$EnableTargetReleaseVersionPin`, default off). Enables target release version pinning |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` | `ProductVersion` | `Windows 11` | **Opt-in.** Target product version |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` | `TargetReleaseVersionInfo` | default `25H2` | **Opt-in.** Pins Windows feature version |
| `HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings` | `IsContinuousInnovationOptedIn` | `0` | Disables "Get latest updates as soon as available" UI toggle |

> **Windows Update note.** `AUOptions = 2` makes updates manual: Windows notifies, but does not download and install automatically, so security patches are not installed until the user acts. This does **not** disable Windows Update or its service. Version pinning (`TargetReleaseVersion*`) is off by default.

### 8. Delivery Optimization

| Registry path | Name | Desired value | Purpose |
|---|---|---:|---|
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization` | `DODownloadMode` | `0` | Disables peer-to-peer Delivery Optimization; HTTP only |

### 9. Microsoft Edge Quiet Mode

| Registry path | Name | Desired value | Purpose |
|---|---|---:|---|
| `HKLM:\SOFTWARE\Policies\Microsoft\Edge` | `StartupBoostEnabled` | `0` | Disables Edge Startup Boost |
| `HKLM:\SOFTWARE\Policies\Microsoft\Edge` | `BackgroundModeEnabled` | `0` | Does not keep Edge background apps after close |
| `HKLM:\SOFTWARE\Policies\Microsoft\Edge` | `HideFirstRunExperience` | `1` | Hides first-run experience |
| `HKLM:\SOFTWARE\Policies\Microsoft\Edge` | `LaunchEdgeOnWindowsStartupEnabled` | `0` | Prevents Edge from launching automatically at Windows startup |
| `HKLM:\SOFTWARE\Policies\Microsoft\Edge` | `PromotionalTabsEnabled` | `0` | Disables promotional tabs |
| `HKLM:\SOFTWARE\Policies\Microsoft\Edge` | `HubsSidebarEnabled` | `0` | Disables Edge sidebar/hubs where supported |

### 10. Developer Mode / Long Paths

**Warning (security trade-off):** enabling Developer Mode and sideloading through `$EnableDeveloperMode = $true` allows deploying and running unsigned/sideloaded apps, which expands the attack surface. Use only when needed for development. Disabled by default.

| Registry path | Name | Desired value | Purpose |
|---|---|---:|---|
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Appx` | `AllowDevelopmentWithoutDevLicense` | `1` | Developer Mode policy |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Appx` | `AllowAllTrustedApps` | `1` | Allows trusted apps / sideloading policy |
| `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock` | `AllowDevelopmentWithoutDevLicense` | `1` | UI compatibility key for Developer settings |
| `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock` | `AllowAllTrustedApps` | `1` | UI compatibility key for trusted apps |
| `HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem` | `LongPathsEnabled` | `1` | Enables Win32 long paths for apps that support `longPathAware` |

### 11. Fast Startup / Power

| Registry path | Name | Desired value | Purpose |
|---|---|---:|---|
| `HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power` | `HiberbootEnabled` | `0` | Disables Fast Startup locally |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\System` | `HiberbootEnabled` | `0` | Does not require Fast Startup by policy |

The script **does not disable hibernation entirely**. It disables Fast Startup / Hybrid Boot only.

### 12. Gaming / Game DVR

| Registry path | Name | Desired value | Purpose |
|---|---|---:|---|
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR` | `AppCaptureEnabled` | `0` | Disables background capture / Game DVR |
| `HKCU:\System\GameConfigStore` | `GameDVR_Enabled` | `0` | Disables Game DVR in GameConfigStore |
| `HKCU:\Software\Microsoft\GameBar` | `ShowStartupPanel` | `0` | Hides Game Bar startup panel |

### 13. Appx Cleanup

Appx cleanup is disabled by default. Removing specific packages is opt-in only: through module toggles, saved GUI/config, or a config file that explicitly enables the relevant block. This is a best-effort action: registry rollback does not restore removed Appx or provisioned packages.

| Target | Patterns | Default |
|---|---|---:|
| Microsoft Copilot app | `*Copilot*`, `Microsoft.Copilot*` | disabled |
| Microsoft Teams personal | `MSTeams*`, `MicrosoftTeams*` | disabled |
| Xbox apps | `Microsoft.Xbox*`, `Microsoft.GamingApp*`, `Microsoft.XboxGamingOverlay*`, `Microsoft.XboxGameOverlay*`, `Microsoft.XboxIdentityProvider*`, `Microsoft.XboxSpeechToTextOverlay*` | disabled |
| OneDrive | `OneDriveSetup.exe /uninstall` | disabled |

To skip Appx cleanup:

```powershell
.\Win11-25H2-CalmMode.ps1 -Mode Apply -NoAppCleanup
```

---

## What The Script Does Not Do

The script intentionally **does not**:

```text
- disable Microsoft Defender;
- disable Windows Firewall;
- disable the Windows Update service;
- remove Microsoft Store;
- remove Edge or WebView2;
- remove .NET;
- remove Visual C++ Redistributables;
- block Microsoft domains through hosts;
- disable UAC;
- disable certificates or cryptographic services;
- mass-disable system services.
```

---

## Known Notes

### `ProductName=Windows 10 Pro` on Windows 11

On some Windows 11 builds, the legacy `ProductName` registry value can still say `Windows 10 Pro`. The script also checks `DisplayVersion`, `Build`, `EditionId`, and `EditionGroup`.

### `TaskbarDa` may be absent

If Widgets are disabled by policy:

```text
HKLM:\SOFTWARE\Policies\Microsoft\Dsh\AllowNewsAndInterests = 0
```

then a missing `TaskbarDa` does not always indicate a problem. It is a UI setting that Windows may not create, or may remove, depending on build/state.

### Registry verification does not guarantee UI behavior

`VerifyOK` means the registry/policy value exists. It does not always guarantee that Windows UI fully honors the policy, especially if it is edition-limited or build-dependent. The script marks such items as `MaybeIgnoredOnEdition`, `BestEffort`, `DeprecatedOrLegacy`, or `UISetting`.

---

## How To Roll Back Changes

In `Apply` mode, the script creates backups of important registry branches in the report folder.

Manual backup import:

```powershell
reg import "C:\Path\To\Backup.reg"
gpupdate /force
```

You can also use System Restore if a restore point was created successfully.

> **Note:** registry rollback through `rollback.reg` or System Restore does not automatically restore removed Appx packages. Those must be reinstalled manually through Microsoft Store.

---

## Manual Verification

Check Windows AI policies:

```powershell
Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
```

Check Windows Update policies:

```powershell
Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
```

Check Widgets:

```powershell
Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
```

Create a Group Policy report:

```powershell
gpresult /h "$env:USERPROFILE\Desktop\gpresult.html"
```

---

## Recommended Use Order

```powershell
# 1. See what would change
.\Win11-25H2-CalmMode.ps1 -Mode Audit

# 2. Apply
.\Win11-25H2-CalmMode.ps1 -Mode Apply

# 3. Reboot
Restart-Computer

# 4. Verify
.\Win11-25H2-CalmMode.ps1 -Mode Verify
```

---

## Official References

- WindowsAI Policy CSP: https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-windowsai
- Update Policy CSP: https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-update
- News and Interests / Widgets Policy CSP: https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-newsandinterests
- Experience Policy CSP: https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-experience
- Microsoft Edge browser policies: https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies
- Edge StartupBoostEnabled policy: https://learn.microsoft.com/en-us/deployedge/microsoft-edge-browser-policies/startupboostenabled
- Edge BackgroundModeEnabled policy: https://learn.microsoft.com/en-us/deployedge/microsoft-edge-browser-policies/backgroundmodeenabled
- Win32 maximum path length / LongPathsEnabled: https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation
- Windows Developer Mode: https://learn.microsoft.com/en-us/windows/advanced-settings/developer-mode
- ADMX WinInit / Hiberboot policy: https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-admx-wininit

---

## Disclaimer

This is an unofficial community/scripted configurator. Use at your own risk. Before running it on your main system, test it in a VM, back up important data, and run `-Mode Audit`.

---

## GitHub Actions / CI

The repository uses GitHub Actions to run a full quality gate on every push and pull request.

Workflow file:

```text
.github/workflows/powershell-check.yml
```

The workflow performs:

- **Syntax Check:** parses `.ps1` files in both `pwsh` and Windows PowerShell 5.1.
- **PSScriptAnalyzer:** runs static code analysis and fails on warnings or errors.
- **Pester Tests:** runs unit tests for internal functions.
- **Forbidden Patterns:** scans for dangerous patterns such as `Invoke-Expression`, `DownloadString`, base64, etc.
- **Dry-run Audit:** runs the script in `Audit` mode without modifying the runner.
- **GUI Self-test:** runs `Win11-25H2-CalmMode-GUI.ps1 -SelfTest` under Windows PowerShell 5.1.
