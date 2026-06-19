[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '')]
param()

$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $PSScriptRoot "Win11-25H2-CalmMode.ps1"
if (-not (Test-Path $scriptPath)) {
    throw "Script not found at $scriptPath"
}

# Parse the script and dot-source only the functions to avoid running the main body
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
$functions = $ast.FindAll({$args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst]}, $true)
foreach ($func in $functions) {
    Invoke-Expression $func.Extent.Text
}

Describe "Win11-25H2-CalmMode Pure Functions" {
    Context "ConvertTo-RegFileHivePath" {
        It "converts HKLM correctly" {
            ConvertTo-RegFileHivePath "HKLM:\SOFTWARE\Test" | Should -Be "HKEY_LOCAL_MACHINE\SOFTWARE\Test"
        }
        It "converts HKCU correctly" {
            ConvertTo-RegFileHivePath "HKCU:\Software\Test" | Should -Be "HKEY_CURRENT_USER\Software\Test"
        }
        It "converts HKCR correctly" {
            ConvertTo-RegFileHivePath "HKCR:\.txt" | Should -Be "HKEY_CLASSES_ROOT\.txt"
        }
        It "converts HKU correctly" {
            ConvertTo-RegFileHivePath "HKU:\.DEFAULT" | Should -Be "HKEY_USERS\.DEFAULT"
        }
        It "leaves other paths unchanged" {
            ConvertTo-RegFileHivePath "C:\Windows" | Should -Be "C:\Windows"
        }
    }

    Context "Format-RegValueLine" {
        It "formats a Delete operation correctly" {
            Format-RegValueLine -Name "TestName" -Type "DWord" -Value 1 -Delete $true | Should -Be "`"TestName`"=-"
        }
        It "formats DWord correctly" {
            Format-RegValueLine -Name "TestName" -Type "DWord" -Value 1 -Delete $false | Should -Be "`"TestName`"=dword:00000001"
        }
        It "formats String correctly" {
            Format-RegValueLine -Name "TestName" -Type "String" -Value "TestValue" -Delete $false | Should -Be "`"TestName`"=`"TestValue`""
        }
        It "escapes backslashes and quotes in Name and String Value" {
            Format-RegValueLine -Name 'Test"Name' -Type "String" -Value 'Val\ue' -Delete $false | Should -Be '"Test\"Name"="Val\\ue"'
        }
        It "encodes a large unsigned DWord without Int32 overflow" {
            Format-RegValueLine -Name "Big" -Type "DWord" -Value 4294967295 -Delete $false | Should -Be '"Big"=dword:ffffffff'
        }
        It "encodes a negative DWord as its unsigned 32-bit pattern" {
            Format-RegValueLine -Name "Neg" -Type "DWord" -Value -1 -Delete $false | Should -Be '"Neg"=dword:ffffffff'
        }
        It "encodes a QWord as eight little-endian bytes (hex(b))" {
            Format-RegValueLine -Name "Q" -Type "QWord" -Value 1 -Delete $false | Should -Be '"Q"=hex(b):01,00,00,00,00,00,00,00'
        }
        It "encodes an ExpandString as UTF-16LE + NUL (hex(2))" {
            Format-RegValueLine -Name "E" -Type "ExpandString" -Value "%TEMP%" -Delete $false |
                Should -Be '"E"=hex(2):25,00,54,00,45,00,4d,00,50,00,25,00,00,00'
        }
        It "encodes a MultiString as NUL-terminated UTF-16LE + final NUL (hex(7))" {
            Format-RegValueLine -Name "M" -Type "MultiString" -Value @("a", "b") -Delete $false |
                Should -Be '"M"=hex(7):61,00,00,00,62,00,00,00,00,00'
        }
        It "formats a Delete for the new types the same way" {
            Format-RegValueLine -Name "Q" -Type "QWord" -Value 1 -Delete $true | Should -Be '"Q"=-'
            Format-RegValueLine -Name "M" -Type "MultiString" -Value @("a") -Delete $true | Should -Be '"M"=-'
        }
    }

    Context "Get-EditionGroup" {
        It "groups Core editions as Home" {
            Get-EditionGroup "CoreCountrySpecific" | Should -Be "Home"
            Get-EditionGroup "Core" | Should -Be "Home"
        }
        It "groups Professional as Pro" {
            Get-EditionGroup "ProfessionalWorkstation" | Should -Be "Pro"
            Get-EditionGroup "Professional" | Should -Be "Pro"
        }
        It "groups Enterprise correctly" {
            Get-EditionGroup "Enterprise" | Should -Be "Enterprise"
        }
        It "returns original ID if unknown" {
            Get-EditionGroup "SomeNewEdition" | Should -Be "SomeNewEdition"
        }
        It "returns Unknown if empty" {
            Get-EditionGroup "" | Should -Be "Unknown"
        }
    }

    Context "Test-ValueEquals" {
        It "compares DWords as integers" {
            Test-ValueEquals -A 1 -B "1" -Type "DWord" | Should -Be $true
            Test-ValueEquals -A 0 -B 1 -Type "DWord" | Should -Be $false
        }
        It "compares Strings as strings" {
            Test-ValueEquals -A "01" -B "1" -Type "String" | Should -Be $false
            Test-ValueEquals -A "Test" -B "Test" -Type "String" | Should -Be $true
        }
        It "compares large DWords without Int32 overflow" {
            Test-ValueEquals -A 4294967295 -B 4294967295 -Type "DWord" | Should -Be $true
            Test-ValueEquals -A 0 -B 4294967295 -Type "DWord" | Should -Be $false
        }
        It "compares QWords numerically" {
            Test-ValueEquals -A 5000000000 -B "5000000000" -Type "QWord" | Should -Be $true
            Test-ValueEquals -A 1 -B 2 -Type "QWord" | Should -Be $false
        }
        It "compares ExpandString as strings" {
            Test-ValueEquals -A "%TEMP%" -B "%TEMP%" -Type "ExpandString" | Should -Be $true
            Test-ValueEquals -A "%TEMP%" -B "%TMP%" -Type "ExpandString" | Should -Be $false
        }
        It "compares MultiString element-by-element and order-sensitively" {
            Test-ValueEquals -A @("a", "b") -B @("a", "b") -Type "MultiString" | Should -Be $true
            Test-ValueEquals -A @("a", "b") -B @("b", "a") -Type "MultiString" | Should -Be $false
            Test-ValueEquals -A @("a") -B @("a", "b") -Type "MultiString" | Should -Be $false
            Test-ValueEquals -A $null -B @() -Type "MultiString" | Should -Be $true
        }
    }

    Context "Get-Applicability" {
        BeforeAll {
            $script:BuildNumber = 22621
            $script:EditionGroup = "Pro"
        }

        It "returns Supported if build and edition match" {
            $setting = [pscustomobject]@{ MinBuild = 22000; Editions = @("Pro", "Enterprise"); ApplyIfMaybeUnsupported = $false }
            $res = Get-Applicability -Setting $setting
            $res.Status | Should -Be "Supported"
            $res.CanApply | Should -Be $true
        }

        It "returns UnsupportedBuild if build is too low" {
            $setting = [pscustomobject]@{ MinBuild = 26100; Editions = @(); ApplyIfMaybeUnsupported = $false }
            $res = Get-Applicability -Setting $setting
            $res.Status | Should -Be "UnsupportedBuild"
            $res.CanApply | Should -Be $false
        }

        It "returns MaybeIgnoredOnEdition if edition doesn't match" {
            $setting = [pscustomobject]@{ MinBuild = 22000; Editions = @("Enterprise"); ApplyIfMaybeUnsupported = $true }
            $res = Get-Applicability -Setting $setting
            $res.Status | Should -Be "MaybeIgnoredOnEdition"
            $res.CanApply | Should -Be $true
        }

        It "MaybeIgnoredOnEdition is not applied when ApplyIfMaybeUnsupported is false" {
            $setting = [pscustomobject]@{ MinBuild = 22000; Editions = @("Enterprise"); ApplyIfMaybeUnsupported = $false }
            $res = Get-Applicability -Setting $setting
            $res.Status | Should -Be "MaybeIgnoredOnEdition"
            $res.CanApply | Should -Be $false
        }
    }

    Context "Get-Applicability UBR gating" {
        BeforeAll {
            $script:BuildNumber = 26100
            $script:EditionGroup = "Pro"
        }

        It "blocks when UBR is known and below MinUBR" {
            $script:UBR = 3000
            $setting = [pscustomobject]@{ MinBuild = 26100; MinUBR = 3915; Editions = @("Pro"); ApplyIfMaybeUnsupported = $false }
            $res = Get-Applicability -Setting $setting
            $res.Status | Should -Be "UnsupportedBuild"
            $res.CanApply | Should -Be $false
        }

        It "allows when UBR meets MinUBR" {
            $script:UBR = 4000
            $setting = [pscustomobject]@{ MinBuild = 26100; MinUBR = 3915; Editions = @("Pro"); ApplyIfMaybeUnsupported = $false }
            $res = Get-Applicability -Setting $setting
            $res.Status | Should -Be "Supported"
            $res.CanApply | Should -Be $true
        }

        It "fails open (does not block) when UBR is unknown (0)" {
            $script:UBR = 0
            $setting = [pscustomobject]@{ MinBuild = 26100; MinUBR = 3915; Editions = @("Pro"); ApplyIfMaybeUnsupported = $false }
            $res = Get-Applicability -Setting $setting
            $res.Status | Should -Be "Supported"
            $res.CanApply | Should -Be $true
        }
    }

    Context "Get-KnownStatuses" {
        It "contains the core report statuses" {
            $known = Get-KnownStatuses
            foreach ($s in "Compliant", "WouldChange", "WouldRemove", "Skipped", "VerifyFail", "Error", "Warning") {
                $known | Should -Contain $s
            }
        }
        It "has no duplicate entries" {
            $known = Get-KnownStatuses
            ($known | Sort-Object -Unique).Count | Should -Be $known.Count
        }
    }

    Context "Get-AttentionStatuses" {
        It "contains the highlight-worthy statuses" {
            $att = Get-AttentionStatuses
            foreach ($s in "Warning", "VerifyFail", "Error", "WouldChange", "WouldRemove", "UnsupportedBuild") {
                $att | Should -Contain $s
            }
        }
        It "has no duplicate entries" {
            $att = Get-AttentionStatuses
            ($att | Sort-Object -Unique).Count | Should -Be $att.Count
        }
        It "is a subset of the known statuses" {
            $known = Get-KnownStatuses
            foreach ($s in Get-AttentionStatuses) { $known | Should -Contain $s }
        }
        It "does not flag compliant/informational statuses" {
            $att = Get-AttentionStatuses
            foreach ($s in "Compliant", "AlreadyConfigured", "Changed", "VerifyOK", "Skipped") {
                $att | Should -Not -Contain $s
            }
        }
    }

    Context "Get-ResultSummary" {
        It "counts results grouped by status" {
            $script:Results = New-Object 'System.Collections.Generic.List[object]'
            $script:Results.Add([pscustomobject]@{ Status = "Compliant" })
            $script:Results.Add([pscustomobject]@{ Status = "Compliant" })
            $script:Results.Add([pscustomobject]@{ Status = "WouldChange" })
            $summary = Get-ResultSummary
            $summary["Compliant"] | Should -Be 2
            $summary["WouldChange"] | Should -Be 1
        }
    }

    Context "Test-PendingReboot" {
        It "returns a Pending boolean and a Reasons collection" {
            $r = Test-PendingReboot
            ($r.Pending -is [bool]) | Should -Be $true
            ($r.PSObject.Properties.Name -contains "Reasons") | Should -Be $true
            if (-not $r.Pending) { @($r.Reasons).Count | Should -Be 0 }
        }
    }

    Context "Get-RegValueSafe missing value (no terminating error)" {
        It "reports Exists=false and Error=null for a missing value under an existing key" {
            # The key exists (read at startup), but this value name will not.
            $res = Get-RegValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "CalmModeNoSuchValue_$([Guid]::NewGuid().ToString('N'))"
            $res.Exists | Should -Be $false
            $res.Error | Should -Be $null
        }
        It "reports Exists=false and Error=null for a non-existent key" {
            $res = Get-RegValueSafe -Path "HKLM:\SOFTWARE\CalmModeNoSuchKey_$([Guid]::NewGuid().ToString('N'))" -Name "Whatever"
            $res.Exists | Should -Be $false
            $res.Error | Should -Be $null
        }
    }

    Context "Invoke-RegSetting read-only applicability (A1 regression)" {
        BeforeAll {
            # Pro build so an Enterprise-only tweak is MaybeIgnoredOnEdition.
            $script:BuildNumber = 22621
            $script:UBR = 0
            $script:EditionGroup = "Pro"
            # Invoke-RegSetting consults this set; it must exist in this scope.
            $script:DisabledTweaks = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        }

        # Build a setting whose target value does NOT exist, so equals is false.
        function Get-TestSetting {
            param([bool]$ApplyIfMaybeUnsupported)
            $name = "CalmModeTestValue_$([Guid]::NewGuid().ToString('N'))"
            [pscustomobject]@{
                Key = "HKLM:\SOFTWARE\CalmModeNoSuchKey\$name"
                Category = "TestCat"; Path = "HKLM:\SOFTWARE\CalmModeNoSuchKey"; Name = $name
                Type = "DWord"; Value = 1; Description = "Edition-limited test tweak"
                MinBuild = 22000; Editions = @("Enterprise"); Confidence = "Official"
                Note = "test"; ApplyIfMaybeUnsupported = $ApplyIfMaybeUnsupported; MinUBR = 0
            }
        }

        It "Verify marks an edition-skipped tweak (CanApply=false) as Skipped, not VerifyFail" {
            $script:Mode = "Verify"
            $script:Results = New-Object 'System.Collections.Generic.List[object]'
            Invoke-RegSetting -Setting (Get-TestSetting -ApplyIfMaybeUnsupported $false)
            $script:Results[-1].Status | Should -Be "Skipped"
        }

        It "Verify still reports VerifyFail for a missing applicable tweak (CanApply=true)" {
            $script:Mode = "Verify"
            $script:Results = New-Object 'System.Collections.Generic.List[object]'
            Invoke-RegSetting -Setting (Get-TestSetting -ApplyIfMaybeUnsupported $true)
            $script:Results[-1].Status | Should -Be "VerifyFail"
        }

        It "Audit marks an edition-skipped tweak as Skipped, not WouldChange" {
            $script:Mode = "Audit"
            $script:Results = New-Object 'System.Collections.Generic.List[object]'
            Invoke-RegSetting -Setting (Get-TestSetting -ApplyIfMaybeUnsupported $false)
            $script:Results[-1].Status | Should -Be "Skipped"
        }
    }

    Context "Get-RegValueSafe caching (C2)" {
        BeforeAll { $script:RegKeyCache = $null }

        It "populates the per-run cache and Clear-RegKeyCache invalidates it" {
            $path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
            $null = Get-RegValueSafe -Path $path -Name "CurrentBuild"
            $script:RegKeyCache.ContainsKey($path) | Should -Be $true
            Clear-RegKeyCache -Path $path
            $script:RegKeyCache.ContainsKey($path) | Should -Be $false
        }

        It "caches a missing key so repeated misses are cheap" {
            $missing = "HKLM:\SOFTWARE\CalmModeNoSuchKey_$([Guid]::NewGuid().ToString('N'))"
            (Get-RegValueSafe -Path $missing -Name "X").Exists | Should -Be $false
            $script:RegKeyCache.ContainsKey($missing) | Should -Be $true
        }
    }

    Context "Apply idempotency (E1)" {
        BeforeAll {
            $script:BuildNumber = 22621
            $script:UBR = 0
            $script:EditionGroup = "Pro"
            $script:DisabledTweaks = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
            $script:RegKeyCache = $null
            # Point at an existing read-only value so "current == desired" holds and Apply takes
            # the AlreadyConfigured path (which returns BEFORE any write / ShouldProcess). This
            # proves the idempotency guarantee without changing the system.
            $script:probePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
            $script:probeName = "CurrentBuild"
            $script:probeVal = (Get-RegValueSafe -Path $script:probePath -Name $script:probeName).Value
        }

        function Get-IdemSetting {
            [pscustomobject]@{
                Key = "$script:probePath\$script:probeName"
                Category = "Idem"; Path = $script:probePath; Name = $script:probeName
                Type = "String"; Value = $script:probeVal; Description = "already-correct probe"
                MinBuild = 0; Editions = @(); Confidence = "Official"
                Note = ""; ApplyIfMaybeUnsupported = $true; MinUBR = 0
            }
        }

        It "reports AlreadyConfigured (no write) on repeated Apply when already correct" {
            $script:Mode = "Apply"
            foreach ($run in 1..2) {
                $script:Results = New-Object 'System.Collections.Generic.List[object]'
                Invoke-RegSetting -Setting (Get-IdemSetting)
                $script:Results[-1].Status | Should -Be "AlreadyConfigured"
            }
        }
    }
}

# ------------------------------------------------------------------------------
# Integration tests for the config mechanism (-ExportCatalog / -ConfigPath) and
# the GUI self-test. These spawn the engine via Windows PowerShell (powershell.exe)
# because the engine requires the Desktop edition. All runs are read-only (Audit).
# ------------------------------------------------------------------------------
Describe "Config mechanism (integration)" {
    BeforeAll {
        $script:engine = Join-Path $PSScriptRoot "Win11-25H2-CalmMode.ps1"
        $sys32 = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
        $script:psExe = if (Test-Path $sys32) { $sys32 } else { "powershell.exe" }
        $script:knownStatuses = Get-KnownStatuses

        $raw = & $script:psExe -NoProfile -ExecutionPolicy Bypass -File $script:engine -ExportCatalog 2>$null
        $text = ($raw -join "`n")
        $s = $text.IndexOf("{"); $e = $text.LastIndexOf("}")
        $script:catalog = $text.Substring($s, $e - $s + 1) | ConvertFrom-Json

        $script:tempReports = Join-Path $env:TEMP ("calm-tests-" + [Guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $script:tempReports -Force | Out-Null
    }

    AfterAll {
        if ($script:tempReports -and (Test-Path $script:tempReports)) {
            Remove-Item -Recurse -Force $script:tempReports -ErrorAction SilentlyContinue
        }
    }

    # Run an Audit with a given config object and return the parsed JSON results.
    function Invoke-AuditWithConfig {
        param($ConfigObject)
        $cfg = Join-Path $env:TEMP ("calm-cfg-" + [Guid]::NewGuid().ToString("N") + ".json")
        ($ConfigObject | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $cfg -Encoding UTF8
        & $script:psExe -NoProfile -ExecutionPolicy Bypass -File $script:engine -Mode Audit -ConfigPath $cfg -ReportPath $script:tempReports *> $null
        $dir = Get-ChildItem -LiteralPath $script:tempReports -Directory -Filter "Win11-25H2-CalmMode-v*-Audit-*" |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        $json = Get-ChildItem -LiteralPath $dir.FullName -Filter "*-results.json" | Select-Object -First 1
        $results = Get-Content -LiteralPath $json.FullName -Raw | ConvertFrom-Json
        Remove-Item -LiteralPath $cfg -Force -ErrorAction SilentlyContinue
        return , @($results)
    }

    Context "-ExportCatalog" {
        It "returns at least one block and one tweak" {
            $script:catalog.Blocks.Count | Should -BeGreaterThan 0
            $script:catalog.Tweaks.Count | Should -BeGreaterThan 0
        }
        It "every tweak exposes the contract fields" {
            $t = $script:catalog.Tweaks[0]
            foreach ($p in "Key", "BlockKey", "Category", "Name", "Path", "Type", "Value", "Description", "Confidence", "MinBuild", "Editions") {
                ($t.PSObject.Properties.Name -contains $p) | Should -Be $true
            }
        }
        It "reports a non-empty script version" {
            [string]::IsNullOrWhiteSpace($script:catalog.ScriptVersion) | Should -Be $false
        }
        It "exposes a non-empty AttentionStatuses list" {
            ($script:catalog.PSObject.Properties.Name -contains "AttentionStatuses") | Should -Be $true
            @($script:catalog.AttentionStatuses).Count | Should -BeGreaterThan 0
        }
        It "gives every block a non-empty Title" {
            foreach ($b in $script:catalog.Blocks) {
                [string]::IsNullOrWhiteSpace($b.Title) | Should -Be $false
            }
        }
    }

    Context "-ConfigPath selection" {
        It "disabling a block removes all of its results" {
            $results = Invoke-AuditWithConfig @{ blocks = @{ Gaming = $false }; disabledTweaks = @() }
            (@($results | Where-Object { $_.Category -eq "Gaming" })).Count | Should -Be 0
        }

        It "disabling a single tweak reports it as Skipped" {
            $enabledKeys = ($script:catalog.Blocks | Where-Object { $_.Enabled }).Key
            $tweak = $script:catalog.Tweaks | Where-Object { $enabledKeys -contains $_.BlockKey } | Select-Object -First 1
            $results = Invoke-AuditWithConfig @{ blocks = @{}; disabledTweaks = @($tweak.Key) }
            $row = $results | Where-Object { ("$($_.Path)\$($_.Name)") -eq $tweak.Key } | Select-Object -First 1
            $row | Should -Not -BeNullOrEmpty
            $row.Status | Should -Be "Skipped"
        }

        It "emits only known statuses" {
            $results = Invoke-AuditWithConfig @{ blocks = @{}; disabledTweaks = @() }
            $bad = $results | Where-Object { $script:knownStatuses -notcontains $_.Status }
            (@($bad)).Count | Should -Be 0
        }

        It "records a Run configuration preflight row that reflects a disabled block" {
            $results = Invoke-AuditWithConfig @{ blocks = @{ Gaming = $false }; disabledTweaks = @() }
            $row = $results | Where-Object { $_.Category -eq "Preflight" -and $_.Item -eq "Run configuration" } | Select-Object -First 1
            $row | Should -Not -BeNullOrEmpty
            $row.Status | Should -Be "Compliant"
            $row.Message | Should -Match "Selection source"
            # Gaming was turned off, so it must not appear in the enabled-blocks list.
            $row.Message | Should -Not -Match "Gaming"
        }

        It "records disabled tweaks in the Run configuration row" {
            $enabledKeys = ($script:catalog.Blocks | Where-Object { $_.Enabled }).Key
            $tweak = $script:catalog.Tweaks | Where-Object { $enabledKeys -contains $_.BlockKey } | Select-Object -First 1
            $results = Invoke-AuditWithConfig @{ blocks = @{}; disabledTweaks = @($tweak.Key) }
            $row = $results | Where-Object { $_.Category -eq "Preflight" -and $_.Item -eq "Run configuration" } | Select-Object -First 1
            $row.Message | Should -Match "Disabled tweaks"
        }
    }

    Context "-Skip / -Only block selection" {
        function Get-AuditResults {
            param([string[]]$ExtraArgs)
            & $script:psExe -NoProfile -ExecutionPolicy Bypass -File $script:engine -Mode Audit -ReportPath $script:tempReports @ExtraArgs *> $null
            $dir = Get-ChildItem -LiteralPath $script:tempReports -Directory -Filter "Win11-25H2-CalmMode-v*-Audit-*" |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1
            $json = Get-ChildItem -LiteralPath $dir.FullName -Filter "*-results.json" | Select-Object -First 1
            return , @(Get-Content -LiteralPath $json.FullName -Raw | ConvertFrom-Json)
        }

        It "-Skip removes the skipped block's results" {
            $results = Get-AuditResults -ExtraArgs @("-Skip", "Gaming")
            (@($results | Where-Object { $_.Category -eq "Gaming" })).Count | Should -Be 0
        }

        It "-Only keeps the listed block and drops the others" {
            $results = Get-AuditResults -ExtraArgs @("-Only", "WindowsAI")
            (@($results | Where-Object { $_.Category -eq "Windows AI" })).Count | Should -BeGreaterThan 0
            (@($results | Where-Object { $_.Category -eq "Widgets" })).Count | Should -Be 0
        }

        It "-Skip and -Only together exit with code 1" {
            & $script:psExe -NoProfile -ExecutionPolicy Bypass -File $script:engine -Mode Audit -NoReport -Skip Gaming -Only WindowsAI *> $null
            $LASTEXITCODE | Should -Be 1
        }

        It "an unknown block key exits with code 1" {
            & $script:psExe -NoProfile -ExecutionPolicy Bypass -File $script:engine -Mode Audit -NoReport -Skip Nonsense *> $null
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "-RestoreFrom validation (no import)" {
        It "exits 1 when the path does not exist" {
            & $script:psExe -NoProfile -ExecutionPolicy Bypass -File $script:engine -RestoreFrom "Z:\does\not\exist.reg" *> $null
            $LASTEXITCODE | Should -Be 1
        }
        It "exits 1 when the folder contains no .reg file" {
            $empty = Join-Path $env:TEMP ("calm-empty-" + [Guid]::NewGuid().ToString("N"))
            New-Item -ItemType Directory -Path $empty -Force | Out-Null
            & $script:psExe -NoProfile -ExecutionPolicy Bypass -File $script:engine -RestoreFrom $empty *> $null
            $code = $LASTEXITCODE
            Remove-Item -Recurse -Force $empty -ErrorAction SilentlyContinue
            $code | Should -Be 1
        }
    }

    Context "config errors" {
        It "exits with code 1 on a missing config path" {
            & $script:psExe -NoProfile -ExecutionPolicy Bypass -File $script:engine -Mode Audit -ConfigPath "Z:\does\not\exist.json" -NoReport *> $null
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "-OpenReport switch" {
        It "is accepted and exits 0 (no HTML opened with -NoReport)" {
            # -NoReport short-circuits report writing, so -OpenReport opens nothing here:
            # this asserts the parameter exists and the run stays clean.
            & $script:psExe -NoProfile -ExecutionPolicy Bypass -File $script:engine -Mode Audit -NoReport -OpenReport *> $null
            $LASTEXITCODE | Should -Be 0
        }
    }
}

Describe "GUI self-test (integration)" {
    It "builds the tree and round-trips the config" {
        $gui = Join-Path $PSScriptRoot "Win11-25H2-CalmMode-GUI.ps1"
        $sys32 = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
        $psExe = if (Test-Path $sys32) { $sys32 } else { "powershell.exe" }
        $out = & $psExe -NoProfile -ExecutionPolicy Bypass -File $gui -SelfTest 2>&1
        ($out -join "`n") | Should -Match "SELFTEST OK"
    }
}
