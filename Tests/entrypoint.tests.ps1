#requires -modules @{ModuleName='Pester';ModuleVersion='5.0.0'}
Describe 'EntryPoint' -Tag Integration {
    BeforeAll {
        $Mocks = Resolve-Path "$PSScriptRoot/Mocks"
        $ErrorActionPreference = 'Stop'
    }
    It 'Runs' {
        $linters = . $PSScriptRoot/../entrypoint.ps1 -Path $Mocks/codeToLint
        $pwshlinter = $linters | where name -eq 'powershell'
        $pwshlinter.name | Should -be 'powershell'
        $pwshlinter.result[0] | Should -BeOfType [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]
        $pwshlinter.status | Should -be 'failure'
    }
}