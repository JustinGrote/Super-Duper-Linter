#!/usr/bin/pwsh
#requires -version 7 -module powershell-yaml
param (
    #Where your repository is located. You should rarely if ever need to change this, the action will automatically pick it up
    [ValidateNotNullOrEmpty()][String]$BasePath = (Get-Content -ErrorAction 'SilentlyContinue' -Path ENV:GITHUB_WORKSPACE || '/github/workspace'),
    #Path to the file(s) or directories to lint. Wildcards are supported
    [String[]]$Path = (Get-Content -ErrorAction 'SilentlyContinue' -Path ENV:INPUT_PATH || '.'),
    #Explicit file paths to exclude, relative to your root directory. Wildcards are *not* supported
    [String[]]$ExcludePath = $ENV:INPUT_INCLUDE -split '[ ;,\n]',
    #Files patterns to include. Wildcards are supported.
    [String[]]$Include = $ENV:INPUT_INCLUDE -split '[ ;,\n]',
    #Files patterns to exclude. Wildcards are supported.
    [String[]]$Exclude = $ENV:INPUT_EXCLUDE -split '[ ;,\n]',
    #Where to find the language definitions. Definitions are evaluated in order, with the first one found being accepted
    [String[]]$LinterDefinitionPath = "$PSScriptRoot/linters",
    #The filename of your linter definition. This usually does not have to change
    [String[]]$LinterDefinitionFileName = 'linter.yml',
    #Name(s) of the linters you wish to run. Runs all by default
    [String[]]$Name = $ENV:INPUT_NAME -split '[ ;,\n]'
)
Import-Module $PSScriptRoot/Utils/GHActionUtils.psm1
Import-Module $PSScriptRoot/SuperDuperLinter/SuperDuperLinter.psm1 -Force

GHAGroup 'Environment Information' {
    Get-ChildItem env: | Foreach-Object {$_.name + '=' + $_.value}
}

GHAGroup 'Startup' {

    Push-Location -StackName basePath $basePath
    $candidatePaths = $Path.Foreach{
        Join-Path -Path $BasePath -ChildPath $PSItem -Resolve -ErrorAction stop
    }
    $excludePath = $ExcludePath.Foreach{
        Join-Path -Path $BasePath -ChildPath $PSItem -Resolve -ErrorAction stop
    }
    
    #Apply filters
    $candidatePaths = Get-Childitem -File -Recurse -Path $candidatePaths -Include $Include -Exclude $Exclude

    function Write-GHADebug {
        [CmdletBinding()]
        param(
            [Parameter(ValueFromPipeline)][String]$Message
        )
        process {
            $Message.split([Environment]::newline).foreach{
                "::debug::$PSItem"
            }
        }
    }
    New-Alias Write-Debug Write-GHADebug
}

GHAGroup 'Import Linter Definition and Identify Files To Lint' {
    $linters = Import-LinterDefinition $LinterDefinitionPath $LinterDefinitionFileName

    if ($Name) {
        $linters = $linters | Where-Object name -in $Name
    }

    $linters = $linters | Add-LinterFiles -Path $candidatePaths
}

GHAGroup 'Files to Lint' {
    Push-Location $BasePath 
    $linters.filesToLint | Sort-Object -Unique | Get-GHRelativePath
    Pop-Location
}


GHAGroup 'Run Linters' {
    [HashTable[]]$linterResult = Invoke-Linter -LinterDefinition $linters
}

#TODO: More structured output
Out-LinterGithubAction -LinterResult $LinterResult

#Set exit code to number of errors
$failureCount = $LinterResult
| Where-Object status -eq 'failure'
| Measure-Object
| Foreach-Object count

#Exit based on failures. Anything other than zero will fail the action
if ($failureCount -ne 0) {
    throw "Super Duper Linter found $failureCount errors"
} else {
    "=== Super Duper Linter Complete! ==="
}
Pop-Location -StackName basePath