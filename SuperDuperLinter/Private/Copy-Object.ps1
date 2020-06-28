using namespace System.Management.Automation
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