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


FROM hadolint AS entrypoint
COPY entrypoint.ps1 /action/
COPY SuperDuperLinter /action/SuperDuperLinter
COPY languages /action/languages
ENTRYPOINT ["/action/entrypoint.ps1"]


#TEMPORARY FIXME: Replace with individual actions or language-provided directives
FROM entrypoint AS super-linter-compatibility
####################
# Run APK installs #
####################
RUN apk add --no-cache \
    bash git git-lfs musl-dev curl gcc jq file\
    npm nodejs \
    libxml2-utils perl \
    ruby ruby-dev ruby-bundler ruby-rdoc make \
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

# ####################
# # Run GEM installs #
# ####################
# RUN gem install rubocop:0.74.0 rubocop-rails rubocop-github:0.13.0

# # Need to fix the version as it installs 'rubocop:0.85.1' as a dep, and forces the default
# # We then need to promot the correct verion, uninstall, and fix deps
# RUN sh -c 'gem install --default rubocop:0.74.0;  yes | gem uninstall rubocop:0.85.1 -a -x -I; gem install rubocop:0.74.0'

# ######################
# # Install shellcheck #
# ######################
# RUN wget -qO- "https://github.com/koalaman/shellcheck/releases/download/stable/shellcheck-stable.linux.x86_64.tar.xz" | tar -xJv \
#     && mv "shellcheck-stable/shellcheck" /usr/bin/

# #####################
# # Install Go Linter #
# #####################
# ARG GO_VERSION='v1.27.0'
# RUN wget -O- -nvq https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s "$GO_VERSION"

# ##################
# # Install TFLint #
# ##################
# RUN curl -Ls "$(curl -Ls https://api.github.com/repos/terraform-linters/tflint/releases/latest | grep -o -E "https://.+?_linux_amd64.zip")" -o tflint.zip && unzip tflint.zip && rm tflint.zip \
#     && mv "tflint" /usr/bin/

# ##################
# # Install dotenv-linter #
# ##################
# RUN wget "https://github.com/dotenv-linter/dotenv-linter/releases/latest/download/dotenv-linter-alpine-x86_64.tar.gz" -O - -q | tar -xzf - \
#     && mv "dotenv-linter" /usr/bin
