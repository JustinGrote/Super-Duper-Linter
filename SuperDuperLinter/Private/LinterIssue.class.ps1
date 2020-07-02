#requires -module PSScriptAnalyzer
class LinterIssue : Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord {
    [String]$LinterName
    #These have to be redefined to not be readonly to allow the below constructor to work
    [String]$Message
    [Management.Automation.Language.IScriptExtent]$Extent
    [String]$RuleName
    [String]$RuleSuppressionID
    [String]$ScriptName
    [String]$ScriptPath
    [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticSeverity]$Severity
    [System.Collections.Generic.IEnumerable[Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent]]$SuggestedCorrections

    hidden Init([HashTable]$LinterResult) {
        $linterResult.keys.foreach{
            $this.$PSItem = $linterResult[$PSItem]
        }
    }
    LinterIssue(
        [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]$DiagnosticRecord,
        [String]$LinterName
    ) {
        $this.LinterName = $LinterName
        $DiagnosticRecord.psobject.properties.where{$PSItem.MemberType -eq 'Property'}.name.foreach{
            $this.$PSItem = $DiagnosticRecord.$PSItem
        }
    }
    LinterIssue(
        [HashTable]$LinterResult
    ) {
        $this.init($LinterResult)
    }
}