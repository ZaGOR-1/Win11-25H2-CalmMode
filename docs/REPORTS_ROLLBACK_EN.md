# Reports, Statuses, And Rollback

[← README](../README_EN.md) · [Українською](REPORTS_ROLLBACK_UA.md)

## Reports

Each run creates a folder:

```text
Win11-25H2-CalmMode-v<version>-<Mode>-YYYY-MM-DD_HH-MM-SS
```

It contains:

```text
Win11-25H2-CalmMode-v<version>-report.html
Win11-25H2-CalmMode-v<version>-results.csv
Win11-25H2-CalmMode-v<version>-results.json
Win11-25H2-CalmMode-v<version>.log
rollback.reg                 # Apply only
```

The HTML report has a **Needs attention** section that checks `Status`, `Support`, and `Confidence`.

## Statuses

| `Status` | Meaning |
|---|---|
| `Compliant` | Value is already correct in `Audit` |
| `WouldChange` | In `Audit`, the value would be changed |
| `WouldRemove` | In `Audit`, the package would be removed |
| `AlreadyConfigured` | In `Apply`, no write is needed |
| `Changed` | In `Apply`, the value was written and verified |
| `VerifyOK` | In `Verify`, the desired value is present |
| `VerifyFail` | In `Verify`, the desired value is missing or different |
| `Skipped` | Skipped due to parameters, config, or applicability |
| `Warning` | Non-critical warning |
| `Error` | Write or verification error |

| `Support` / `Confidence` | Meaning |
|---|---|
| `UnsupportedBuild` | Does not apply to the current build |
| `MaybeIgnoredOnEdition` | Windows may ignore it on the current edition |
| `BestEffort` | Best-effort behavior depends on build/package state |
| `RequiresVerification` | Verify after Apply |
| `DeprecatedOrLegacy` | Deprecated or legacy policy |
| `UISetting` | UI tweak, not a full device policy |

## Exit Codes

| Code | Meaning |
|---:|---|
| `0` | No critical errors; `Verify` passed |
| `1` | Parameter or preflight error |
| `2` | `Verify` found `VerifyFail` |

## Rollback

In `Apply`, the script creates `rollback.reg`. To restore:

```powershell
.\Win11-25H2-CalmMode.ps1 -RestoreFrom "C:\Path\To\ReportFolder"
```

If a folder is passed, it must contain `rollback.reg`. Any other `.reg` must be passed as a direct file path:

```powershell
.\Win11-25H2-CalmMode.ps1 -RestoreFrom "C:\Path\To\backup.reg"
```

Rollback restores **registry values only**. It does not restore removed Appx/provisioned packages.

## Manual Verification

```powershell
Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
gpresult /h "$env:USERPROFILE\Desktop\gpresult.html"
```

`VerifyOK` means the registry/policy value exists. It does not always guarantee that the Windows UI fully honors a policy, especially for edition/build-limited items.
