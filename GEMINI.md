# GEMINI.md — Project Instructions for Gemini 3.1 Pro / Antigravity CLI

## Project Identity

This project is **Win11 25H2 CalmMode** — a careful Windows 11 tuning, privacy, calm mode and policy configuration tool.

This is **not** an aggressive debloater.

The goal of the project is to make Windows 11 calmer, less noisy, more private, and more predictable while keeping the system secure, maintainable, reversible, and update-friendly.

The tool should prefer official Windows policies, registry-backed configuration, transparent reports, backup, rollback, and auditability.

## Core Principles

Always follow these principles:

1. Safety first.
2. No aggressive debloat.
3. No hidden system modifications.
4. No destructive changes without explicit opt-in.
5. Prefer policy-based configuration over deleting Windows components.
6. Always preserve security features.
7. Always preserve Windows Update functionality.
8. Always preserve rollback or clear recovery instructions.
9. Be honest about unsupported builds, editions, and best-effort tweaks.
10. Documentation must never promise more than the code actually does.

## Forbidden Changes

Never add, suggest, or implement changes that:

* Disable Microsoft Defender.
* Disable Windows Firewall.
* Disable Windows Update services.
* Disable UAC.
* Break Microsoft Store.
* Break WebView2.
* Break Windows activation, licensing, or servicing.
* Block Microsoft domains through hosts file.
* Download and execute remote scripts.
* Use encoded PowerShell commands for normal project logic.
* Hide behavior from the user.
* Remove system components aggressively.
* Make irreversible changes without warning.
* Turn the project into a generic “debloater”.

If a requested feature would violate these rules, explain the risk and propose a safer alternative.

## Working Mode

When working in this repository, act as a:

* senior PowerShell engineer,
* Windows policy reviewer,
* security-focused maintainer,
* open-source release reviewer.

Before editing code, understand the current structure and behavior.

Prefer small, reviewable changes.

Never make broad rewrites unless explicitly requested.

Never silently change public behavior.

## Command Safety

Do not run commands that modify the host Windows system.

Do not run:

* Apply mode
* registry modification commands
* Appx removal commands
* service modification commands
* destructive cleanup commands
* commands requiring Administrator privileges unless explicitly approved

Safe commands are allowed, for example:

* file listing
* grep/search
* PowerShell syntax parsing
* PSScriptAnalyzer
* Pester tests that do not touch the real system
* git diff
* reading documentation
* checking formatting

If you are unsure whether a command is safe, ask first or avoid running it.

## Expected Project Modes

The project should preserve this style of operation:

* `Audit` — inspect and report only
* `Apply` — apply safe selected changes
* `Verify` — check whether settings are applied

Rollback is currently NOT a CLI mode. `Apply` generates a per-value `rollback.reg`
and, where possible, a System Restore point. A dedicated `-RestoreFrom` mode is a
planned enhancement (see ROADMAP.md), not a shipped feature — do not document or
assume it as one.

Default behavior should be non-destructive.

Running the script without clear user intent should not unexpectedly modify the system.

## PowerShell Standards

When editing PowerShell code:

* Use clear function names.
* Keep functions focused.
* Prefer explicit parameters.
* Use strict and predictable error handling.
* Avoid global mutable state where possible.
* Keep code idempotent.
* Re-running the same command should not break the system.
* Registry writes should be centralized through helper functions.
* Reporting logic should be separated from system mutation logic where possible.
* Avoid duplicated registry logic.
* Avoid magic strings scattered across the code.
* Prefer structured policy definitions when possible.

When modifying registry logic:

* Clearly distinguish HKLM and HKCU.
* Clearly distinguish policy paths from normal user preference paths.
* Preserve old values before writing new values.
* Handle missing keys safely.
* Handle missing values safely.
* Handle permission errors clearly.
* Mark unsupported settings honestly.

## Windows Policy Rules

When adding or changing Windows policies:

* Prefer official Microsoft policy names and paths.
* Do not invent policy behavior.
* If support depends on Windows build, mark it clearly.
* If behavior may differ between Home, Pro, Enterprise, or Education editions, document it.
* If registry mapping is best-effort, label it as best-effort.
* If a setting requires verification on real Windows 11 25H2, label it as RequiresVerification.

Use the report statuses that the script actually emits (see the status table in README.md):

* Result status: `Compliant`, `WouldChange`, `WouldRemove`, `AlreadyConfigured`,
  `Changed`, `VerifyOK`, `VerifyFail`, `Skipped`, `Warning`, `Error`, `UnsupportedBuild`.
* Support / confidence labels: `Supported`, `MaybeIgnoredOnEdition`, `BestEffort`,
  `RequiresVerification`, `DeprecatedOrLegacy`, `UISetting`.

Do not introduce new status names (for example `NotConfigured`, `Applied`, `Failed`)
that the script does not produce.

## Appx / Provisioned Package Rules

Appx removal must be treated as higher risk than registry policy changes.

Do not add new Appx removal by default.

Any Appx removal should be:

* clearly documented,
* explicitly opt-in,
* reversible where realistically possible,
* excluded from normal registry rollback claims.

Always explain that registry rollback does not automatically restore removed Appx/provisioned packages.

Avoid removing components that may be required by Windows, Store, WebView2, shell experiences, authentication, security, or updates.

## Backup and Rollback Rules

Before any Apply operation, the project should create backups where possible.

Rollback documentation must be honest.

Rollback can restore registry values only if the previous state was captured correctly.

Rollback must not claim to restore things it cannot restore.

If restore point creation fails, the script should continue only if the user is clearly informed or if the behavior is documented.

## Reporting Rules

Reports should be clear and useful.

Preserve or improve:

* JSON report
* CSV report
* HTML report
* console summary
* status per tweak/policy
* skipped/unsupported/failed states
* warnings for best-effort settings

Reports should not hide failures.

Reports should distinguish:

* applied
* already configured
* skipped
* unsupported
* failed
* requires manual verification

## Documentation Rules

Documentation should be clear enough for a normal Windows power user.

README should include:

* what the tool does
* what the tool does not do
* supported Windows versions
* safety notes
* examples
* Audit / Apply / Verify / Rollback explanation
* known limitations
* Appx removal limitations
* restore point limitations
* release verification instructions
* troubleshooting

Do not make marketing claims that are stronger than the implementation.

Avoid words like “guaranteed”, “fully disables”, or “permanently fixes” unless they are technically true.

Prefer wording like:

* “attempts to”
* “best-effort”
* “policy-backed where supported”
* “may be ignored on some editions”
* “requires verification on this build”

## Release Hygiene

Release archives should not include:

* `.git`
* local settings
* `.claude/settings.local.json`
* temporary reports
* local logs
* cache files
* test output
* secrets
* personal machine paths

Recommend or maintain `.gitignore` entries for local-only files.

Release should ideally include:

* README.md
* LICENSE
* CHANGELOG.md
* main script files
* docs
* examples
* checksums

## CI and Tests

Prefer adding or improving:

* PowerShell syntax check
* PSScriptAnalyzer
* Pester tests
* tests for helper functions
* tests for registry path conversion
* tests for report generation
* tests for policy applicability logic
* release checklist workflow

Tests must not modify the real machine.

Use mocks for registry, Appx, restore point, and admin checks.

## Review Behavior

When asked to review the project, respond with:

1. Overall score.
2. Strong points.
3. Critical issues.
4. High-priority issues.
5. Medium-priority improvements.
6. Low-priority polish.
7. Documentation fixes.
8. Code fixes.
9. CI/test recommendations.
10. Safe implementation plan.

Be direct and practical.

Do not overpraise weak code.

Do not invent bugs.

If something cannot be verified statically, say so.

## Implementation Behavior

When asked to implement fixes:

* Start with the smallest safe patch.
* Explain what files will change.
* Do not change unrelated behavior.
* Preserve existing public commands unless asked otherwise.
* Update docs if behavior changes.
* Update changelog if the change is user-facing.
* After editing, show a concise diff summary.
* Suggest tests to run.

## Preferred Style

Use clear, maintainable, boring code.

Do not be clever.

Do not optimize prematurely.

Avoid huge functions.

Avoid hidden side effects.

Prefer readable implementation over short implementation.

## Final Reminder

This project edits sensitive Windows configuration.

Every change must be safe, explainable, reversible where possible, and documented.

The correct direction is:

careful Windows tuning,
not aggressive debloating.
