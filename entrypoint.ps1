#!/usr/bin/pwsh
#requires -version 7 -module powershell-yaml
param (
    #Path to the file(s) or directories to lint. This defaults to your entire repository
    [String[]]$Path = $ENV:INPUT_PATH,
    #Where to find the language definitions. Definitions are evaluated in order, with the first one found being accepted
    [String[]]$LinterDefinitionPath = "$PSScriptRoot/linters",
    #The filename of your linter definition. This usually does not have to change
    [String[]]$LinterDefinitionFileName = 'linter.yml',
    #Which linters to include, by name. This will be set by the Github Action "Name" input
    [String[]]$Name = $($ENV:INPUT_NAME -split '[ ;,\n]'),
    #Enable Verbose and Debug Logging
    [Switch]$EnableDebug = $([bool]$ENV:INPUT_DEBUG)
)
Import-Module $PSScriptRoot/Utils/GHActionUtils.psm1

Push-GHAGroup 'Startup'

if ($EnableDebug) {
    #TODO: Proxy Verbose and Warning commands and send them to github
    $VerbosePreference = 'continue'
    $WarningPreference = 'continue'
}

if (-not $Path) {
    #Prepend the mount directory
    $Path = Join-Path '/github/workspace' $Path
}
if (-not (Test-Path $Path)) {
    write-host -fore red "ERROR: $Path not found. If you are trying to test locally, add -v /path/to/test:/github/workspace to your docker run command"
    exit 1
}

Import-Module $PSScriptRoot/SuperDuperLinter/SuperDuperLinter.psm1 -Force
Pop-GHAGroup #Startup

Push-GHAGroup 'Import Linter Definition and Identify Files To Lint'
$linters = Import-LinterDefinition $LinterDefinitionPath $LinterDefinitionFileName

if ($Name) {
    $linters = $linters | Where-Object name -in $Name
}

$linters = $linters | Add-LinterFiles -Path $Path
Pop-GHAGroup #Import

Push-GHAGroup 'Run Linters'
[HashTable[]]$linterResult = Invoke-Linter -LinterDefinition $linters
Pop-GHAGroup #Linters

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
