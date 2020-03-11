#!/usr/bin/env bash
# Set up a bastion host

set -e

# Include common defaults and functions from the ec2-common install script
# See: https://github.com/gruntwork-io/aws-service-catalog/blob/master/modules/base/ec2-common
readonly GRUNTWORK_INSTALLER_DOWNLOAD_DIR="/tmp/gruntwork-script-modules"
source $GRUNTWORK_INSTALLER_DOWNLOAD_DIR/base/ec2-common/install.sh

function install_bastion_host {
  # Read from env vars to make it easy to set these in a Packer template (without super-wide --module-param foo=bar code).
  # Fallback to default version if the env var is not set.
  local module_security_version="${module_security_version:-$DEFAULT_MODULE_SECURITY_VERSION}"
  local module_aws_monitoring_version="${module_aws_monitoring_version:-$DEFAULT_MODULE_AWS_MONITORING_VERSION}"
  local bash_commons_version="${bash_commons_version:-$DEFAULT_BASH_COMMONS_VERSION}"
  local enable_ssh_grunt="${enable_ssh_grunt:-$DEFAULT_ENABLE_SSH_GRUNT}"
  local enable_cloudwatch_metrics="${enable_cloudwatch_metrics:-$DEFAULT_ENABLE_CLOUDWATCH_METRICS}"
  local enable_cloudwatch_log_aggregation="${enable_cloudwatch_log_aggregation:-$DEFAULT_ENABLE_CLOUDWATCH_LOG_AGGREGATION}"

  while [[ $# > 0 ]]; do
    local key="$1"

    case "$key" in
      --module-security-version)
        assert_not_empty "$key" "$2"
        module_security_version="$2"
        shift
        ;;
      --module-aws-monitoring-version)
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
    "$GRUNTWORK_INSTALLER_DOWNLOAD_DIR/base/ec2-common/user-data-common.sh"
}

install_bastion_host "$@"
