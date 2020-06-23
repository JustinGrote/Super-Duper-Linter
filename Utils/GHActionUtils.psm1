#A collection of functions to make formatting Github Action Output Easier

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

Export-ModuleMember -Function *