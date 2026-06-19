# Security Policy

## Scope

Win11 25H2 CalmMode is a PowerShell tool that reads and (in `Apply` mode) writes
Windows policy/registry values. It deliberately does **not** disable Microsoft Defender,
Windows Firewall, the Windows Update service, UAC, or remove core components, and it never
downloads or executes remote code.

Security-relevant concerns for this project include, for example:
- a tweak that weakens system security beyond what is documented;
- a change that breaks Windows Update, servicing, activation, Store, or WebView2;
- any path that could execute untrusted code or hide behavior from the user;
- a release artifact that ships unexpected/sensitive files.

## Supported versions

Only the latest released version receives fixes. The current version is tracked in the
[`VERSION`](VERSION) file.

## Reporting a vulnerability

Please report suspected security issues **privately**, not in public issues:

1. Open a GitHub **Security Advisory** ("Report a vulnerability") on this repository, or
2. Contact the maintainer privately through the repository profile.

When reporting, include:
- affected version (`VERSION`) and Windows build/edition;
- the parameter/toggle and registry path involved;
- expected vs. actual behavior, and the security impact;
- reproduction steps (an `Audit`-mode report or `.reg`/log excerpt helps).

Please do not include personal data or full unredacted reports.

## Verifying release integrity

Each release ships a SHA256 checksum. Verify before running:

```powershell
Get-FileHash .\Win11-25H2-CalmMode-v<version>.zip -Algorithm SHA256
# compare against Win11-25H2-CalmMode-v<version>.zip.sha256 / checksums.txt
```

## Safe usage

- Run `-Mode Audit` first; it does not modify the system.
- Test on a VM or spare install before applying to a primary machine.
- `Apply` creates a registry backup and a per-value `rollback.reg`; note that registry
  rollback does **not** restore removed Appx packages.
