using namespace System.Management.Automation.Language
function Convert-CheckStyleToLinterIssue ($linterResult) {
    $record = @{
        linterName = $LinterResult.name
    }
    if ($LinterResult.stderr -as [xml]) {
        $ErrorFormatResult = $linterResult.stderr
    } elseif ($LinterResult.stdout -as [xml]) {
        $ErrorFormatResult = $linterResult.stderr
    } else {
        throw "$($LinterResult.Name): Result was not in checkstyle XML format. Please ensure you selected the correct formatter"
    }
    foreach ($checkStyleFile in ([xml]$ErrorFormatResult).checkstyle.file) {
        $record.scriptPath = $checkStyleFile.name
        #FIXME: Needs Warning and Info Handlers too
        $csLinterMap = @{
            error = 'error'
            warning = 'warning'
            info = 'information'
        }
        foreach ($severity in $cslintermap.keys) {
            $checkStyleFile.$severity.foreach{
                if ($linterResult.codeRegex) {
                    if ($PSItem.message -notmatch $LinterResult.codeRegex) {
                        Write-Error "$($linterResult.name): CodeRegex was specified but $coderegex doesn't match $($PSItem.message). Make sure you specified named capture groups with (?<message>) and (?<code>)"
                        continue
                    }
                    $record.message = ($matches['message'])
                    $record.rulename = $matches['code']
                } else {
                    #Remove unnecessary whitespace
                    $record.message = $PSItem.message
                }
    
                $record.severity = $csLinterMap.$Severity
                $record.extent = [ScriptExtent]::new(
                    [ScriptPosition]::new(
                        $record.ScriptPath,
                        $PSItem.line,
                        $PSItem.col,
                        $null
                    ),
                    $null
                )
                Write-Debug "$($LinterResult.Name) Errorformat Linter Record: $([PSCustomObject]$record | Format-List | Out-String)"
                Write-Output ([LinterIssue]$Record)
            }
        }

    }
}