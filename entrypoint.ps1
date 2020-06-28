#!/usr/bin/pwsh
using namespace System.Management.Automation.Language
using namespace System.Management.Automation
using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic
#requires -version 7 -module powershell-yaml
[CmdletBinding()]
param (
    #Name(s) of the linters you wish to run. Runs all by default
    [String[]]$Name = $ENV:INPUT_LINTER -split '[ ;,\n]',
    #Where your repository is located. You should rarely if ever need to change this, the action will automatically pick it up
    [ValidateNotNullOrEmpty()][String]$BasePath = $ENV:GITHUB_WORKSPACE ? $ENV:GITHUB_WORKSPACE : '/github/workspace',
    #Path to the file(s) or directories to lint. Wildcards are supported
    [String[]]$Path = $ENV:INPUT_PATH ? $ENV:INPUT_PATH : '.',
    #Path to custom linter
    [String[]]$CustomLinterPath = $ENV:INPUT_CUSTOMLINTERPATH ? $ENV:INPUT_CUSTOMLINTERPATH : 'linters',
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
    #How many linters to run concurrently. You can adjust this depending on the performance of the system you are running on. Defaults to 
    [int]$ThrottleLimit = $ENV:INPUT_PARALLEL ? $ENV:INPUT_PARALLEL : ($(nproc) + 1),
    #Set to true to enable debug messaging for github actions. For running locally use standard debug preference variables
    [Switch]$EnableDebug = ($ENV:INPUT_DEBUG ? $ENV:INPUT_DEBUG : $ENV:RUNNER_DEBUG) -eq $true,
    #Set to true to enable verbose messaging for github actions. For running locally use standard debug preference variables
    [Switch]$EnableVerbose = ($ENV:INPUT_VERBOSE ? $ENV:INPUT_VERBOSE : $ENV:RUNNER_DEBUG) -eq $true,
    #Set to true to only show items with errors in the log output
    [Switch]$ProblemsOnly = $ENV:INPUT_PROBLEMSONLY -eq $true,
    #Set to true to scan all files in the commit, not just the ones that have changed
    [Switch]$All = $ENV:INPUT_ALL -eq $true,
    #Set to true to disable fetching the metadata of the repository that super-duper-linter uses to make intelligent decisions about what to lint
    [Switch]$NoFetch = $ENV:INPUT_NOFETCH -eq $true,
    #Set to true to validate the linter operation against defined test cases. This is useful if defining a new custom linter.
    [Switch]$Test = $ENV:INPUT_TEST -eq $true,
    #Choose what level of issue severity consistutes a failure of the linter and that it should exit with a non-zero exit status. Options are error, warning, and information. Options are inclusive of their previous choices (e.g. setting information also fails on warnings and errors)
    [String]$Severity = $ENV:INPUT_PATH ? $ENV:INPUT_PATH : 'error',
    #Choose what level of issue severity to emit in outputs. severities below this level will be omitted. Options are error, warning, and information.
    [String]$Level = $ENV:INPUT_PATH ? $ENV:INPUT_PATH : 'information'
)
#TODO: Make a SET-GHAInputs to auto-populate parameters intelligently

Import-Module $PSScriptRoot/Utils/GHActionUtils.psm1 -Force -ErrorAction Stop
Import-Module $PSScriptRoot/SuperDuperLinter/SuperDuperLinter.psm1 -Force -ErrorAction Stop

if ($ENV:GITHUB_ACTIONS) {
    if ($EnableVerbose) {
        Enable-GHAVerbose
    }

    if ($EnableDebug) {
        Enable-GHADebug

        GHAGroup 'Environment Information' {
            Get-ChildItem env: | Foreach-Object {$_.name + '=' + $_.value}
        }
    }
}

GHAGroup 'Startup' {
    Push-Location -StackName basePath $basePath
    

    #Determine which files to process
    if (-not $All -or -not $Test) {
        if ($Path -ne '.') {
            $PathFilter = $Path
        }
        $Path = Get-GHAFileChanges
    } else {
        Write-Verbose "Linting all files because 'ALL' was set to true"
    }

    Write-Debug "Pre-Evaluation Paths"
    Write-Debug "==================="
    $Path | Write-Debug
    Write-Debug "==================="
    
    #Apply file filters. We don't need to waste time with this on a test because we are going to override them anyways
    if (-not $Test) {
        Write-Debug "Scanning for files to lint"
        [String[]]$candidatePaths = Get-ChildItem -Force -File -Recurse -Path $Path -Include $Include -Exclude $Exclude
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
        Write-Debug "File scan lint completed"
    }


    Write-Host "Startup OK!"
}

if (-not $Test -and -not $candidatePaths) {
    throw "Either no files were found in the current path, or they were all excluded. We will assume this is an error because why would you be running Super Duper Linter then?"
}

GHAGroup 'Import Linter Definition and Identify Files To Lint' {
    $CustomLinterPath.Foreach{
        if (Test-Path (join-path $PSItem "/*/$LinterDefinitionFileName")) {
            Write-Host "${PSItem}: Custom Linters Detected, these will override the builtin linters"
            $LinterDefinitionPath += $PSItem
        } else {
            Write-Verbose "No Custom Linter found at $PSItem, skipping..."
        }
    }
    
    $linters = Import-LinterDefinition $LinterDefinitionPath $LinterDefinitionFileName

    if ($Name) {
        $lintersToExclude = foreach ($linter in $linters.values) {
            if ($linter.name -notin $Name) {
                Write-Output $linter.name
            }
        }
        #Remove the excluded linters
        $lintersToExclude.foreach{
            [void]$linters.Remove($PSItem)
        }
    }
    if (-not $Test) {
        Add-LinterFiles -LinterDefinition $linters -Path $candidatePaths
    }
    

    Write-Host "Successfully imported $($linters.count) linters"
}

if ($Test) {
    GHAGroup '===Linter Test Mode===' {
        Test-Linter $linters
    }
    '===Linter Test Mode Completed==='
    exit 0
}

if (-not $linters.values.filesToLint) {
    throw "No linters were found for the $(@($candidatePaths).count) files in scope. We will assume this is an error because why would you be running Super Duper Linter then?"
}

GHAGroup 'Files to Lint' {
    $linters.values.filesToLint | Sort-Object -Unique
}

GHAGroup 'Run Linters' {
    [HashTable[]]$LinterResult = Invoke-Linter -LinterDefinition $linters -ThrottleLimit $ThrottleLimit


    $linterIssues = $LinterResult.foreach{
        Format-LinterResult $PSItem
    }
    $severityPriority = @{
        error=0
        warning=1
        information=2
    }
    $LinterIssues = $LinterIssues | Where-Object {
        $severityPriority[$PSItem.severity] -lt $severityPriority[$Level]
    }
}

#TODO: More structured output
Out-LinterGithubAction -LinterIssue $LinterIssues

#Set exit code to number of errors
$linterIssueCount = $LinterIssues | Group Severity

$completionMessage = . {
    "Super Duper Linter issues found:"
    $indent = "  "
    $SCRIPT:failureFound = $false
    #TODO: Use enum instead
    $severityPriority = @{
        error=0
        warning=1
        information=2
    }
    ('information','warning','error').foreach{
        $issueCount = $linterIssueCount | Where-Object name -eq $PSItem | Foreach-Object Count
        if ($issueCount -gt 0) {
            "$indent$issueCount $PSItem"
            if ($severityPriority[$PSItem] -le $severityPriority[$Severity] ) {
                $SCRIPT:failureFound = $true
            }
        }
    }
}

#Exit based on failures. Anything other than zero will fail the action
if ($failureFound) {
    throw $completionMessage
} else {
    $completionMessage
    "`u{1F389}`u{1F389}`u{1F389} No $severity level issues or higher were found. Congratulations! `u{1F389}`u{1F389}`u{1F389}"
}
Pop-Location -StackName basePath