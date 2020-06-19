#!/usr/bin/env bash
# Install ECS Cluster and Gruntwork dependencies on a Linux server

set -e

readonly DEFAULT_ECS_CLUSTER_VERSION="v0.20.2"

# ECS tooling 
readonly DEFAULT_ECS_SCRIPTS_VERSION="v0.20.2"
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


function install_ecs_cluster {
  # Read from env vars to make it easy to set these in a Packer template (without super-wide --module-param foo=bar code).
  # Fallback to default version if the env var is not set.
  local ecs_cluster_version="${ecs_cluster_version:-DEFAULT_ECS_CLUSTER_VERSION}"
  
  while [[ $# > 0 ]]; do
    local key="$1"

    case "$key" in
      --ecs_cluster-version)
        assert_not_empty "$key" "$2"
        ecs_cluster_version="$2"
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

  gruntwork-install --module-name 'ecs-scripts' --repo https://github.com/gruntwork-io/module-ecs --tag "$ecs_cluster_version"
}

include_ec2_baseline

install_ecs_cluster "$@"
