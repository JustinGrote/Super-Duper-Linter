#!/usr/bin/pwsh
param (
    $Path = $ENV:GITHUB_WORKSPACE
)
if (-not $Path) {
    $Path = '/github/workspace'
}

Invoke-ScriptAnalyzer -Path $Path
if ($?) {  
    "Successfully checked all Powershell files in $Path"
} else {
    Write-Host -fore red 'Linting Failed!'
    exit 1
}