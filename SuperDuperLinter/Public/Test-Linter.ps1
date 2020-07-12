function Test-Linter {
    [CmdletBinding()]
    param(
        #Path to an imported linter definition from Import-LinterDefinition.
        [Parameter(Mandatory)][Collections.Generic.SortedDictionary[String, Hashtable]]$LinterDefinition,
        [String]$TestPath = 'Tests'
    )

    foreach ($linter in $linterDefinition.values) {
        $linterName = $linter.Name
        Push-Location -StackName TestLinter (Split-Path $linter.path)
        #TODO: Process tests in parallel
        try {
            $testFound = $false
            foreach ($statusToTest in 'success','error','warning','info') {
                Write-Verbose "${linterName}: Checking for $statusToTest test"
                $ErrorActionPreference = 'Stop'
                
                [String]$testFileName = "${statusToTest}*.*"
                [String]$testMatchPath = (Join-Path $TestPath $testFileName)
                Write-Debug "${lintername}: Searching $pwd using $testMatchPath"
                $linter.filesToLint = (Resolve-Path $testMatchPath -Relative -ErrorAction SilentlyContinue) -replace '^\.[\\\/](.+)$','$1'
                if (-not $linter.filesToLint) {
                    Write-Verbose "${linterName}: No $statusToTest test found"
                    continue
                } else {
                    Write-Verbose "${linterName}: $statusToTest test(s) found at $($linter.filesToLint -join ', ')"
                    $testFound = $true
                }

                #Wrap the linter to test back into a sorted dictionary. This isn't directly intuitive in Powershell
                $linterToTest = [Collections.Generic.SortedDictionary[String, Hashtable]]::new()
                $linterToTest[$linter.name] = $linter

                $result = Format-LinterResult (Invoke-Linter $linterToTest 6>$null)
                
                [bool]$linterPassesTest = switch ($statusToTest) {
                    'Success' {
                        $null -eq $result
                        break
                    }
                    Default {
                        $statusToTest -in $result.severity
                    }
                }
                if (-not $linterPassesTest) {
                    [String]$linterOutput = @($linter.stdout,$linter.stderr) -join ';'
                    Write-Error "$linterName $statusToTest test FAILED. Expected $statusToTest but got $($result.severity). Linter Output: $linterOutput" -ErrorAction Continue
                } else {
                    Write-Host -fore green "PASSED - ${linterName}/$statusToTest"
                }
            }
            if (-not $TestFound) {Write-Warning "$($linter.name): No tests have been defined for this linter. You should define at least a success and error test"}
        } catch {throw $PSItem} finally {
            Pop-Location -StackName TestLinter
        }
    }
}