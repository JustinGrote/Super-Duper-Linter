using namespace System.Collections.Generic
function Import-LinterDefinition {
    [CmdletBinding()]
    param (
        [String[]]$LinterDefinitionPath, 
        [String[]]$LinterDefinitionFileName='linter.yml'
    )
    
    $linterDefinitionFiles = foreach ($FileItem in $LinterDefinitionFileName) {
        Get-ChildItem -Recurse -Path $LinterDefinitionPath -Filter $FileItem
    }

    #This can be used like a normal hashtable but it automatically sorts the keys alphabetically
    $linters = [SortedDictionary[String, Hashtable]]::new()

    foreach ($linterDefinitionFileItem in $linterDefinitionFiles) {
        Write-Verbose "Importing linter definition from $linterDefinitionFileItem"
        try {
            Push-Location -StackName $linterDefinitionFileItem -Path (Split-Path $linterDefinitionFileItem)
            $linter = Get-Content -Raw -Path $linterDefinitionFileItem | ConvertFrom-Yaml 

            #Checks file path properties and resolves them to their absolute paths
            'command','config','problemMatcher' | Foreach-Object {
                if ($linter.$PSItem) {
                    if (Test-Path $linter.$PSItem) {
                        $linter.$PSItem = Resolve-Path $linter.$PSItem
                    } elseif ($psitem -eq 'command') {
                        $linter.$PSItem = [string](Get-Command $linter.$PSItem)
                    } else {
                        Write-Error "$PSItem $($linter.$PSItem) was not found for $($linter.name). Please file a bug report."
                    }
                }
            }

            if (-not (Get-Command $linter.command -ErrorAction SilentlyContinue)) {
                Write-Error "Unable to find $($linter.command) for linter $($linter.name). Please file a bug report."
                continue
            }
        } catch {
            Write-Error $PSItem
        } finally {
            Pop-Location -StackName $linterDefinitionFileItem
        }

        $linter.path = $linterDefinitionFileItem
        
        #Check for a local repository config and use that overriding config if present
        if ($linter.config) {
            $linterConfigName = Split-Path $linter.config -Leaf
            if (Test-Path $linterConfigName) {
                $linter.config = Resolve-Path $linterConfigName
                Write-Host "$($linter.name) - Using config $($linterConfigName) found in local repository rather than the default"
            }
        }

        #Resolve any variables that may be present
        $varMatchRegex = '\${{ ?(\w+) ?}}'
        [String[]]$linter.args = $linter.args | Foreach-Object {
            if ($PSItem -match $varMatchRegex) {
                $varToReplace = $linter.($matches[1])
                if (-not $varToReplace) {
                    Write-Error "$linter.name`: Variable $varToReplace was not found or was null. Please file a bug report."
                    continue
                }
                $PSItem -replace $varMatchRegex, $linter.($matches[1])
            } else {
                $PSItem
            }
        }

        #If a linter already exists it will be overwritten
        $linters[$linter.name] = $linter
    }
    return $linters
}