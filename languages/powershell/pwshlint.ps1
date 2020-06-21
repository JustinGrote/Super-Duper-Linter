#!/usr/bin/pwsh
param(
    [String]$SettingsPath,
    [Parameter(ValueFromRemainingArguments)][String[]]$FileToAnalyze
)
$scriptAnalyzerResults = $FileToAnalyze.foreach{
    Invoke-ScriptAnalyzer -Settings $SettingsPath -Path $PSItem
}
$scriptAnalyzerResults
exit ($scriptAnalyzerResults | where Severity -eq 'Error').count