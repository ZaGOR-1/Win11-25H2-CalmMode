# Policies And Registry Areas

[← README](../README_EN.md) · [Українською](POLICIES_UA.md)

This file summarizes the main blocks configured by the script. The full machine-readable catalog is available through:

```powershell
.\Win11-25H2-CalmMode.ps1 -ExportCatalog
```

## Windows AI / Recall / Copilot

| Area | Example values | Purpose |
|---|---|---|
| `WindowsAI` policy | `AllowRecallEnablement=0`, `DisableAIDataAnalysis=1`, `DisableClickToDo=1` | Limit Recall / Click to Do / AI analysis where supported |
| Paint policies | `DisableCocreator=1`, `DisableGenerativeFill=1`, `DisableImageCreator=1` | Disable Paint AI features |
| Copilot legacy/UI | `TurnOffWindowsCopilot=1`, `ShowCopilotButton=0` | Hide or disable legacy Copilot surfaces |
| Copilot app removal request | `RemoveMicrosoftCopilotApp=1` | Best-effort policy request for Copilot app removal |

Some WindowsAI policies are build/edition-limited, so reports may show `RequiresVerification` or `MaybeIgnoredOnEdition`.

## Widgets / News

| Path | Name | Value | Purpose |
|---|---|---:|---|
| `HKLM:\SOFTWARE\Policies\Microsoft\Dsh` | `AllowNewsAndInterests` | `0` | Disable Widgets / News and Interests |
| `HKLM:\SOFTWARE\Policies\Microsoft\Dsh` | `DisableWidgetsBoard` | `1` | Disable Widgets board where supported |
| `HKLM:\SOFTWARE\Policies\Microsoft\Dsh` | `DisableWidgetsOnLockScreen` | `1` | Disable Widgets on lock screen |
| `HKCU:\...\Explorer\Advanced` | `TaskbarDa` | `0` | Hide Widgets button |

## Cloud Content / Ads / Recommendations

This block reduces Windows consumer experiences, Spotlight, third-party suggestions, tailored experiences, and ContentDeliveryManager toggles.

Examples:

- `DisableWindowsConsumerFeatures=1`
- `DisableSoftLanding=1`
- `DisableCloudOptimizedContent=1`
- `DisableThirdPartySuggestions=1`
- `DisableTailoredExperiencesWithDiagnosticData=1`
- ContentDeliveryManager `SubscribedContent-*Enabled=0`

## Privacy / Diagnostics

| Path | Name | Value | Purpose |
|---|---|---:|---|
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo` | `DisabledByGroupPolicy` | `1` | Disable Advertising ID by policy |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo` | `Enabled` | `0` | Disable Advertising ID for current user |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection` | `AllowTelemetry` | `1` | Required diagnostic data on Home/Pro |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy` | `TailoredExperiencesWithDiagnosticDataEnabled` | `0` | Disable tailored experiences |

`AllowTelemetry=0` is not universal on Home/Pro, so the default is `1`.

## Search

| Path | Name | Value | Purpose |
|---|---|---:|---|
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search` | `EnableDynamicContentInWSB` | `0` | Disable Search highlights |
| same | `AllowCloudSearch` | `0` | Disable cloud search |
| same | `AllowSearchToUseLocation` | `0` | Disable location-aware search |
| same | `DisableWebSearch` | `1` | Disable web search where supported |
| same | `ConnectedSearchUseWeb` | `0` | Do not use web results |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer` | `DisableSearchBoxSuggestions` | `1` | Disable suggestions in Explorer/Start |

## Start / Taskbar / Explorer

Examples:

- `HideRecommendedSection=1`
- `HideRecommendedPersonalizedSites=1`
- `HideRecentlyAddedApps=1`
- `HideFrequentlyUsedApps=1`
- `TaskbarAl=0`
- `SearchboxTaskbarMode=0/1/2`
- `Start_AccountNotifications=0`
- `DisableAccountNotifications=1`
- `HideFileExt=0`
- `ShowSyncProviderNotifications=0`
- `LaunchTo=1`

On Windows 11, `SearchboxTaskbarMode` lives under:

```text
HKCU:\Software\Microsoft\Windows\CurrentVersion\Search
```

## Windows Update

The script **does not disable the Windows Update service**.

| Name | Value | Purpose |
|---|---:|---|
| `NoAutoUpdate` | `0` | Keeps Windows Update enabled |
| `AUOptions` | `2` | Opt-in manual update mode |
| `NoAutoRebootWithLoggedOnUsers` | `1` | Avoid auto-restart during a user session |
| `ExcludeWUDriversInQualityUpdate` | `1` | Exclude drivers from Windows Update |
| `SetAllowOptionalContent` | `0` | Do not automatically receive optional/CFR content |
| `DeferFeatureUpdates*` | configured | Feature update deferral |
| `DeferQualityUpdates*` | configured | Quality update deferral |
| `TargetReleaseVersion*` | opt-in | Feature version pinning, default off |

`AUOptions=2` means the user must manually approve update download/installation.

## Delivery Optimization

`DODownloadMode=0` sets Delivery Optimization to HTTP-only mode without peer-to-peer.

## Microsoft Edge Quiet Mode

Examples:

- `StartupBoostEnabled=0`
- `BackgroundModeEnabled=0`
- `HideFirstRunExperience=1`
- `LaunchEdgeOnWindowsStartupEnabled=0`
- `PromotionalTabsEnabled=0`
- `HubsSidebarEnabled=0`

## Developer Mode / Long Paths

Developer Mode and sideloading are disabled by default. This is a security trade-off.

Long paths:

```text
HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem\LongPathsEnabled = 1
```

## Fast Startup / Power

The script disables Fast Startup / Hybrid Boot, but **does not disable hibernation entirely**.

```text
HiberbootEnabled = 0
```

## Gaming

Disables background capture / Game DVR / Game Bar startup panel:

- `AppCaptureEnabled=0`
- `GameDVR_Enabled=0`
- `ShowStartupPanel=0`

## Appx Cleanup

Appx cleanup is disabled by default. Opt-in targets:

| Target | Patterns |
|---|---|
| Microsoft Copilot app | `*Copilot*`, `Microsoft.Copilot*` |
| Microsoft Teams personal | `MSTeams*`, `MicrosoftTeams*` |
| Xbox apps | `Microsoft.Xbox*`, `Microsoft.GamingApp*`, overlays |
| OneDrive | `OneDriveSetup.exe /uninstall` |

Registry rollback does not restore Appx/provisioned packages.

## What The Script Does Not Do

```text
- does not disable Microsoft Defender;
- does not disable Windows Firewall;
- does not disable the Windows Update service;
- does not remove Microsoft Store;
- does not remove Edge or WebView2;
- does not remove .NET / VC++ runtimes / certificates;
- does not block Microsoft domains through hosts;
- does not disable UAC;
- does not mass-disable system services.
```

## Official References

- WindowsAI Policy CSP: https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-windowsai
- Update Policy CSP: https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-update
- News and Interests / Widgets Policy CSP: https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-newsandinterests
- Experience Policy CSP: https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-experience
- Microsoft Edge browser policies: https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies
- Win32 maximum path length: https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation
- Windows Developer Mode: https://learn.microsoft.com/en-us/windows/advanced-settings/developer-mode
