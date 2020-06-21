#requires -version 7 -modules @{ModuleName='Pester';ModuleVersion='5.0.0'}
$SCRIPT:__PesterFunctionName = $myinvocation.MyCommand.Name.split('.')[0]

Describe "$__PesterFunctionName" -Tag Unit {
    BeforeAll {
        . $(Get-ChildItem -Path $PSScriptRoot/.. -Recurse -Filter "$__PesterFunctionName.ps1")
        $Mocks = Resolve-Path "$PSScriptRoot/Mocks"
        $ErrorActionPreference = 'Stop'

        $MockLinter = @{
            Name='pester'
            FileMatch='\.pesterfile$'
        }
    }
    It 'Finds File' {
        $MockLinter
        | Add-LinterFiles -Path $Mocks/$__PesterFunctionName
        | Where Name -match 'pester'
        | Foreach-Object -MemberName filesToLint 
        | Should -match 'fileToLint.pesterfile'
    }
}