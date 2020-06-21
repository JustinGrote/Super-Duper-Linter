using namespace System.Management.Automation
using namespace System.IO

function Invoke-Linter {
    param (
        #Linter Definitions to run. These must have filesToMatch already populated
        [Parameter(Mandatory)][Hashtable[]]$LinterDefinition,
        #How many different linters to run simultaneously
        [Int]$ThrottleLimit = 5
    )

    $LinterDefinition | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
        $linter = $PSItem
        if (-not $linter.filesToLint) {
            Write-Verbose "$($linter.name): No files matched. Skipping..."
            continue
        }
        
        $linterArgs = $linter.args
        $linter.result = & $linter.command @linterArgs $linter.filesToLint *>&1

        if ($LASTEXITCODE -ne 0) {
            $linter.status = 'failure'
            Write-Host -fore red "$($linter.name) FAILED: $LASTEXITCODE"
        } else {
            Write-Host $result
            Write-Host -fore green "$($linter.name): SUCCEEDED"
            $linter.status = 'success'
        }

        #Return the formatted linter result
        Write-Output $linter
    }

}