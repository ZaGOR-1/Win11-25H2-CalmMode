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
