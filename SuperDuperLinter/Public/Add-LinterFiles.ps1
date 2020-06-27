function Add-LinterFiles {
    param (
        #The linter definitions imported from Import-LinterDefinition
        [Parameter(Mandatory,ValueFromPipeline)][Collections.Generic.SortedDictionary[String, Hashtable]]$LinterDefinition,
        #The path to files that will be used by the linters
        [Parameter(Mandatory)][String[]]$Path
    )
    process {
        foreach ($linter in $LinterDefinition.values) {
            $matchedFiles = $linter.filematch.foreach{
                #The array wrapper forces -match to return the name of files that match, rather than just $true
                @($Path) -match $PSItem
            }
            $linter.filesToLint = $matchedFiles
            #Return the linter with the additional files
            #$linter
        }
    }
}