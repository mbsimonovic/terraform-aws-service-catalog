# Build a simple Docker image that contains dependencies for tls-scripts module.
FROM ubuntu:20.04 as with-secrets
MAINTAINER Gruntwork "gruntwork.io"

# Build Phase 1: With Secrets
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~
# only gruntkms and whatever it needs

# export github-oauth-token for accessing private repos
ARG GITHUB_OAUTH_TOKEN
# make version an arg

# If the build-time args are not defined, make it clear to the user.
RUN if [ -z "$GITHUB_OAUTH_TOKEN" ]; then echo "ERROR: You must set GITHUB_OAUTH_TOKEN as a Docker build arg."; exit 1; fi

# Install dependencies
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
      curl && \
      rm -rf /var/lib/apt/lists/*

# install gruntwork-installer
RUN curl -LsS "https://raw.githubusercontent.com/gruntwork-io/gruntwork-installer/master/bootstrap-gruntwork-installer.sh" | bash /dev/stdin --version v0.0.28 --no-sudo true

# install gruntkms
RUN gruntwork-install --binary-name "gruntkms" --repo "https://github.com/gruntwork-io/gruntkms" --tag 'v0.0.8' --no-sudo true
RUN gruntkms --version


# Build Phase 2: Without Secrets
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# everything else

# Start from openjdk because we need keytool
FROM openjdk:8-jre-slim as without-secrets
COPY --from=with-secrets /usr/local/bin/gruntkms /usr/local/bin/gruntkms

# Copy over ssh keys for cloning private repo gruntwork-io/package-kafka
# COPY --from=with-secrets /root/.ssh/* /root/.ssh/

RUN apt-get update && \
      apt-get install -y \
      curl \
      ssh \
      unzip \
      git \
      jq \
      pwgen \
      openssl && \
      rm -rf /var/lib/apt/lists/*

# copy ssh keys to docker
ARG SSH_PRIVATE_KEY
ARG SSH_PUBLIC_KEY
ARG SSH_PASSPHRASE
RUN mkdir /root/.ssh/ && \
      chmod 0700 /root/.ssh/ && \
      ssh-keyscan github.com >> /root/.ssh/known_hosts
RUN echo "${SSH_PRIVATE_KEY}" > /root/.ssh/id_rsa && \
      echo "${SSH_PUBLIC_KEY}" > /root/.ssh/id_rsa.pub && \
      chmod 0600 /root/.ssh/id_rsa && \
      chmod 0600 /root/.ssh/id_rsa.pub
# RUN eval `ssh-agent -s` && \
#       printf "${SSH_PASSPHRASE}\n" | ssh-add

# install terraform
RUN curl -LsS "https://releases.hashicorp.com/terraform/0.12.18/terraform_0.12.18_linux_amd64.zip" -o "terraform.zip" && \
      unzip "terraform.zip" && \
      mv terraform /usr/local/bin/ && \
      terraform --version && \
      rm -f "terraform.zip"

# install aws
# RUN pip install aws
RUN curl -LsS "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
      unzip awscliv2.zip && \
      ./aws/install && \
      aws --version && \
      rm -f "awscliv2.zip"

# Copy over scripts for tls-scripts test
COPY *.sh /usr/local/bin/
