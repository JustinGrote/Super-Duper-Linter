#This is a docker BuildKit file
#https://docs.docker.com/develop/develop-images/build_enhancements/

#TODO: Generate a docker file from the language specifications
FROM mcr.microsoft.com/powershell:lts-alpine-3.10 AS pwshsetup
RUN pwsh -c '$ModulesToInstall = @( \
    "PSScriptAnalyzer", \
    "Powershell-Yaml" \
); $progresspreference="silentlycontinue";"Installing $ModulesToInstall";Install-Module -Scope AllUsers -Force -Name $ModulesToInstall'

FROM pwshsetup AS apkinstall
RUN apk --no-cache add \
    git \
    npm nodejs

#Docker Hadolint
FROM apkinstall AS hadolint
COPY --from=hadolint/hadolint /bin/hadolint /usr/bin

# #####################
# # Install Go Linter #
# #####################
FROM hadolint AS go
ARG GO_VERSION='v1.27.0'
RUN wget -O- -nvq https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s "$GO_VERSION"

# ##################
# # Install TFLint #
# ##################
FROM go AS tflint
COPY --from=wata727/tflint /usr/local/bin/tflint /usr/bin


#TEMPORARY FIXME: Replace with individual actions or language-provided directives
FROM tflint AS super-linter-compatibility-apk
####################
# Run APK installs #
####################
RUN apk add --no-cache \
    bash git git-lfs musl-dev curl gcc jq file\
    npm nodejs \
    libxml2-utils perl \
    py3-setuptools ansible-lint \
    go

#####################
# Run Pip3 Installs #
#####################
# RUN pip3 install --upgrade pip
# RUN pip3 --no-cache-dir install --upgrade --no-cache-dir \
#     yamllint pylint yq

# ####################
# # Run NPM Installs #
# ####################
FROM super-linter-compatibility-apk AS super-linter-compatibility-npm
RUN npm config set package-lock false \
    && npm config set loglevel error \
    && npm -g --no-cache install \
      markdownlint-cli \
      jsonlint prettyjson \
      @coffeelint/cli \
      typescript eslint \
      standard \
      babel-eslint \
      @typescript-eslint/eslint-plugin \
      @typescript-eslint/parser \
      eslint-plugin-jest \
      stylelint \
      stylelint-config-standard \
      && npm --no-cache install \
      markdownlint-cli \
      jsonlint prettyjson \
      @coffeelint/cli \
      typescript eslint \
      standard \
      babel-eslint \
      prettier \
      eslint-config-prettier \
      @typescript-eslint/eslint-plugin \
      @typescript-eslint/parser \
      eslint-plugin-jest \
      stylelint \
      stylelint-config-standard

# ####################################
# # Install dockerfilelint from repo #
# ####################################
# RUN git clone https://github.com/replicatedhq/dockerfilelint.git && cd /dockerfilelint && npm install

#  # I think we could fix this with path but not sure the language...
#  # https://github.com/nodejs/docker-node/blob/master/docs/BestPractices.md

######################
# Install shellcheck #
######################
FROM super-linter-compatibility-npm AS bash
RUN wget -qO- "https://github.com/koalaman/shellcheck/releases/download/stable/shellcheck-stable.linux.x86_64.tar.xz" | tar -xJv \
    && mv "shellcheck-stable/shellcheck" /usr/bin/



# ##################
# # Install dotenv-linter #
# ##################
FROM bash AS env
RUN wget "https://github.com/dotenv-linter/dotenv-linter/releases/latest/download/dotenv-linter-alpine-x86_64.tar.gz" -O - -q | tar -xzf - \
    && mv "dotenv-linter" /usr/bin

# PyLint
FROM env AS pylint
RUN apk add python3-dev \ 
&& pip3 install --upgrade pip \
&& pip3 install pylint

FROM pylint AS yamllint
RUN pip3 install yamllint

FROM yamllint AS entrypoint
COPY entrypoint.ps1 /action/
COPY SuperDuperLinter /action/SuperDuperLinter
COPY Utils /action/Utils
COPY linters /action/linters
ENTRYPOINT ["/action/entrypoint.ps1"]