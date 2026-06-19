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
}
