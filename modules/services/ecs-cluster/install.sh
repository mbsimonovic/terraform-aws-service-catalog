#!/usr/bin/env bash
# Install ECS Cluster and Gruntwork dependencies on a Linux server

set -e

readonly DEFAULT_ECS_CLUSTER_VERSION="v0.20.2"

# Build tooling
readonly DEFAULT_TERRAFORM_VERSION="0.12.21"
readonly DEFAULT_TERRAGRUNT_VERSION="v0.22.3"
readonly DEFAULT_PACKER_VERSION="1.5.4"
readonly DEFAULT_DOCKER_VERSION="18.06.1~ce~3-0~ubuntu"

# ECS tooling 
readonly DEFAULT_ECS_SCRIPTS_VERSION="v0.16.0"
readonly DEFAULT_GRUNT_KMS_VERSION="v0.0.8"

# TODO: Update ref to a tag when released
readonly DEFAULT_EC2_BASELINE_REF="master"

# You can set the version of the build tooling to this value to skip installing it
readonly SKIP_INSTALL_VERSION="NONE"

# NOTE: A few variables will be imported from ec2-baseline
# - DEFAULT_MODULE_SECURITY_VERSION
# - DEFAULT_MODULE_AWS_MONITORING_VERSION
# - DEFAULT_BASH_COMMONS_VERSION
# - DEFAULT_ENABLE_SSH_GRUNT
# - DEFAULT_ENABLE_CLOUDWATCH_LOG_AGGREGATION
# - DEFAULT_ENABLE_CLOUDWATCH_METRICS

function include_ec2_baseline {
  gruntwork-install \
    --module-name base/ec2-baseline \
    --repo https://github.com/gruntwork-io/aws-service-catalog \
    --tag ${DEFAULT_EC2_BASELINE_REF}

  # Include common defaults and functions from the ec2-baseline install script
  # See: https://github.com/gruntwork-io/aws-service-catalog/blob/master/modules/base/ec2-baseline
  readonly EC2_BASELINE_RELATIVE_PATH="../../base/ec2-baseline"
  readonly EC2_BASELINE_PATH="$(dirname $(realpath $0))/${EC2_BASELINE_RELATIVE_PATH}"
  if [[ ! -f "${EC2_BASELINE_PATH}/install.sh" ]]; then
    echo "ERROR: $EC2_BASELINE_PATH/install.sh not found."
    exit 1
  fi

  source $EC2_BASELINE_PATH/install.sh
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

function install_terraform {
  local -r version="$1"

  if [[ "$version" == "$SKIP_INSTALL_VERSION" ]]; then
    echo "Terraform version is set to $SKIP_INSTALL_VERSION, so skipping install."
    return
  fi

  echo "Installing Terraform $version"
  wget "https://releases.hashicorp.com/terraform/${version}/terraform_${version}_linux_amd64.zip"
  unzip "terraform_${version}_linux_amd64.zip"
  sudo cp terraform /usr/local/bin/terraform
  sudo chmod a+x /usr/local/bin/terraform
}

function install_terragrunt {
  local -r version="$1"

  if [[ "$version" == "$SKIP_INSTALL_VERSION" ]]; then
    echo "Terragrunt version is set to $SKIP_INSTALL_VERSION, so skipping install."
    return
  fi

  echo "Installing Terragrunt $version"
  wget "https://github.com/gruntwork-io/terragrunt/releases/download/$version/terragrunt_linux_amd64"
  sudo cp terragrunt_linux_amd64 /usr/local/bin/terragrunt
  sudo chmod a+x /usr/local/bin/terragrunt
}

function install_packer {
  local -r version="$1"

  if [[ "$version" == "$SKIP_INSTALL_VERSION" ]]; then
    echo "Packer version is set to $SKIP_INSTALL_VERSION, so skipping install."
    return
  fi

  echo "Installing Packer $version"
  wget "https://releases.hashicorp.com/packer/${version}/packer_${version}_linux_amd64.zip"
  unzip "packer_${version}_linux_amd64.zip"
  sudo cp packer /usr/local/bin/packer
  sudo chmod a+x /usr/local/bin/packer
}

# Based on: https://docs.docker.com/engine/installation/linux/ubuntu/#install-using-the-repository
function install_docker {
  local -r version="$1"

  if [[ "$version" == "$SKIP_INSTALL_VERSION" ]]; then
    echo "Docker version is set to $SKIP_INSTALL_VERSION, so skipping install."
    return
  fi

  echo "Installing Docker $version"

  sudo apt-get install -y linux-image-extra-virtual
  sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  sudo apt-get update
  sudo apt-get install -y docker-ce="$version"

  # This allows us to run Docker without sudo: http://askubuntu.com/a/477554
  echo "Adding user $ecs_cluster_USER to Docker group"
  sudo gpasswd -a "$ecs_cluster_USER" docker
}

function install_git {
  echo "Installing Git"
  sudo apt-get install -y git
}

function install_build_dependencies {
  local -r terraform_version="$1"
  local -r terragrunt_version="$2"
  local -r packer_version="$3"
  local -r docker_version="$4"

  install_terraform "$terraform_version"
  install_terragrunt "$terragrunt_version"
  install_packer "$packer_version"
  install_docker "$docker_version"
  install_git
}

function install_ecs_cluster {
  # Read from env vars to make it easy to set these in a Packer template (without super-wide --module-param foo=bar code).
  # Fallback to default version if the env var is not set.
  local ecs_cluster_version="${ecs_cluster_version:-DEFAULT_ECS_CLUSTER_VERSION}"
  local terraform_version="${terraform_version:-DEFAULT_TERRAFORM_VERSION}"
  local terragrunt_version="${terragrunt_version:-DEFAULT_TERRAGRUNT_VERSION}"
  local packer_version="${packer_version:-DEFAULT_PACKER_VERSION}"
  local docker_version="${docker_version:-DEFAULT_DOCKER_VERSION}"

  while [[ $# > 0 ]]; do
    local key="$1"

    case "$key" in
      --ecs_cluster-version)
        assert_not_empty "$key" "$2"
        ecs_cluster_version="$2"
        shift
        ;;
  --terraform-version)
        assert_not_empty "$key" "$2"
        terraform_version="$2"
        shift
        ;;
      --terragrunt-version)
        assert_not_empty "$key" "$2"
        terragrunt_version="$2"
        shift
        ;;
    --packer-version)
        assert_not_empty "$key" "$2"
        packer_version="$2"
        shift
        ;;
      --docker-version)
        assert_not_empty "$key" "$2"
        docker_version="$2"
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
        echo "ERROR: Unrecognized argument: $key"
        exit 1
        ;;
    esac

    shift
  done

  assert_env_var_not_empty "GITHUB_OAUTH_TOKEN"

  install_build_dependencies \
    "$terraform_version" \
    "$terragrunt_version" \
    "$packer_version" \
    "$docker_version"

  gruntwork-install --module-name 'ecs-scripts' --repo https://github.com/gruntwork-io/module-ecs --tag "$ecs_cluster_version"
}

include_ec2_baseline

install_ecs_cluster "$@"
