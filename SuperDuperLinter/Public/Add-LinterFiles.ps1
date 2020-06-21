function Add-LinterFiles {
    param (
        #The linter definitions imported from Import-LinterDefinition
        [Parameter(Mandatory,ValueFromPipeline)][Hashtable[]]$LinterDefinition,
        #The path(s) where candiate files should be searched
        [Parameter(Mandatory)][String[]]$Path
    )
    begin {
        $candidateFiles = Get-ChildItem -File -Path $Path -Recurse
    }
    process {
        foreach ($linter in $LinterDefinition) {
            $matchedFiles = $linter.filematch.foreach{
                #The array wrapper forces -match to return the name of files that match, rather than just $true
                @($candidateFiles) -match $PSItem
            }
            $linter.filesToLint = $matchedFiles
            #Return the linter with the additional files
            $linter
        }
    }
}