#!/usr/bin/env bash
# Install Jenkins and Gruntwork dependencies on a Linux server

set -e

readonly MODULE_SECURITY_VERSION="v0.18.1"
readonly MODULE_AWS_MONITORING_VERSION="v0.16.0"
readonly MODULE_STATEFUL_SERVER_VERSION="v0.7.1"
readonly MODULE_CI_VERSION="v0.15.0"
readonly KUBERGRUNT_VERSION="v0.5.1"
readonly BASH_COMMONS_VERSION="v0.1.2"
readonly TERRAFORM_VERSION="0.12.6"
readonly TERRAGRUNT_VERSION="v0.19.19"
readonly KUBECTL_VERSION="v1.12.0"
readonly HELM_VERSION="v2.11.0"
readonly PACKER_VERSION="1.3.3"
readonly DOCKER_VERSION="18.06.1~ce~3-0~ubuntu"
readonly JENKINS_USER="jenkins"

function install_security_packages {
  local -r module_security_version="$1"
  local -r enable_ssh_grunt="$2"

  echo "Installing Gruntwork Security Modules"

  gruntwork-install --module-name 'auto-update' --repo https://github.com/gruntwork-io/module-security --tag "$module_security_version"
  gruntwork-install --module-name 'fail2ban' --repo https://github.com/gruntwork-io/module-security --tag "$module_security_version"
  gruntwork-install --module-name 'ntp' --repo https://github.com/gruntwork-io/module-security --tag "$module_security_version"
  gruntwork-install --module-name 'ip-lockdown' --repo https://github.com/gruntwork-io/module-security --tag "$module_security_version"

  if [[ "$enable_ssh_grunt" == "true" ]]; then
    gruntwork-install --binary-name 'ssh-grunt' --repo https://github.com/gruntwork-io/module-security --tag "$module_security_version"
  fi
}

function install_monitoring_packages {
  local -r module_aws_monitoring_version="$1"
  local -r enable_cloudwatch_metrics="$2"
  local -r enable_cloudwatch_log_aggregation="$3"

  echo "Installing Gruntwork Monitoring Modules"

  if [[ "$enable_cloudwatch_metrics" == "true" ]]; then
    gruntwork-install --module-name 'metrics/cloudwatch-memory-disk-metrics-scripts' --repo https://github.com/gruntwork-io/module-aws-monitoring --tag "$module_aws_monitoring_version"
  fi

  if [[ "$enable_cloudwatch_log_aggregation" == "true" ]]; then
    # Allow the region to be passed in by env var
    local aws_region="$AWS_REGION"
    if [[ -z "$aws_region" ]]; then
      # If no region is passed in by env var, read it from the EC2 metadata endpoint instead
      source "/opt/gruntwork/bash-commons/aws.sh"
      aws_region=$(aws_get_instance_region)
    fi

    gruntwork-install --module-name 'logs/cloudwatch-log-aggregation-scripts' --repo https://github.com/gruntwork-io/module-aws-monitoring --tag "$module_aws_monitoring_version" --module-param aws-region="$aws_region"
  fi

  gruntwork-install --module-name 'logs/syslog' --repo https://github.com/gruntwork-io/module-aws-monitoring --tag "$module_aws_monitoring_version"
}

function install_stateful_server_packages {
  local -r module_server_version="$1"

  echo "Installing Gruntwork Stateful Server Modules"
  gruntwork-install --module-name 'persistent-ebs-volume' --repo 'https://github.com/gruntwork-io/module-server' --tag "$module_server_version"
}

function install_ci_packages {
  local -r module_ci_version="$1"
  local -r jenkins_version="$2"

  echo "Installing Gruntwork CI Modules"

  gruntwork-install --module-name 'install-jenkins' --repo 'https://github.com/gruntwork-io/module-ci' --tag "$module_ci_version" --module-param "version=$jenkins_version"
  gruntwork-install --module-name 'build-helpers' --repo 'https://github.com/gruntwork-io/module-ci' --tag "$module_ci_version"
  gruntwork-install --module-name 'git-helpers' --repo 'https://github.com/gruntwork-io/module-ci' --tag "$module_ci_version"
  gruntwork-install --module-name 'terraform-helpers' --repo 'https://github.com/gruntwork-io/module-ci' --tag "$module_ci_version"
}

function install_kubergrunt {
  local -r version="$1"

  echo "Installing Kubergrunt"
  gruntwork-install --binary-name "kubergrunt" --repo "https://github.com/gruntwork-io/kubergrunt" --tag "$version"
  sudo chmod 755 /usr/local/bin/kubergrunt
}

function assert_not_empty {
  local -r arg_name="$1"
  local -r arg_value="$2"

  if [[ -z "$arg_value" ]]; then
    log_error "The value for '$arg_name' cannot be empty."
    exit 1
  fi
}

function assert_env_var_not_empty {
  local -r var_name="$1"
  local -r var_value="${!var_name}"

  if [[ -z "$var_value" ]]; then
    echo "ERROR: Required environment variable $var_name not set."
    exit 1
  fi
}

function install_bash_commons {
  local -r bash_commons_version="$1"

  echo "Installing bash-commons"
  gruntwork-install --module-name 'bash-commons' --repo https://github.com/gruntwork-io/bash-commons --tag "$bash_commons_version"
}

function install_terraform {
  local -r version="$1"

  echo "Installing Terraform $version"
  wget "https://releases.hashicorp.com/terraform/${version}/terraform_${version}_linux_amd64.zip"
  unzip "terraform_${version}_linux_amd64.zip"
  sudo cp terraform /usr/local/bin/terraform
  sudo chmod a+x /usr/local/bin/terraform
}

function install_terragrunt {
  local -r version="$1"

  echo "Installing Terragrunt $version"
  wget "https://github.com/gruntwork-io/terragrunt/releases/download/$version/terragrunt_linux_amd64"
  sudo cp terragrunt_linux_amd64 /usr/local/bin/terragrunt
  sudo chmod a+x /usr/local/bin/terragrunt
}

function install_packer {
  local -r version="$1"

  echo "Installing Packer $version"
  wget "https://releases.hashicorp.com/packer/${version}/packer_${version}_linux_amd64.zip"
  unzip "packer_${version}_linux_amd64.zip"
  sudo cp packer /usr/local/bin/packer
  sudo chmod a+x /usr/local/bin/packer
}

function install_kubectl {
  local -r version="$1"

  echo "Installing Kubectl $version"
  wget "https://storage.googleapis.com/kubernetes-release/release/${version}/bin/linux/amd64/kubectl"
  sudo mv kubectl /usr/local/bin/kubectl
  sudo chmod a+x /usr/local/bin/kubectl
}

function install_helm {
  local -r version="$1"

  echo "Installing Helm $version"
  wget "https://storage.googleapis.com/kubernetes-helm/helm-${version}-linux-amd64.tar.gz"
  tar -xvf helm-${version}-linux-amd64.tar.gz
  sudo mv linux-amd64/helm /usr/local/bin/helm
  sudo chmod a+x /usr/local/bin/helm

  echo "Cleaning up temporary files"
  rm -rf linux-amd64
  rm helm-${version}-linux-amd64.tar.gz
}

# Based on: https://docs.docker.com/engine/installation/linux/ubuntu/#install-using-the-repository
function install_docker {
  local -r version="$1"

  echo "Installing Docker $version"

  sudo apt-get install -y linux-image-extra-virtual
  sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  sudo apt-get update
  sudo apt-get install -y docker-ce="$version"

  # This allows us to run Docker without sudo: http://askubuntu.com/a/477554
  echo "Adding user $JENKINS_USER to Docker group"
  sudo gpasswd -a "$JENKINS_USER" docker
}

function install_git {
  echo "Installing Git"
  sudo apt-get install -y git
}

function install_aws_cli {
  echo "Installing AWS CLI"
  sudo apt-get install -y jq python-pip unzip
  sudo pip install awscli
}

function install_build_dependencies {
  install_terraform "$TERRAFORM_VERSION"
  install_terragrunt "$TERRAGRUNT_VERSION"
  install_packer "$PACKER_VERSION"
  install_kubectl "$KUBECTL_VERSION"
  install_helm "$HELM_VERSION"
  install_docker "$DOCKER_VERSION"
  install_git
}

function install_gruntwork_modules {
  local -r jenkins_version="$1"
  local -r enable_ssh_grunt="$2"
  local -r enable_cloudwatch_metrics="$3"
  local -r enable_cloudwatch_log_aggregation="$4"

  install_aws_cli
  install_bash_commons "$BASH_COMMONS_VERSION"
  install_security_packages "$MODULE_SECURITY_VERSION" "$enable_ssh_grunt"
  install_monitoring_packages "$MODULE_AWS_MONITORING_VERSION" "$enable_cloudwatch_metrics" "$enable_cloudwatch_log_aggregation"
  install_stateful_server_packages "$MODULE_STATEFUL_SERVER_VERSION"
  install_ci_packages "$MODULE_CI_VERSION" "$jenkins_version"
  install_kubergrunt "$KUBERGRUNT_VERSION"
}

function install_jenkins {
  local jenkins_version
  local enable_ssh_grunt="true"
  local enable_cloudwatch_metrics="true"
  local enable_cloudwatch_log_aggregation="true"

  while [[ $# > 0 ]]; do
    local key="$1"

    case "$key" in
      --jenkins-version)
        jenkins_version="$2"
        shift
        ;;
      --enable-ssh-grunt)
        enable_ssh_grunt="$2"
        shift
        ;;
      --enable-cloudwatch-metrics)
        enable_cloudwatch_metrics="$2"
        shift
        ;;
      --enable-cloudwatch-log-aggregation)
        enable_cloudwatch_log_aggregation="$2"
        shift
        ;;
      *)
        log "ERROR: Unrecognized argument: $key"
        exit 1
        ;;
    esac

    shift
  done

  assert_not_empty "--jenkins-version" "$jenkins_version"
  assert_env_var_not_empty "GITHUB_OAUTH_TOKEN"

  install_gruntwork_modules "$jenkins_version" "$enable_ssh_grunt" "$enable_cloudwatch_metrics" "$enable_cloudwatch_log_aggregation"
  install_build_dependencies
}

install_jenkins "$@"
