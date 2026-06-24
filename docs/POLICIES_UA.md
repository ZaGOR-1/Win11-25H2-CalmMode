# Політики Та Registry Areas

[← README](../README.md) · [English](POLICIES_EN.md)

Цей файл описує основні блоки, які налаштовує скрипт. Повний машинний каталог можна отримати так:

```powershell
.\Win11-25H2-CalmMode.ps1 -ExportCatalog
```

## Windows AI / Recall / Copilot

| Area | Приклади значень | Призначення |
|---|---|---|
| `WindowsAI` policy | `AllowRecallEnablement=0`, `DisableAIDataAnalysis=1`, `DisableClickToDo=1` | Обмежити Recall / Click to Do / AI-аналіз, де підтримується |
| Paint policies | `DisableCocreator=1`, `DisableGenerativeFill=1`, `DisableImageCreator=1` | Вимкнути AI-функції Paint |
| Copilot legacy/UI | `TurnOffWindowsCopilot=1`, `ShowCopilotButton=0` | Сховати або вимкнути legacy Copilot поверхню |
| Copilot app removal request | `RemoveMicrosoftCopilotApp=1` | Best-effort policy-запит на видалення Copilot app |

Частина WindowsAI policies build/edition-limited, тому звіт може показувати `RequiresVerification` або `MaybeIgnoredOnEdition`.

## Widgets / News

| Path | Name | Value | Призначення |
|---|---|---:|---|
| `HKLM:\SOFTWARE\Policies\Microsoft\Dsh` | `AllowNewsAndInterests` | `0` | Вимкнути Widgets / News and Interests |
| `HKLM:\SOFTWARE\Policies\Microsoft\Dsh` | `DisableWidgetsBoard` | `1` | Вимкнути дошку віджетів, де підтримується |
| `HKLM:\SOFTWARE\Policies\Microsoft\Dsh` | `DisableWidgetsOnLockScreen` | `1` | Вимкнути віджети на lock screen |
| `HKCU:\...\Explorer\Advanced` | `TaskbarDa` | `0` | Сховати кнопку Widgets |

## Cloud Content / Ads / Recommendations

Блок зменшує Windows consumer experiences, Spotlight, third-party suggestions, tailored experiences і ContentDeliveryManager toggles.

Приклади:

- `DisableWindowsConsumerFeatures=1`
- `DisableSoftLanding=1`
- `DisableCloudOptimizedContent=1`
- `DisableThirdPartySuggestions=1`
- `DisableTailoredExperiencesWithDiagnosticData=1`
- ContentDeliveryManager `SubscribedContent-*Enabled=0`

## Privacy / Diagnostics

| Path | Name | Value | Призначення |
|---|---|---:|---|
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo` | `DisabledByGroupPolicy` | `1` | Вимкнути Advertising ID policy |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo` | `Enabled` | `0` | Вимкнути Advertising ID для користувача |
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection` | `AllowTelemetry` | `1` | Required diagnostic data на Home/Pro |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy` | `TailoredExperiencesWithDiagnosticDataEnabled` | `0` | Вимкнути tailored experiences |

`AllowTelemetry=0` не є універсальним для Home/Pro, тому default - `1`.

## Search

| Path | Name | Value | Призначення |
|---|---|---:|---|
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search` | `EnableDynamicContentInWSB` | `0` | Вимкнути Search highlights |
| same | `AllowCloudSearch` | `0` | Вимкнути cloud search |
| same | `AllowSearchToUseLocation` | `0` | Вимкнути location-aware search |
| same | `DisableWebSearch` | `1` | Вимкнути web search, де підтримується |
| same | `ConnectedSearchUseWeb` | `0` | Не використовувати web results |
| `HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer` | `DisableSearchBoxSuggestions` | `1` | Вимкнути suggestions у Explorer/Start |

## Start / Taskbar / Explorer

Приклади:

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

`SearchboxTaskbarMode` для Windows 11 зберігається в:

```text
HKCU:\Software\Microsoft\Windows\CurrentVersion\Search
```

## Windows Update

Скрипт **не вимикає Windows Update service**.

| Name | Value | Призначення |
|---|---:|---|
| `NoAutoUpdate` | `0` | Windows Update лишається увімкненим |
| `AUOptions` | `2` | Opt-in ручний режим оновлень |
| `NoAutoRebootWithLoggedOnUsers` | `1` | Уникати авто-restart під час сесії |
| `ExcludeWUDriversInQualityUpdate` | `1` | Не включати драйвери в Windows Update |
| `SetAllowOptionalContent` | `0` | Не отримувати optional/CFR автоматично |
| `DeferFeatureUpdates*` | configured | Відкладення feature updates |
| `DeferQualityUpdates*` | configured | Відкладення quality updates |
| `TargetReleaseVersion*` | opt-in | Закріплення feature version, default off |

`AUOptions=2` означає, що користувач має вручну підтверджувати завантаження/інсталяцію оновлень.

## Delivery Optimization

`DODownloadMode=0` переводить Delivery Optimization у HTTP-only режим без peer-to-peer.

## Microsoft Edge Quiet Mode

Приклади:

- `StartupBoostEnabled=0`
- `BackgroundModeEnabled=0`
- `HideFirstRunExperience=1`
- `LaunchEdgeOnWindowsStartupEnabled=0`
- `PromotionalTabsEnabled=0`
- `HubsSidebarEnabled=0`

## Developer Mode / Long Paths

Developer Mode і sideloading вимкнені за замовчуванням. Це security trade-off.

Long paths:

```text
HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem\LongPathsEnabled = 1
```

## Fast Startup / Power

Скрипт вимикає Fast Startup / Hybrid Boot, але **не вимикає hibernation повністю**.

```text
HiberbootEnabled = 0
```

## Gaming

Вимикає background capture / Game DVR / стартову панель Game Bar:

- `AppCaptureEnabled=0`
- `GameDVR_Enabled=0`
- `ShowStartupPanel=0`

## Appx Cleanup

Appx cleanup за замовчуванням вимкнений. Opt-in targets:

| Target | Patterns |
|---|---|
| Microsoft Copilot app | `*Copilot*`, `Microsoft.Copilot*` |
| Microsoft Teams personal | `MSTeams*`, `MicrosoftTeams*` |
| Xbox apps | `Microsoft.Xbox*`, `Microsoft.GamingApp*`, overlays |
| OneDrive | `OneDriveSetup.exe /uninstall` |

Registry rollback не повертає Appx/provisioned packages.

## Чого Скрипт Не Робить

```text
- не вимикає Microsoft Defender;
- не вимикає Windows Firewall;
- не вимикає Windows Update service;
- не видаляє Microsoft Store;
- не видаляє Edge або WebView2;
- не видаляє .NET / VC++ runtimes / сертифікати;
- не блокує Microsoft domains через hosts;
- не вимикає UAC;
- не вимикає системні служби пачками.
```

## Official References

- WindowsAI Policy CSP: https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-windowsai
- Update Policy CSP: https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-update
- News and Interests / Widgets Policy CSP: https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-newsandinterests
- Experience Policy CSP: https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-experience
- Microsoft Edge browser policies: https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies
- Win32 maximum path length: https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation
- Windows Developer Mode: https://learn.microsoft.com/en-us/windows/advanced-settings/developer-mode
