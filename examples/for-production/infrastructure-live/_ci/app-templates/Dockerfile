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

FROM debian:buster AS with-secrets
MAINTAINER Gruntwork <info@gruntwork.io>

# Require a build-time arg of your GitHub Personal Token. Be sure to read the intro notes to understand the risks of
# passing in secrets this way.
# Example command: docker build --build-arg GITHUB_OAUTH_TOKEN --tag gruntwork/ecs-deploy-runner .
# This example will set the GITHUB_OAUTH_TOKEN build arg using the value of the environment variable with the same name.
ARG GITHUB_OAUTH_TOKEN

# If the build-time arg is not defined, make it clear to the user.
RUN if [ -z "$GITHUB_OAUTH_TOKEN" ]; then echo "ERROR: You must set GITHUB_OAUTH_TOKEN as a Docker build arg."; exit 1; fi

# These build args have defaults that can be overridden. For example, you can update the module ci version by passing
# in: --build-arg MODULE_CI_VERSION=v0.24.0
ARG GRUNTWORK_INSTALLER_VERSION=v0.0.38
ARG MODULE_CI_VERSION=v0.41.1
ARG MODULE_SECURITY_VERSION=v0.61.0


# Here we setup the gruntwork-installer so that we can install various tooling necessary to perform a deployment.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y jq bash sudo curl && \
    echo "set disable_coredump false" > /etc/sudo.conf
COPY ./scripts/install.sh /tmp/scripts/install.sh
RUN ./tmp/scripts/install.sh


# Build Phase 2: Without Secrets
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FROM python:3.8-buster AS without-secrets
MAINTAINER Gruntwork <info@gruntwork.io>

# Copy the files installed with gruntwork-install
COPY --from=with-secrets /usr/local/bin/infrastructure-deployer /usr/local/bin/infrastructure-deployer
COPY --from=with-secrets /usr/local/bin/aws-auth /usr/local/bin/aws-auth
RUN chmod +x /usr/local/bin/infrastructure-deployer && \
    chmod +x /usr/local/bin/aws-auth
RUN apt-get update && apt-get install -yy jq git bash && pip install awscli
