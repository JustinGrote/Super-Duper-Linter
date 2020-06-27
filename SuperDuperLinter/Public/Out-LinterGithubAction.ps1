using namespace System.Collections.Generic

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
        [Parameter(Mandatory,ValueFromPipeline)][Hashtable[]]$LinterResult,
        #Path to the github workspace path. This is required due to 
        [String]$GithubWorkspacePath
    )
    begin {
        $linters = [List[HashTable]]::new()
    }
    process {
        $LinterResult.foreach{
            [void]$linters.Add($PSItem)
        }
        $ansi = Get-GHAAnsi
    }
    end {
        $groupedLinters = $linters | Group-Object Name -AsHashTable
        #TODO: REFACTOR use .values and then sort by name then this more convoluted method
        $sortedLinterNames = $groupedLinters.keys | Sort-Object -unique

        foreach ($linterName in $sortedLinterNames) {
            [int]$indentCount = 3
            [string]$indent = ' '*3
            $linterGroup = $groupedLinters[$linterName]
            $failedSymbol = "`u{274C}"
            $successSymbol = "`u{2705}"
            #If any test failed, set the aggregate of the linter to failed
            $statusicon = ($linterGroup.status -notmatch 'success') ? $failedSymbol : $successSymbol
            GHAGroup ("[$statusicon] " + $linterName) {
                foreach ($linter in $linterGroup) {
                    $statusicon = ($linter.status -ne 'success') ? $failedSymbol : $successSymbol
                    #Enable problem matcher if present
                    
                    #Get the longest line and use that as the width for the header
                    $linterHasMultipleFiles = @($linter.filesToLint).count -gt 1

                    if ($linterHasMultipleFiles) {
                        $headerwidth = ($linter.filesToLint.foreach{$_.length} | Measure-Object -Maximum).maximum

                        Write-Host ($ansi.Yellow + '='*$headerwidth)
                        Write-Host ($ansi.yellow + "$indent$statusicon File Group")
                    } else {
                        Write-Host -NoNewLine "$indent${statusicon} "
                    }

                    $linter.filesToLint.foreach{
                        Write-Host $PSItem
                    }
                    
                    if ($linterHasMultipleFiles) {
                        Write-Host ($ansi.yellow + ('='*$headerwidth) + $ansi.reset)
                    }

                    #Output the appropriate lintes with the appropriate file matcher
                    if ($linter.status -ne 'success' -and $linter.problemMatcher) {
                        Enable-ProblemMatcher $Linter.problemMatcher -Destination $matcherFilePath
                    }
                    try {
                        $linterOutput = $linter.name -eq 'powershell' ? (
                            $linter.result | Format-Table -prop ScriptName,RuleName,Severity,Message | Out-String
                        ):(
                            $linter.result | Format-List | Out-String
                        )
                        Write-Host $linterOutput
                    } catch {
                        Write-Error $PSItem
                    } finally {
                        if ($linter.status -ne 'success' -and $linter.problemMatcher) {
                            Disable-ProblemMatcher
                        }
                    }
                }
                
            }
        }
    }
}
