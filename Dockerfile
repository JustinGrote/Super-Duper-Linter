#This is a docker BuildKit file
#https://docs.docker.com/develop/develop-images/build_enhancements/
FROM mcr.microsoft.com/powershell:lts-alpine-3.10 AS pwshsetup
RUN pwsh -c '$ModulesToInstall = @( \
    "PSScriptAnalyzer", \
    "Powershell-Yaml" \
); $progresspreference="silentlycontinue";"Installing $ModulesToInstall";Install-Module -Scope AllUsers -Force -Name $ModulesToInstall'

FROM pwshsetup AS apkinstall
RUN apk --no-cache add \
    git

FROM apkinstall AS entrypoint
COPY entrypoint.ps1 /action/entrypoint.ps1
ENTRYPOINT ["/action/entrypoint.ps1"]