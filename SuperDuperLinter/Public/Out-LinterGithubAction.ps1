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
    
    process {
        foreach ($linter in $LinterResult) {
            $statuscolor = if ($linter.status -eq 'success') { 'green' } else { 'red' }
            Write-Host -NoNewline "=== $($linter.name): "
            Write-Host -NoNewline -ForegroundColor $statuscolor $linter.status
            Write-Host " - $($linter.filesToLint)"
            #Enable problem matcher if present
            if ($linter.status -ne 'success' -and $linter.problemMatcher) {
                #Required due to running in container
                #https://github.com/actions/toolkit/issues/305
                #TODO: Find out if there is a more appropriate TEMP directory to put this
                $matcherFilePath = "/github/home/$($linter.name).json"
                #FIXME: Resolve from environment variables
                Copy-Item -Path $Linter.problemMatcher -Destination $matcherFilePath
                Write-Output "::add-matcher::/home/runner/work/_temp/_github_home/$(Split-Path -Leaf $matcherFilePath)"
            }

            try {
                
                if ($linter.name -eq 'powershell') {
                    Write-Host -Fore Cyan ($linter.result | Format-Table -prop ScriptName,RuleName,Severity,Message | Out-String)
                } else {
                    Write-Host -Fore Cyan ($linter.result | Format-List | Out-String)
                }
            } catch {
                Write-Error $linter
            } finally {
                if ($linter.problemMatcher) {
                    $problemMatcherName = (Get-Content -Raw $linter.problemMatcher 
                    | ConvertFrom-Json).problemmatcher.owner
                    Write-Output "::remove-matcher owner=$problemMatcherName::"
                }
            }
        }
    }
}
