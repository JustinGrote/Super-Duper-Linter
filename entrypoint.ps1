#!/usr/bin/pwsh
#requires -version 7 -module powershell-yaml
param (
    [String[]]$Path = $ENV:GITHUB_WORKSPACE,
    [String[]]$LinterDefinitionPath = "$PSScriptRoot/languages",
    [String[]]$LinterDefinitionFileName = 'linter.yml'
)

if (-not $Path) {
    $Path = '/github/workspace'
}
if (-not (Test-Path $Path)) {
    write-host -fore red "ERROR: You must mount a path containing files you wish to inspect to $Path to use the linter. If you are trying to test locally, add -v /path/to/test:/github/workspace to your docker run command"
    exit 1
}

Import-Module $PSScriptRoot/SuperDuperLinter/SuperDuperLinter.psm1 -Force

$linters = Import-LinterDefinition $LinterDefinitionPath $LinterDefinitionFileName

$linters = $linters | Add-LinterFiles -Path $Path

[HashTable[]]$linterResult = Invoke-Linter -LinterDefinition $linters

#TODO: More structured output
$linterResult.foreach{
    $statuscolor = if ($PSItem.status -eq 'success') { 'green' } else { 'red' }
    Write-Host -NoNewline "=== $($PSItem.name): "
    Write-Host -ForegroundColor $statuscolor $PSItem.status
    if ($PSItem.name -eq 'powershell') {
        Write-Host -Fore Cyan ($PSItem.result | Format-Table -prop ScriptName,RuleName,Severity,Message | Out-String)
    } else {
        Write-Host -Fore Cyan ($PSItem.result | Format-List | Out-String)
    }
    
}
