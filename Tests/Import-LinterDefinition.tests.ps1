#requires -modules @{ModuleName='Pester';ModuleVersion='5.0.0'}
$SCRIPT:__PesterFunctionName = $myinvocation.MyCommand.Name.split('.')[0]

Describe "$__PesterFunctionName" -Tag Unit {
    BeforeAll {
        . $(Get-ChildItem -Path $PSScriptRoot/.. -Recurse -Filter "$__PesterFunctionName.ps1")
        $Mocks = Resolve-Path "$PSScriptRoot/Mocks"
        $ErrorActionPreference = 'Stop'
    }
    Context 'Single' {
        BeforeAll {
            $LinterDefinition = Import-LinterDefinition $Mocks/linters/OneLinter
        }
        It 'Imports Definitions' {
            $LinterDefinition | Should -Not -BeNullOrEmpty
        }
        It 'Name' {
            $LinterDefinition.name | Should -Be 'pester'
    
        }
        It 'Path' {
            $LinterDefinition.path | Should -BeLike '*linter.yml'
        }
    }

    Context 'Multiple' {
        BeforeAll {
            $LinterDefinition = Import-LinterDefinition $Mocks/linters/OneLinter,$Mocks/linters/ManyLinter
        }
        It 'Imports Definitions' {
            $LinterDefinition | Should -Not -BeNullOrEmpty
        }
        It 'Name' {
            $LinterDefinition.foreach{
                $_.name | Should -BeIn 'pester','pester2','pester3'
            }
        }
    }

}