using namespace System.Management.Automation.Language
using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic
function Format-LinterResult {
    param (
        [HashTable]$LinterResult,
        [ValidateSet('Simple')]$matchMethod = 'Simple'
    )

    $record = @{
        severity = 'Information'
        LinterName = $LinterResult.name
    }
    Import-Module PSScriptAnalyzer

    #Compatibility: If a problemMatcher was defined, set the matchmethod to problemMatcher
    if (-not $LinterResult.matchmethod -and $LinterResult.problemMatcher) {
        $LinterResult.matchmethod = 'problemMatcher'
    }
    #Default if any of the above are unset
    $linterResult.matchMethod ??= $matchMethod

    Write-Verbose "Processing $($LinterResult.Name) result with $($linterResult.matchMethod) method"

    if ($linterResult.matchmethod -ne 'powershell') {
        [String]$combinedOutput = ($linterResult.stdOut + $linterResult.stdErr) -join [Environment]::NewLine
    }

    switch ($LinterResult.matchmethod) {
        'powershell' {
            #Scriptanalyzer actually already outputs diagnostic records, so output them as-is
            $LinterResult.stdout.foreach{
                $PSItem.severity = $PSItem.severity -replace '^ParseError$','Error'
                Write-Output ([LinterIssue]::new($PSItem, $LinterResult.Name))
            }
            break
        }
        'regex' {
            $LinterOutput = $LinterResult.stderr ? $LinterResult.stderr : $LinterResult.stdout
            $matchResult = [Regex]::Matches($LinterOutput, $LinterResult.regex)
            if (-not $matchresult -and $LinterResult.exitcode -ne 0) {
                Write-Error "$($LinterResult.Name): Linter exited with exitcode $($LinterResult.exitcode) and no output was found that matched $($linterResult.regex)"
            } else {
                $matchresult.foreach{
                    $matches = $PSItem.groups | Group-Object -Property Name -ashashtable
                    [LinterIssue]@{
                        linterName = $LinterResult.name
                        scriptpath = $matches.path.value
                        message = $matches.message.value
                        severity = $matches.severity.value ?? 'Error'
                        ruleName = $matches.code.value
                        extent = [ScriptExtent]::new(
                            [ScriptPosition]::new(
                                $matches.scriptpath.value,
                                $matches.line.value,
                                $matches.column.value,
                                $null
                            ),
                            $null
                        )
                    }
                }
            }
        }
        'checkstyle' {
            Convert-CheckStyleToLinterIssue $LinterResult
        }
        'errorformat' {
            $errorFormatArgs = @(
                '-w'
                'checkstyle'
            )
            if ($linterResult.format) {
                $errorFormatArgs += '-name'
                $errorFormatArgs += $linterResult.format
            } elseif ($linterResult.efm) {
                $errorFormatArgs += $LinterResult.efm
            } else {
                throw "$($linterResult.name): errorformat requires either the format: or efm: parameters defined in your linter config. Available formats are: $(errorformat -list)"
            }
            
            Write-Debug "Executing errorformat $errorformatArgs"
            Write-Debug '==========='
            $resultToProcess = if ($LinterResult.stderr) {
                $LinterResult.stderr
            } elseif ($LinterResult.stdout) {
                $LinterResult.stdout
            } elseif ($LinterResult.exitcode -eq 0) {
                write-verbose "$($linterResult.name): Exited successfully with no output"
                break
            } else {
                throw "$($linterResult.name): Failed with exit code $($LinterResult.exitcode) and did not have any output"
            }
            #Override default matching
            if ($linterResult.matchon) {$resultToProcess = $LinterResult[$LinterResult.matchon]}

            ### Run ErrorFormat
            $errorformatResult = $resultToProcess | & errorformat @errorformatArgs

            Write-Debug "ErrorFormatResult: $errorFormatResult"
            if ($errorFormatResult -as [xml]) {
                $linterResult.stderr = $errorFormatResult
                Convert-CheckStyleToLinterIssue $linterResult
            } else {
                Write-Error "$($linterResult.name): Error Found while running errorformat: $errorFormatResult"
                break
            }

            if ($LASTEXITCODE -eq 0 -and $null -eq $errorformatResult) {
                #No record to return. Move on
                break
            }
        }
        'problemMatcher' {
            if (-not $combinedOutput) {
                #Assume success if no output
                Write-Verbose "problemMatcher: command had no output, assuming no issues"
                break
            }
            $problemMatchers = ((Get-Content $LinterResult.problemMatcher) | ConvertFrom-Json).problemMatcher

            foreach ($problemMatcher in $problemMatchers) {
                Write-Verbose "Running Problem Matcher $($problemMatcher.owner) on $($LinterResult.name)"
                foreach ($outputLine in ($combinedOutput -split '\r?\n')) {
                    $pattern = $problemMatcher.pattern
                    if ($outputline -match $pattern.regexp) {
                        Write-Debug "Match found! Creating DiagnosticRecord"
                        Write-Debug ([PSCustomObject]$matches | Format-List | out-string)
                        $scriptPath = if ($pattern.fromPath) {
                            join-path $matches[[int]$pattern.frompath] $matches[[int]$pattern.file]
                        } else {
                            $matches[[int]$pattern.file]
                        }
                        $record = @{
                            linterName = $LinterResult.name
                            scriptPath = $scriptPath
                            message = $matches[[int]$pattern.message]
                            severity = if ($pattern.severity) {$matches[[int]$pattern.severity]}
                            ruleName = $matches[[int]$pattern.code]
                            extent = [ScriptExtent]::new(
                                [ScriptPosition]::new(
                                    $matches[[int]$pattern.file],
                                    $matches[[int]$pattern.line],
                                    $matches[[int]$pattern.column],
                                    $null
                                ),
                                $null
                            )
                        }
                        write-debug ([PSCustomObject]$record | Format-List | Out-String)
                        #If a severity wasn't defined in the regex, it should be defined higher up, use that if not present
                        $record.severity ??= $problemMatcher.severity
                        #If it still doesn't match, default to error. This is probably a bug in the problem matcher
                        $record.severity ??= (Write-Error "Unable to determine severity. This is probably a bug in the $($problemMatcher.owner) problem matcher. Output Line $outputline.")
                        Write-Output ([LinterIssue]$record)
                    }
                }
            }
            break
        }
        'stderr' {
            if ($linterResult.stderr) {
                $record.severity = 'Error'
                $record.message = $linterResult.stderr
            } else {
                #No record to return, move on
                break
            }
            $LinterResult.filesToLint.foreach{
                $record.scriptpath = $PSItem
                Write-Output ([LinterIssue]$record)
            }
            break
        }
        'exitcode' {
            if ($linterResult.exitcode -ne 0) {
                $record.severity = 'Error'
                $record.message = $combinedOutput
            } else {
                #No record to return, move on
                break
            }
            $LinterResult.filesToLint.foreach{
                $record.scriptpath = $PSItem
                Write-Output ([LinterIssue]$record)
            }
            break
        }
        #Default is 'Simple'
        Default {
            if ($combinedOutput) {
                $record.severity = 'Error'
                $record.message = $combinedOutput
            } elseif ($linterResult.exitcode -ne 0) {
                $record.severity = 'Error'
                $record.message = "$($linterResult.command) silently exited with exit code $($linterResult.exitcode)"
            } else {
                #No record to return, move on
                break
            }
            $LinterResult.filesToLint.foreach{
                $record.scriptpath = $PSItem
                Write-Output ([LinterIssue]$record)
            }
        }
    }
}