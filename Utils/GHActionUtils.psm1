#A collection of functions to make formatting Github Action Output Easier



$Script:GHAGroupNumber = 0
function Get-GHAGroup {
    [CmdletBinding()]
    param(
        [String]$Name = $($GHAGroupNumber++;"Group$GHAGroupNumber"),
        [Scriptblock]$ScriptBlock
    )
    "##[group]$Name"
    . $ScriptBlock
    "##[endgroup]$Name"
}

function Push-GHAGroup ($GroupName) {
    if ($SCRIPT:GHACurrentGroup) {
        Write-Error -Category NotImplemented -Message "Nested Github Action Output Groups are currently not supported and you already specified Push-GHAGroup. Run Pop-GHAGroup first before specifying a new group."
        return
    }
    
    $SCRIPT:GHACurrentGroup = $GroupName
    "##[group]$GroupName"
}

function Pop-GHAGroup {
    if (-not $SCRIPT:GHACurrentGroup) {
        Write-Error -Category InvalidOperation -Message "You must run Push-GHAGroup first to create a Github Action Output Group"
        return
    }
    "##[endgroup]$($SCRIPT:GHACurrentGroup)"
    Remove-Variable -Scope Script -Name GHACurrentGroup
}


function Get-GHAAnsi ($Name) {
    $ansiCollection = [ordered]@{}
    enum AnsiColors {
        Black
        Red
        Green
        Yellow
        Blue
        Magenta
        Cyan
        White
    }
    $template = "`e[{0}{1}m"
    $brightCode = ';1'
    foreach ($colorItem in [AnsiColors]::GetValues([AnsiColors])) {
        $ansiCollection["$ColorItem"]             = $template -f [int][AnsiColors]($ColorItem+30),$null
        $ansiCollection["Bright$ColorItem"]     = $template -f [int][AnsiColors]($ColorItem+30),$brightCode
        $ansiCollection["BG${ColorItem}"]       = $template -f [int][AnsiColors]($ColorItem+40),$null
        $ansiCollection["BGBright${ColorItem}"] = $template -f [int][AnsiColors]($ColorItem+40),$brightCode
    }

    $specialkeys = @{
        Reset       = $template -f 0,$null
        Bold        = $template -f 1, $null
        Underline   = $template -f 4,$null
        Reversed    = $template -f 7,$null
    }

    $specialkeys.keys | Foreach-Object {
        $ansiCollection[$PSItem] = $SpecialKeys[$PSItem]
    }
    if ($Name) {
        return $ansiCollection.$Name
    } else {
        return $ansiCollection
    }
}
function Write-GHADebug {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)][String]$Message
    )
    process {
        $Message.split([Environment]::NewLine).foreach{
            # Write-Host "::debug::$PSItem"
            Write-Host (
                (Get-GHAAnsi 'Magenta') +
                "DEBUG: " +
                $PSItem + 
                (Get-GHAAnsi 'Reset')
            )
        }
    }
}
function Write-GHAVerbose{
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)][String]$Message
    )
    process {
        $Message.split([Environment]::NewLine).foreach{
            #Write-Host "::verbose::$PSItem"
            Write-Host (
                (Get-GHAAnsi 'Cyan') +
                "VERBOSE: " +
                $PSItem + 
                (Get-GHAAnsi 'Reset')
            )
        }
    }
}


$SCRIPT:ProblemMatcherCache = @{}
function Enable-ProblemMatcher ([String]$matcherFilePath) {
    $matcherTempPath = "$ENV:HOME/$(New-Guid).json"
    Copy-Item -Path $matcherFilePath -Destination $matcherTempPath
    Write-Host "::add-matcher::$matcherTempPath"
    $loadedMatchers = (Get-Content -Raw $matcherTempPath | ConvertFrom-Json).problemmatcher.owner
    #For retrieving later when disabling
    $ProblemMatcherCache.$MatcherFilePath = $loadedMatchers
    $SCRIPT:lastMatcherFilePath = $matcherFilePath
}
function Disable-ProblemMatcher ([String]$matcherFilePath = $SCRIPT:lastMatcherFilePath) {
    write-host -fore Magenta $($ProblemMatcher)
    if (-not $SCRIPT:ProblemMatcherCache.$matcherFilePath) {
        throw "Did not find a matching file to $matcherFilePath in the cache. Did you run Enable-ProblemMatcher first?"
    }
    $SCRIPT:ProblemMatcherCache.$MatcherFilePath.foreach{
        Write-Host "::remove-matcher owner=$PSItem::"
    }
}

#DSL Language Construct
function Get-ProblemMatcher ([String]$matcherFilePath, [ScriptBlock]$ScriptBlock) {
    Enable-ProblemMatcher $matcherFilePath
    try {
        . $ScriptBlock
    } catch {
        throw $PSItem
    } finally {
        Disable-ProblemMatcher $matcherFilePath
    }
}

function Enable-GHADebug {
    #Scope 2 means "above function then module scope" meaning whatever scope imported the module. Better than using global since it gets cleaned up
    Set-Alias -scope 2 -Name Write-Debug -Value Write-GHADebug
}

function Enable-GHAVerbose {
    #Scope 2 means "above function then module scope" meaning whatever scope imported the module. Better than using global since it gets cleaned up
    Set-Alias -scope 2 -Name Write-Verbose -Value Write-GHAVerbose
}

function Set-GHAOutput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,ValueFromPipeline)]$InputObject,
        [Parameter(Mandatory)][String]$Name,
        $Depth = 5
    )
    process {
        if ($InputObject -isnot [String]) {
            $InputObject = $InputObject | ConvertTo-Json -Compress -Depth $Depth -EnumsAsStrings
        }
        
        Write-Host "::set-output name=$name::$InputObject"
    }
}

function Get-GHAFileChanges {
    param (
        $Path = '/github/workspace',
        $TargetCommit = $ENV:GITHUB_BASE_REF,
        [ValidateNotNullOrEmpty()]$SourceCommit = $ENV:GITHUB_SHA
    )
    try {
        $GitRootPath = git rev-parse --show-toplevel || Write-Error "Github Pull Request Environment Variables were detected but $Path is not a valid git repository."
        Push-Location -StackName GetGHAFileChanges $GitRootPath

        #Detect the parent branch
        if (-not $TargetCommit) {
            #We need to fetch all branches to detect the common ancestor
            $fetchResult = git fetch origin || Write-Error "Unable to fetch from origin. Please file an issue."
            $TargetCommit = Get-GHAParentBranch
        } else {
            $fetchResult = git fetch origin -- $TargetCommit $SourceCommit
        }
        $diffTarget = $TargetCommit ? "origin/$TargetCommit" : $null
        $diffPaths = git diff --diff-filter=d --name-only $diffTarget $SourceCommit || Write-Error "Unable to determine changed files in $Path. Please file an issue on this."

        Write-Output $diffPaths
    } catch {throw $PSItem} finally {
        Pop-Location -StackName GetGHAFileChanges
    }
}

function Get-GHAParentBranch {
    [CmdletBinding()]
    param(
        $Name = (git branch --show-current)
    )
    Write-Debug "Git Show branch"
    $gitShowBranchResult = git show-branch -a
    $gitShowBranchResult | Write-Debug
    
    #Get the name of the parent branch
    $gitShowBranchResult
    | Select-String '^[^\[]*\*'
    | Select-String -NotMatch -Pattern "\[$([Regex]::Escape($Name)).*?\]"
    | Select-Object -First 1
    | Foreach-Object {$PSItem -replace '^.+?\[(.+)\].+$','$1'}
}

Export-ModuleMember -Function *
