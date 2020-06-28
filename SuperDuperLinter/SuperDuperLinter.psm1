Get-ChildItem -Recurse @("$PSScriptRoot/Public","$PSScriptRoot/Private") | Foreach-Object {
    . $PSItem
}
Export-ModuleMember -Function *