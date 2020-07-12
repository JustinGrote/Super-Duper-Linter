using namespace System.Management.Automation
using namespace System.IO

function Invoke-Linter {
    param (
        #Linter Definitions to run. These must have filesToMatch already populated
        [Parameter(Mandatory)][Collections.Generic.SortedDictionary[String, Hashtable]]$LinterDefinition,
        #How many different linters to run simultaneously
        [Int]$ThrottleLimit = 5
    )

    #Filter out linters that don't need to be run
    $linterDefinition.values.foreach{
        if (-not $PSItem.filesToLint) {
            Write-Verbose "$($PSItem.name): No files matched. Skipping..."
            $LinterDefinition.Remove($LinterDefinition.Name)
        }
    }

    function Copy-Object ($InputObject) {
        <#
        .SYNOPSIS
        Use the serializer to create an independent copy of an object, useful when using an object as a template
        #>
        [psserializer]::Deserialize(
            [psserializer]::Serialize(
                $InputObject
            )
        )
    }
    #Break out linters into individual files for those that need it (assume by default)

    [HashTable[]]$LinterRunners = foreach ($linter in $LinterDefinition.values) {
        if ($linter.filemode -eq 'multiple' -or $linter.filestolint.count -eq 1) {
            Write-Output $linter
        } else {
            foreach ($linterFilePath in $linter.filesToLint) {
                Write-Verbose "`u{1F680} $linterfilePath - $($linter.command)"
                $newLinter = Copy-Object $linter
                $newLinter.filesToLint = $linterFilePath
                Write-Output $newLinter
            }
        }
    }

    $LinterResults = $LinterRunners | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
        $linter = $PSItem
        $icons = @{
            success = "`u{2705}"
            failure = "`u{274C}"
        }

        $linterArgs = $linter.args
        $linterErrTempFile = [io.path]::GetTempFileName()

        #Run the Linter
        if ($linter.pre) {Invoke-Expression $linter.pre}
        $linterOut = & $linter.command @linterArgs $linter.filesToLint 2>$linterErrTempFile
        if ($linter.post) {Invoke-Expression $linter.post}
        
        #Workaround because you can't direct stderr directly to a variable
        $linterErr = Get-Content -Raw $linterErrTempFile
        Remove-Item $linterErrTempFile

        $linter.exitcode = $LASTEXITCODE
        $statusIcon = ($linter.exitcode -eq 0) ? $icons['success'] : $icons['failure'] 
        $linter.filesToLint.foreach{
            $resultMessage = "[$statusIcon] $PSItem - $($linter.name)"
            if ($EnableDebug) {
                $resultMessage + " - Exited $($linter.exitcode)"
            }
            Write-Host $resultMessage
        }
        $linter.stdout = $linterOut
        $linter.stderr = $linterErr
        #Return the formatted linter result
        Write-Output $linter
    }
    Write-Debug "===Linter Result==="
    Write-Debug (
        [PSCustomObject[]]$LinterResults
        | Select-Object name,status,exitcode,stdout,stderr,command,args,filesToLint
        | Format-List
        | Out-String
    )
    return $LinterResults
}