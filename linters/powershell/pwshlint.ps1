#!/usr/bin/pwsh
param(
    [String]$SettingsPath,
    [Parameter(ValueFromRemainingArguments)][String[]]$FileToAnalyze
)
$scriptAnalyzerResults = $FileToAnalyze.foreach{
    Invoke-ScriptAnalyzer -Settings $SettingsPath -Path $PSItem
}
Write-Output $scriptAnalyzerResults

exit ($scriptAnalyzerResults | Where-Object Severity -eq 'Error').count