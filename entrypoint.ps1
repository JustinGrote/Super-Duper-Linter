#!/usr/bin/pwsh
#requires -module powershell-yaml,psscriptanalyzer
param (
    $Path = $ENV:GITHUB_WORKSPACE
)
if (-not $Path) {
    $Path = '/github/workspace'
}
if (-not (Test-Path $Path)) {
    write-host -fore red 'ERROR: You must mount a path containing files you wish to inspect to /github/workspace to use the linter. If you are trying to test locally, add -v /path/to/test:/github/workspace to your docker run command'
    exit
}

Invoke-ScriptAnalyzer -Path $Path
if ($?) {  
    "Successfully checked all Powershell files in $Path"
} else {
    Write-Host -fore red 'Linting Failed!'
    exit 1
}