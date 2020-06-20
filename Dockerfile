######################
# Set the entrypoint #
######################
FROM mcr.microsoft.com/powershell:lts-alpine-3.10
RUN apk add --no-cache \
        git \
    && \
    pwsh -c '$ModulesToInstall = @( \
        "PSScriptAnalyzer", \
        "Powershell-Yaml" \
    ); $progresspreference="silentlycontinue";"Installing $ModulesToInstall";Install-Module -Scope AllUsers -Force -Name $ModulesToInstall'
COPY entrypoint.ps1 /action/entrypoint.ps1
ENTRYPOINT ["/action/entrypoint.ps1"]
