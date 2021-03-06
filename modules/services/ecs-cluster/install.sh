#!/usr/bin/env bash
# Install ECS Cluster and Gruntwork dependencies on a Linux server

set -e

# patcher auto-update: terraform-aws-ecs
readonly DEFAULT_ECS_CLUSTER_VERSION="v0.32.0"

# ECS tooling
# patcher auto-update: terraform-aws-ecs
readonly DEFAULT_ECS_SCRIPTS_VERSION="v0.32.0"
# patcher auto-update: gruntkms
readonly DEFAULT_GRUNT_KMS_VERSION="v0.0.10"

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
  if [[ "$1" ]]; then
    ec2_baseline_version_branch="--branch $1"
  fi
  if [[ "$2" ]]; then
    ec2_baseline_version_tag="--tag $2"
  fi
  if [[ "$ec2_baseline_version_branch" == "" && "$ec2_baseline_version_tag" == "" ]]; then
    echo "ERROR: no version was provided for ec2-baseline module."
    exit 1
  fi

  gruntwork-install \
    --module-name base/ec2-baseline \
    --repo https://github.com/gruntwork-io/terraform-aws-service-catalog \
    ${ec2_baseline_version_branch} \
    ${ec2_baseline_version_tag}

  # Include common defaults and functions from the ec2-baseline install script
  # See: https://github.com/gruntwork-io/terraform-aws-service-catalog/blob/master/modules/base/ec2-baseline
  readonly EC2_BASELINE_RELATIVE_PATH="../../base/ec2-baseline"
  readonly EC2_BASELINE_PATH="$(dirname "$(realpath "$0")")/${EC2_BASELINE_RELATIVE_PATH}"
  if [[ ! -f "${EC2_BASELINE_PATH}/install.sh" ]]; then
    echo "ERROR: $EC2_BASELINE_PATH/install.sh not found."
    exit 1
  fi

  source "$EC2_BASELINE_PATH/install.sh"
}


function install_ecs_scripts {
  local -r ecs_cluster_version="$1"

  # Install aws CLI
  echo 'Installing AWS CLI'
  sudo yum --setopt=tsflags=noscripts remove microcode_ctl -y        # Based on https://forums.aws.amazon.com/thread.jspa?messageID=924216&tstart=0
  sudo yum update -y && sudo yum install -y aws-cli bind-utils

  # Install ecs-scripts module which allows for configuring an EC2 instance to join an existing ECS cluster
  # See: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/bootstrap_container_instance.html for more information
  gruntwork-install --module-name 'ecs-scripts' --repo https://github.com/gruntwork-io/terraform-aws-ecs --tag "$ecs_cluster_version"
}


function install_ecs_cluster {
  # Read from env vars to make it easy to set these in a Packer template (without super-wide --module-param foo=bar code).
  # Fallback to default version if the env var is not set.
  local ecs_cluster_version="${ecs_cluster_version:-$DEFAULT_ECS_CLUSTER_VERSION}"

  local module_security_version="${module_security_version:-$DEFAULT_MODULE_SECURITY_VERSION}"
  local module_aws_monitoring_version="${module_aws_monitoring_version:-$DEFAULT_MODULE_AWS_MONITORING_VERSION}"
  local bash_commons_version="${bash_commons_version:-$DEFAULT_BASH_COMMONS_VERSION}"

  local enable_ssh_grunt="${enable_ssh_grunt:-$DEFAULT_ENABLE_SSH_GRUNT}"
  local enable_cloudwatch_metrics="${enable_cloudwatch_metrics:-$DEFAULT_ENABLE_CLOUDWATCH_METRICS}"
  local enable_cloudwatch_log_aggregation="${enable_cloudwatch_log_aggregation:-$DEFAULT_ENABLE_CLOUDWATCH_LOG_AGGREGATION}"


  while [[ $# -gt 0 ]]; do
    local key="$1"

    case "$key" in
      --ecs_cluster-version)
        assert_not_empty "$key" "$2"
        ecs_cluster_version="$2"
        shift
        ;;
      --module-security-version)
        assert_not_empty "$key" "$2"
        module_security_version="$2"
        shift
        ;;
      --terraform-aws-monitoring-version)
        assert_not_empty "$key" "$2"
        module_aws_monitoring_version="$2"
        shift
        ;;
      --bash-commons-version)
        assert_not_empty "$key" "$2"
        bash_commons_version="$2"
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
        echo "ERROR: Unrecognized argument: $key"
        exit 1
        ;;
    esac

    shift
  done

  assert_env_var_not_empty "GITHUB_OAUTH_TOKEN"

  install_gruntwork_modules \
    "$bash_commons_version" \
    "$module_security_version" \
    "$module_aws_monitoring_version" \
    "$enable_ssh_grunt" \
    "$enable_cloudwatch_metrics" \
    "$enable_cloudwatch_log_aggregation"

  install_user_data \
    "${EC2_BASELINE_PATH}/user-data-common.sh"

  install_ecs_scripts "$ecs_cluster_version"
}

# Determine which version of the EC2 baseline module to install.
# Prioritize an environment variable set by Packer, and fall back to the value
# set by the gruntwork-install script in GRUNTWORK_INSTALL_BRANCH or GRUNTWORK_INSTALL_TAG
# If branch and tag are both set, gruntwork-install prefers branch
module_ec2_baseline_branch="${module_ec2_baseline_branch:-$GRUNTWORK_INSTALL_BRANCH}"
module_ec2_baseline_tag="${module_ec2_baseline_version:-$GRUNTWORK_INSTALL_TAG}"
include_ec2_baseline "$module_ec2_baseline_branch" "$module_ec2_baseline_tag"

install_ecs_cluster "$@"
