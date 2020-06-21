Get-ChildItem -Recurse $PSScriptRoot/Public | Foreach-Object {
    . $PSItem
}
Export-ModuleMember -Function *