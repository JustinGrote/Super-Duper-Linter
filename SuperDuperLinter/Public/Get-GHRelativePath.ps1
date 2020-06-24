function Get-GHRelativePath {
    param(
        [Parameter(ValueFromPipeLine)][String]$Path,
        [String]$BasePath
    )
    if ($BasePath) {Push-Location $BasePath}
    [String]$relativePath = Resolve-Path -Relative $Path
    Write-Output $relativePath.TrimStart(".$([Environment]::NewLine)")
    if ($BasePath) {Pop-Location}
}