# ----------------------------------------------------------------------------------------------------------------------
# CONTAINER FOR DEPLOY SCRIPT FOR INFRASTRUCTURE CI/CD
# This Dockerfile builds an image to help set up an infrastructure CI/CD pipeline to securely deploy infrastructure
# code stored in a source control system.
#
# Challenge: How do we pass in the GITHUB_OAUTH_TOKEN to gruntwork-install?
#
# Use of gruntwork-install requires a non-empty env var GITHUB_OAUTH_TOKEN that corresponds to a personal GitHub Token.
# Unfortunately, Docker does not currently support build-time secrets, Despite the recommendation in
# https://stackoverflow.com/a/33623649/2308858, even as of Jan 15, 2020, the edge version of Docker does not yet support
# build-time secrets.
#
# A common approach to Docker build-time secrets is to use build-time args, but per
# https://stackoverflow.com/a/40762010/2308858, the use of build-time args will propagate the build-time arg values to
# Docker's local cache and history. If a user then pushes the built Docker image to a Docker registry, the build-time
# arg values (and therefore the secrets) will be plainly visible to anyone who pulls the Docker image.
#
# As an admittedly hacky alternative, we will use multi-stage builds
# (https://docs.docker.com/develop/develop-images/multistage-build/). The idea is that our first Docker build phase
# ("with-secrets") contains the discouraged use of a build-time arg, and uses this to run gruntwork-install
# successfully. In the second build phase ("without-secrets"), we will copy everything installed by gruntwork-install by
# leveraging our use of how gruntwork-install works and what it's installing.
#
# In the end, we get the files we needed the secrets to get, but not the secrets themselves.
# ----------------------------------------------------------------------------------------------------------------------

# Build Phase 1: With Secrets
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~

FROM python:3.8-alpine AS with-secrets
MAINTAINER Gruntwork <info@gruntwork.io>

# Require a build-time arg of your GitHub Personal Token. Be sure to read the intro notes to understand the risks of
# passing in secrets this way.
# Example command: docker build --build-arg GITHUB_OAUTH_TOKEN --tag gruntwork/ecs-deploy-runner .
# This example will set the GITHUB_OAUTH_TOKEN build arg using the value of the environment variable with the same name.
ARG GITHUB_OAUTH_TOKEN

# These build args have defaults that can be overridden. For example, you can update the terraform version by passing
# in: --build-arg terraform_version=0.12.21
ARG terraform_version=0.12.20
ARG terragrunt_version=v0.21.11
ARG packer_version=1.5.1
ARG infrastructure_deploy_script_branch=master

# If the build-time arg is not defined, make it clear to the user.
RUN if [ -z "$GITHUB_OAUTH_TOKEN" ]; then echo "ERROR: You must set GITHUB_OAUTH_TOKEN as a Docker build arg."; exit 1; fi

# Here we setup the gruntwork-installer so that we can install various tooling necessary to perform a deployment.
# Note that we install gruntwork-module-circleci-helper, even though this container is not intended to be used with
# CircleCI. This is because gruntwork-module-circleci-helper has useful scripts for installing Terraform, Terragrunt,
# and Packer which are useful for most deployments.
RUN apk update && apk add jq bash sudo curl && echo "set disable_coredump false" > /etc/sudo.conf
RUN curl -Ls https://raw.githubusercontent.com/gruntwork-io/gruntwork-installer/master/bootstrap-gruntwork-installer.sh | bash /dev/stdin --version v0.0.23
RUN gruntwork-install --module-name "gruntwork-module-circleci-helpers" --repo "https://github.com/gruntwork-io/module-ci" --tag "v0.16.2" && \
    gruntwork-install --module-name "infrastructure-deploy-script" --repo "https://github.com/gruntwork-io/module-ci" --branch "$infrastructure_deploy_script_branch" && \
    gruntwork-install --binary-name "kubergrunt" --repo "https://github.com/gruntwork-io/kubergrunt" --tag "v0.5.8"

# Install Terraform, Terragrunt, and Packer using configure-environment-for-gruntwork-module.
RUN configure-environment-for-gruntwork-module \
      --go-version NONE \
      --terraform-version "$terraform_version" \
      --terragrunt-version "$terragrunt_version" \
      --packer-version "$packer_version"


# Build Phase 2: Without Secrets
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FROM python:3.8-alpine AS without-secrets
MAINTAINER Gruntwork <info@gruntwork.io>

# Copy the files installed with gruntwork-install and configure-environment-for-gruntwork-module
COPY --from=with-secrets /opt /opt
COPY --from=with-secrets /usr/local/lib/python3.8/site-packages /usr/local/lib/python3.8/site-packages
COPY --from=with-secrets /usr/local/bin/kubergrunt /usr/local/bin/kubergrunt
COPY --from=with-secrets /usr/local/bin/infrastructure-deploy-script /usr/local/bin/infrastructure-deploy-script
COPY --from=with-secrets /root/terraform/terraform /usr/local/bin/terraform
COPY --from=with-secrets /root/terragrunt/terragrunt /usr/local/bin/terragrunt
COPY --from=with-secrets /root/packer/packer /usr/local/bin/packer

# Install additional tools necessary for infrastructure deployment
RUN apk update && apk add jq git bash curl openssh-client

# Add github.com, gitlab.com, bitbucket.com host key to known hosts. Note that we are using a hard coded file here. This
# was obtained using the following command:
# ssh-keyscan -t rsa DOMAIN
# We don't want to dynamically do this on container build because it defeats the spirit of the host key verification: we
# want to obtain and set the known hosts from a trusted environment. The host key we have here was added from a trusted
# environment at Gruntwork, where it can not be manipulated by a MITM attack.
# If you are sourcing your code from any other location (e.g github enterprise), you will want to add that domain to the
# known_hosts file before building the container.
COPY ./known_hosts /root/.ssh/known_hosts

ENTRYPOINT ["ssh-agent", "/usr/local/bin/infrastructure-deploy-script"]
