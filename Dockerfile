#This is a docker BuildKit file
#https://docs.docker.com/develop/develop-images/build_enhancements/

#Runner: Final Image
FROM alpine:20200626 AS superduperlinter
WORKDIR /usr/bin

#Add APKs

RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories\
    && apk --no-cache add \
        bash git curl file \
        npm \
        perl \
        ansible-lint \
        libxml2-utils \
        go \
        python3 \
        libffi \
        py3-pylint \
        yamllint \
        shellcheck
#libxml2-utils = xmllint

#Add NPM Packages and shrink them minimally
RUN npm config set package-lock false \
    && npm -g --no-cache install \
        markdownlint-cli \
        jsonlint \
        @coffeelint/cli \
        typescript eslint \
        standard \
        babel-eslint \
        @typescript-eslint/eslint-plugin \
        @typescript-eslint/parser \
        eslint-plugin-jest \
        stylelint \
        stylelint-config-standard \
        dockerfilelint\
    && curl -sfL https://install.goreleaser.com/github.com/tj/node-prune.sh | bash -s -- -b /usr/local/bin && \
    node-prune /usr/lib && \
    rm /usr/local/bin/node-prune

#Add Powershell
RUN apk add --no-cache \
    ca-certificates \
    less \
    ncurses-terminfo-base \
    krb5-libs \
    libgcc \
    libintl \
    libssl1.1 \
    libstdc++ \
    tzdata \
    userspace-rcu \
    zlib \
    icu-libs \
    curl \
    lttng-ust \
&& curl -L https://github.com/PowerShell/PowerShell/releases/download/v7.0.2/powershell-7.0.2-linux-alpine-x64.tar.gz -o /tmp/powershell.tar.gz \
&& mkdir -p /opt/microsoft/powershell/7 \
&& tar zxf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7 \
&& rm /tmp/powershell.tar.gz \
&& chmod +x /opt/microsoft/powershell/7/pwsh \
&& ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh

### Direct Imports
#Hadolint
COPY --from=hadolint/hadolint /bin/hadolint .
#TFLint 
COPY --from=wata727/tflint /usr/local/bin/tflint .
#ReviewDog
COPY --from=arachnysdocker/reviewdog /reviewdog .
#DotEnv Linter
RUN wget https://github.com/dotenv-linter/dotenv-linter/releases/latest/download/dotenv-linter-alpine-x86_64.tar.gz -O - -q | tar -xzf -
#GoLangCI-lint
RUN curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b /usr/bin v1.27.0

#Install Powershell Modules
RUN pwsh -c '$ModulesToInstall = @( \
    "PSScriptAnalyzer", \
    "Powershell-Yaml" \
); \
$verbosepreference="continue";\
$progresspreference="silentlycontinue";\
Install-Module -Name $ModulesToInstall -Scope AllUsers -Force;\
'

#Source Compilations
#Dockerfilelint from source
WORKDIR /tmp
RUN git clone https://github.com/replicatedhq/dockerfilelint.git && cd dockerfilelint && npm install && cd .. && rm -rf dockerfilelint
WORKDIR /usr/bin

# Super-Duper-Linter
WORKDIR /action
COPY entrypoint.ps1 .
COPY SuperDuperLinter ./SuperDuperLinter
COPY Utils ./Utils
COPY linters ./linters


ENTRYPOINT ["./entrypoint.ps1"]
