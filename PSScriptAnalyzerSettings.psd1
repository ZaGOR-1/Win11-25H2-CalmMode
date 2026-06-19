@{
    ExcludeRules = @(
        # Write-Host is intentional: this is an interactive console tool with colored status output.
        'PSAvoidUsingWriteHost',

        # False positive. These parameters ARE used (verified): they appear in string
        # interpolation (e.g. $TargetReleaseVersionInfo, $FeatureUpdateDeferralDays) and in
        # script-scoped switch checks inside helper functions (e.g. $NoAppCleanup, $SkipRestorePoint,
        # $NoRestartExplorer). PSScriptAnalyzer's dataflow cannot follow these usage patterns.
        'PSReviewUnusedParameter',

        # False positive. The Invoke-* helper functions deliberately call ShouldProcess via the
        # script-level $PSCmdlet provided by the top-level [CmdletBinding(SupportsShouldProcess=$true)].
        # PSSA expects the attribute on each function individually, which would break the single
        # shared -WhatIf/-Confirm contract used across the whole script.
        'PSShouldProcess',

        # Style only, on internal (non-exported) helper functions whose plural names read more
        # naturally (Get-AppxMatches, Write-Reports, Initialize-RegistrySettings, etc.).
        # Renaming them adds churn without changing behavior.
        'PSUseSingularNouns'
    )
}
