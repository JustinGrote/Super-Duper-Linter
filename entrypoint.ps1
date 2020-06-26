#!/usr/bin/pwsh
#requires -version 7 -module powershell-yaml
[CmdletBinding()]
param (
    #Where your repository is located. You should rarely if ever need to change this, the action will automatically pick it up
    [ValidateNotNullOrEmpty()][String]$BasePath = $ENV:GITHUB_WORKSPACE ? $ENV:GITHUB_WORKSPACE : '/github/workspace',
    #Path to the file(s) or directories to lint. Wildcards are supported
    [String[]]$Path = $ENV:INPUT_PATH ? $ENV:INPUT_PATH : '.',
    #Explicit file paths to exclude, relative to your root directory. Wildcards are *not* supported
    [String[]]$ExcludePath = $ENV:INPUT_EXCLUDEPATH -split '[ ;,\n]',
    #Files patterns to include. Wildcards are supported.
    [String[]]$Include = $ENV:INPUT_INCLUDE -split '[ ;,\n]',
    #Files patterns to exclude. Wildcards are supported.
    [String[]]$Exclude = $ENV:INPUT_EXCLUDE -split '[ ;,\n]',
    #Where to find the language definitions. Definitions are evaluated in order, with the first one found being accepted
    [String[]]$LinterDefinitionPath = "$PSScriptRoot/linters",
    #The filename of your linter definition. This usually does not have to change
    [String[]]$LinterDefinitionFileName = 'linter.yml',
    #Name(s) of the linters you wish to run. Runs all by default
    [String[]]$Name = $ENV:INPUT_LINTER -split '[ ;,\n]',
    #How many linters to run concurrently. You can adjust this depending on the performance of the system you are running on. Defaults to 
    [int]$ThrottleLimit = $ENV:INPUT_PARALLEL ? $ENV:INPUT_PARALLEL : ($(nproc) + 1),
    #Set to true to enable debug messaging for github actions. For running locally use standard debug preference variables
    [Switch]$EnableDebug = ($ENV:INPUT_DEBUG ? $ENV:INPUT_DEBUG : $ENV:RUNNER_DEBUG) -eq $true,
    #Set to true to only show items with errors in the log output
    [Switch]$ProblemsOnly = $ENV:INPUT_PROBLEMSONLY -eq $true,
    #Set to true to scan all files in the commit, not just the ones that have changed
    [Switch]$All = $ENV:INPUT_ALL -eq $true,
    #Set to true to disable fetching the metadata of the repository that super-duper-linter uses to make intelligent decisions about what to lint
    [Switch]$NoFetch= $ENV:INPUT_NOFETCH -eq $true
)

#TODO: Make a SET-GHAInputs to auto-populate parameters intelligently

Import-Module $PSScriptRoot/Utils/GHActionUtils.psm1 -Force
Import-Module $PSScriptRoot/SuperDuperLinter/SuperDuperLinter.psm1 -Force

if ($enableDebug -and $ENV:GITHUB_ACTIONS) {
    Enable-GHADebug
    Enable-GHAVerbose
    GHAGroup 'Environment Information' {
        Get-ChildItem env: | Foreach-Object {$_.name + '=' + $_.value}
    }
}

GHAGroup 'Startup' {
    Push-Location -StackName basePath $basePath
    
    #Determine which files to process
    
    if (-not $All) {
        if ($Path -ne '.') {
            $PathFilter = $Path
        }
        $Path = Get-GHAFileChanges
    }

    Write-Debug "Pre-Evaluation Paths"
    Write-Debug "==================="
    $Path | Write-Debug
    Write-Debug "==================="

    #Apply file filters
    [String[]]$candidatePaths = Get-ChildItem -File -Recurse -Path $Path -Include $Include -Exclude $Exclude
    | Resolve-Path -Relative
    | Foreach-Object {
        #Trim the leading "./" from the paths
        $PSItem -replace '^\.[\\\/](.+)$','$1'
    }
    | Where-Object {
        $PSItem -notin $ExcludePath ? $true : (Write-Debug "$PSItem EXCLUDED by explicit ExcludePath $ExcludePath")
    }
    | Where-Object {
        if ($PathFilter) {
            #Confirm that the path matches at least one of the path suffixes provided
            $pathMatchTest = foreach ($PathItem in $PathFilter) {
                $pathToTest = [Regex]::Escape($PathItem)
                $PSItem -match "^$pathToTest"
            } 
            #If at least one path didn't match, this will return false, which means Where-Object will exclude it
            $pathMatchTest -contains $true ? $true : (Write-Debug "$PSItem EXCLUDED by PathFilter")
        } else {$true}
    }

    Write-Host "Startup OK!"
}

if (-not $candidatePaths) {
    Write-Host "Either no files were found in the current path, or they were all excluded. Exiting..."
    exit 0
}

GHAGroup 'Import Linter Definition and Identify Files To Lint' {
    $linters = Import-LinterDefinition $LinterDefinitionPath $LinterDefinitionFileName

    if ($Name) {
        $linters = $linters | Where-Object name -in $Name
    }
    
    $linters = $linters | Add-LinterFiles -Path $candidatePaths
    Write-Host "Successfully imported $($linters.count) linters"
}

if (-not $linters.filesToLint) {
    Write-Host "No linters were found for the $(@($candidatePaths).count) files in scope. Exiting..."
    exit 0
}

GHAGroup 'Files to Lint' {
    $linters.filesToLint | Sort-Object -Unique
}

GHAGroup 'Run Linters' {
    [HashTable[]]$LinterResult = Invoke-Linter -LinterDefinition $linters -ThrottleLimit 5
    if ($ProblemsOnly) {
        $LinterResult = $LinterResult | Where-Object status -ne 'success'
    }
}

if ($ProblemsOnly -and -not $LinterResult) {
    Write-Host "All linters completed without finding any problems. Congratulations!"
    exit 0
}

#TODO: More structured output
Out-LinterGithubAction -LinterResult $LinterResult
Set-GHAOutput $LinterResult -Name Result -Depth 1

#Set exit code to number of errors
$failureCount = $LinterResult
| Where-Object status -eq 'error'
| Measure-Object
| Foreach-Object count

#Exit based on failures. Anything other than zero will fail the action
if ($failureCount -ne 0) {
    "Super Duper Linter found $failureCount pieces of lint"
    throw "Super Duper Linter found $failureCount pieces of lint"
} else {
    "=== Super Duper Linter Complete! ==="
}
Pop-Location -StackName basePath