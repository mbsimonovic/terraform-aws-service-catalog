# Build a simple Docker image that contains dependencies for tls-scripts module.
FROM ubuntu:20.04
MAINTAINER Rho Sang "rho@gruntwork.io"
RUN apt-get update && apt-get install -y \
      automake \
      build-essential \
      wget \
      p7zip-full \
      bash \
      curl \
      sudo \
      unzip \
      git \
      jq \
      pwgen

# install terraform
RUN wget "https://releases.hashicorp.com/terraform/0.12.18/terraform_0.12.18_linux_amd64.zip"
RUN unzip "terraform_0.12.18_linux_amd64.zip"
RUN mv terraform /usr/local/bin/
RUN terraform --version

# install aws
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip
RUN ./aws/install
RUN aws --version

# install gruntwork-installer
RUN curl -LsS "https://raw.githubusercontent.com/gruntwork-io/gruntwork-installer/master/bootstrap-gruntwork-installer.sh" | bash /dev/stdin --version v0.0.28

# export github-oauth-token for accessing private repos
ARG GITHUB_OAUTH_TOKEN
# export aws cli envvars for running aws api calls
ARG AWS_ACCESS_KEY_ID
ARG AWS_SECRET_ACCESS_KEY

# If the build-time args are not defined, make it clear to the user.
RUN if [ -z "$GITHUB_OAUTH_TOKEN" ]; then echo "ERROR: You must set GITHUB_OAUTH_TOKEN as a Docker build arg."; exit 1; fi
RUN if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then echo "ERROR: You must set AWS_SECRET_ACCESS_KEY as a Docker build arg."; exit 1; fi
RUN if [ -z "$AWS_ACCESS_KEY_ID" ]; then echo "ERROR: You must set AWS_ACCESS_KEY_ID as a Docker build arg."; exit 1; fi

# install gruntkms
RUN gruntwork-install --binary-name "gruntkms" --repo "https://github.com/gruntwork-io/gruntkms" --tag 'v0.0.8'
RUN gruntkms --version
