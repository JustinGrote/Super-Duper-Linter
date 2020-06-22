
function Import-LinterDefinition ([String[]]$LinterDefinitionPath, [String[]]$LinterDefinitionFileName='linter.yml') {
    $linterDefinitionFiles = foreach ($FileItem in $LinterDefinitionFileName) {
        Get-ChildItem -Recurse -Path $LinterDefinitionPath -Filter $FileItem
    }

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

        #FIXME: Resolve paths for the container
        Write-Output $linter
    }
}