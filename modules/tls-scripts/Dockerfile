# Build a simple Docker image that contains dependencies for tls-scripts module.
FROM ubuntu:20.04 as with-secrets
MAINTAINER Gruntwork "gruntwork.io"

# Build Phase 1: With Secrets
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Install gruntkms and whatever it needs
# Clone package-kafka

# github-oauth-token for accessing private repos
ARG GITHUB_OAUTH_TOKEN

# If the build-time args are not defined, make it clear to the user.
RUN if [ -z "$GITHUB_OAUTH_TOKEN" ]; then echo "ERROR: You must set GITHUB_OAUTH_TOKEN as a Docker build arg."; exit 1; fi

# Install dependencies
RUN apt-get update && apt-get install -y \
      git \
      curl && \
      rm -rf /var/lib/apt/lists/*

# install gruntwork-installer
RUN curl -LsS "https://raw.githubusercontent.com/gruntwork-io/gruntwork-installer/master/bootstrap-gruntwork-installer.sh" | bash /dev/stdin --version v0.0.28 --no-sudo true

# install gruntkms
RUN gruntwork-install --binary-name "gruntkms" --repo "https://github.com/gruntwork-io/gruntkms" --tag 'v0.0.8' --no-sudo true
RUN gruntkms --version

# install package-kafka script
RUN git clone "https://${GITHUB_OAUTH_TOKEN}@github.com/gruntwork-io/package-kafka.git" "/tmp/package-kafka" && \
      mv /tmp/package-kafka/modules/generate-key-stores/generate-key-stores.sh /usr/local/bin/ && \
      chmod +x /usr/local/bin/generate-key-stores.sh && \
      rm -rf /tmp/package-kafka/

# Build Phase 2: Without Secrets
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# everything else

# Start from openjdk to easily get keytool
FROM openjdk:8-jre-slim as without-secrets
COPY --from=with-secrets /usr/local/bin/gruntkms /usr/local/bin/gruntkms
COPY --from=with-secrets /usr/local/bin/generate-key-stores.sh /usr/local/bin/generate-key-stores.sh

RUN apt-get update && \
      apt-get install -y \
      curl \
      unzip \
      git \
      jq \
      pwgen \
      openssl && \
      rm -rf /var/lib/apt/lists/*

# install terraform
RUN curl -LsS "https://releases.hashicorp.com/terraform/0.12.18/terraform_0.12.18_linux_amd64.zip" -o "terraform.zip" && \
      unzip "terraform.zip" && \
      mv terraform /usr/local/bin/ && \
      terraform --version && \
      rm -f "terraform.zip"

# install aws
RUN curl -LsS "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
      unzip awscliv2.zip && \
      ./aws/install && \
      aws --version && \
      rm -f "awscliv2.zip"

# Copy over scripts for running tls-scripts tests
COPY *.sh /usr/local/bin/
