#!/usr/bin/pwsh
#TFLint processes all files regardless, so we capture and filter to just the file that was being requested
#Also take the TFLint output and format it as 
[CmdletBinding()]
$Path = $args -replace '^\.[\\/]',''
[String]$Config = "$PSSCRIPTROOT/.tflint.hcl"
if (-not (Get-Command 'tflint' -ErrorAction SilentlyContinue)) {throw 'TFLint not installed or not found on the path'}

$result = & tflint -c $Config -f json $Path
$status = $LASTEXITCODE
if ($status -eq 0) {exit 0}
write-debug "TFLint Raw Output: $result"
$resultJson = $result | ConvertFrom-Json

$resultjson.issues.foreach{
    [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]@{
        message = $PSItem.Message
        severity = $PSItem.rule.severity ?? 'Warning'
        ruleName = $PSItem.rule.name
        scriptPath = $PSItem.range.filename
        extent = [Management.Automation.Language.ScriptExtent]::new(
            [System.Management.Automation.Language.ScriptPosition]::new(
                $PSItem.range.filename,
                $psitem.range.start.line,
                $psitem.range.start.column,
                $null
            ),
            [System.Management.Automation.Language.ScriptPosition]::new(
                $PSItem.range.filename,
                $psitem.range.end.line,
                $psitem.range.end.column,
                $null
            )
        )
    }
}

$resultjson.errors | Foreach-Object {
    if ($PSItem.Message -and -not $PSItem.ScriptName) {
        Write-Debug "TFLint Parse Error Detected: $($PSItem.Message)"
        $TFParseErrorRegex = "^(?<file>.+):(?<line>\d+),(?<columnstart>\d+)-(?<columnend>\d+): (?<rulename>.+); (?<message>.+)$"
        if ($PSItem.Message -match $TFParseErrorRegex) {
            if ($matches.file -notin $Path) {Write-Warning "TFLint Parse Error is in file $($matches.file) which is not in this linter file scope so skipping. Files In scope: $Path";return}
            return [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]@{
                message = $matches.Message
                severity = $PSItem.rule.severity ?? 'Error'
                ruleName = $matches.rulename ?? 'ParseError'
                scriptPath = $matches.file
                extent = [Management.Automation.Language.ScriptExtent]::new(
                    [System.Management.Automation.Language.ScriptPosition]::new(
                        $matches.file,
                        $matches.line,
                        $matches.columnstart,
                        $null
                    ),
                    [System.Management.Automation.Language.ScriptPosition]::new(
                        $matches.file,
                        $matches.line,
                        $matches.columnend,
                        $null
                    )
                )
            }
        } else {
            throw "TFLint Parse Error Detected but was not parseable by regex $TFParseErrorRegex`: $($PSItem.Message)"
        } 
    }


    [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]@{
        message = $PSItem.Message
        severity = $PSItem.rule.severity ?? 'Error'
        ruleName = $PSItem.rule.name ?? 'ParseError'
        scriptPath = $PSItem.range.filename
        extent = [Management.Automation.Language.ScriptExtent]::new(
            [System.Management.Automation.Language.ScriptPosition]::new(
                $PSItem.range.filename,
                $psitem.range.start.line,
                $psitem.range.start.column,
                $null
            ),
            [System.Management.Automation.Language.ScriptPosition]::new(
                $PSItem.range.filename,
                $psitem.range.end.line,
                $psitem.range.end.column,
                $null
            )
        )
    }
}

exit $status