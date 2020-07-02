using namespace System.Collections.Generic
using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic

function Out-LinterGithubAction {
    <#
    .SYNOPSIS
    Outputs in Github Action annotated format
    .DESCRIPTION
    This enables Github problem matchers as well as applies special formatting to optimize Github Action output
    #>
    [CmdletBinding()]
    param (
        #Linter Result objects from Invoke-Linter
        [Parameter(ValueFromPipeline)]$LinterIssue
    )
    begin {
        $ansi = Get-GHAAnsi
        $linters = [List[LinterIssue]]::new()
    }
    process {
        #We collect all the linter results so we can sort them prior to output
        $LinterIssue.foreach{
            [void]$linters.Add($PSItem)
        }
    }
    end {
        #Do not process if no issues were provided
        if ($linters.count -eq 0) {return}
        $groupedLinters = $linters | Group-Object LinterName -AsHashTable
        #TODO: REFACTOR use .values and then sort by name then this more convoluted method
        $sortedLinterNames = $groupedLinters.keys | Sort-Object

        foreach ($linterName in $sortedLinterNames) {
            [int]$indentCount = 3
            [string]$indent = ' '*$indentCount
            $linterGroup = $groupedLinters[$linterName]
            $severitySymbol = @{
                error = "`u{274C}"
                warning = "`u{26A0}`u{FE0F}"
                information = "`u{1F4DD}"
            }

            #If any test failed, set the aggregate of the linter to failed
            $loopMatch = $false
            $groupStatus = ('error','warning','information').foreach{
                #TODO: Figure out why "break" isn't confined to the inner loop here and exits the full loop
                if (-not $loopMatch) {
                    if ($PSItem -in $linterGroup.Severity) {
                        $PSItem
                        $loopMatch = $true
                    }
                }
            }
            $groupStatusIcon = $severitySymbol[$groupStatus]
            GHAGroup ("[$groupStatusIcon] " + $linterName) {
                #TODO: Make this a custom view
                #TODO: Make this an enum and a function
                $sevPriority = @{
                    error=0
                    warning=1
                    information=2
                }
                $linterGroup
                | Sort-Object   {$sevPriority[[String]($PSItem.severity)]},
                                scriptpath,
                                line,
                                rulename
                | Select-Object @{
                        N='Sev'
                        E={
                            $severitySymbol[[String]$PSItem.severity]
                        }
                    },
                    scriptpath,
                    line,
                    column,
                    @{
                        N='Code'
                        E={
                            $PSItem.RuleName
                        }
                    },
                    message
                | Format-Table -autosize -wrap
                | Out-String 
                | Write-Host
            }
        }
    }
}
