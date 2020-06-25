#!/usr/bin/pwsh
#requires -version 7 -module powershell-yaml
[CmdletBinding()]
param (
    #Where your repository is located. You should rarely if ever need to change this, the action will automatically pick it up
    [ValidateNotNullOrEmpty()][String]$BasePath = $ENV:GITHUB_WORKSPACE ? $ENV:GITHUB_WORKSPACE : '/github/workspace',
    #Path to the file(s) or directories to lint. Wildcards are supported
    [String[]]$Path = $ENV:INPUT_PATH ? $ENV:INPUT_PATH : '.',
    #Explicit file paths to exclude, relative to your root directory. Wildcards are *not* supported
    [String[]]$ExcludePath = $ENV:INPUT_EXCLUDEPATH -split '[ ;,\n]',
    #Files patterns to include. Wildcards are supported.
    [String[]]$Include = $ENV:INPUT_INCLUDE -split '[ ;,\n]',
    #Files patterns to exclude. Wildcards are supported.
    [String[]]$Exclude = $ENV:INPUT_EXCLUDE -split '[ ;,\n]',
    #Where to find the language definitions. Definitions are evaluated in order, with the first one found being accepted
    [String[]]$LinterDefinitionPath = "$PSScriptRoot/linters",
    #The filename of your linter definition. This usually does not have to change
    [String[]]$LinterDefinitionFileName = 'linter.yml',
    #Name(s) of the linters you wish to run. Runs all by default
    [String[]]$Name = $ENV:INPUT_LINTER -split '[ ;,\n]',
    #How many linters to run concurrently. You can adjust this depending on the performance of the system you are running on. Defaults to 5
    [int]$ThrottleLimit = $ENV:INPUT_PARALLEL ? $ENV:INPUT_PARALLEL : 5,
    #Set to true to enable debug messaging for github actions. For running locally use standard debug preference variables
    [Switch]$EnableDebug = ($ENV:INPUT_DEBUG ? $ENV:INPUT_DEBUG : $ENV:RUNNER_DEBUG) -eq $true,
    #Set to true to only show items with errors in the log output
    [Switch]$ProblemsOnly = $ENV:INPUT_PROBLEMSONLY -eq $true
)

#TODO: Make a SET-GHAInputs to auto-populate parameters intelligently

Import-Module $PSScriptRoot/Utils/GHActionUtils.psm1 -Force
Import-Module $PSScriptRoot/SuperDuperLinter/SuperDuperLinter.psm1 -Force

if ($enableDebug -and $ENV:GITHUB_ACTIONS) {
    Enable-GHADebug
    Enable-GHAVerbose
    GHAGroup 'Environment Information' {
        Get-ChildItem env: | Foreach-Object {$_.name + '=' + $_.value}
    }
    GHAGroup 'Hardware Info' {
        get-content '/proc/cpuinfo'
        | Where-Object {$_ -match 'siblings|cpu cores'} 
        | Sort-Object -unique
    }
}

GHAGroup 'Startup' {
    Push-Location -StackName basePath $basePath

    # $candidatePaths = $Path.Foreach{
    #     Join-Path -Path $BasePath -ChildPath $PSItem -Resolve -ErrorAction stop
    # }
    # $excludePath = $ExcludePath.Foreach{
    #     Join-Path -Path $BasePath -ChildPath $PSItem -Resolve -ErrorAction stop
    # }

    #Apply file filters
    [String[]]$candidatePaths = Get-ChildItem -File -Recurse -Path $Path -Include $Include -Exclude $Exclude
    | Resolve-Path -Relative
    | Foreach-Object {
        #Trim the leading "./" from the paths
        $PSItem.TrimStart("./\")
    }
    | Where-Object {
        $PSItem -notin $ExcludePath
    }
    Write-Host "Startup OK!"
}

GHAGroup 'Import Linter Definition and Identify Files To Lint' {
    $linters = Import-LinterDefinition $LinterDefinitionPath $LinterDefinitionFileName

    if ($Name) {
        $linters = $linters | Where-Object name -in $Name
    }
    
    $linters = $linters | Add-LinterFiles -Path $candidatePaths
    Write-Host "Successfully imported $($linters.count) linters"
}

GHAGroup 'Files to Lint' {
    $linters.filesToLint | Sort-Object -Unique
}

GHAGroup 'Run Linters' {
    [HashTable[]]$LinterResult = Invoke-Linter -LinterDefinition $linters -ThrottleLimit 5
    if ($ProblemsOnly) {$LinterResult = $LinterResult | Where-Object status -ne 'success'}
}

#TODO: More structured output
Out-LinterGithubAction -LinterResult $LinterResult
Set-GHAOutput $LinterResult -Name Result -Depth 1

#Set exit code to number of errors
$failureCount = $LinterResult
| Where-Object status -eq 'error'
| Measure-Object
| Foreach-Object count

#Exit based on failures. Anything other than zero will fail the action
if ($failureCount -ne 0) {
    throw "Super Duper Linter found $failureCount errors"
} else {
    "=== Super Duper Linter Complete! ==="
}
Pop-Location -StackName basePath