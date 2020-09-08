#!/usr/bin/env bash
# Install OpenVPN server and Gruntwork dependencies on a Linux server

set -e

# renovate.json auto-update: package-openvpn
readonly DEFAULT_PACKAGE_OPENVPN_VERSION="v0.11.1"

function include_ec2_baseline {
  ec2_baseline_version_branch="$1"
  ec2_baseline_version_tag="$2"
  if [[ "$ec2_baseline_version_branch" == "" && "$ec2_baseline_version_tag" == "" ]]; then
    echo "ERROR: no version was provided for ec2-baseline module."
    exit 1
  fi

  gruntwork-install \
    --module-name base/ec2-baseline \
    --repo https://github.com/gruntwork-io/aws-service-catalog \
    --branch ${ec2_baseline_version_branch} \
    --tag ${ec2_baseline_version_tag}

  # Include common defaults and functions from the ec2-baseline install script
  # See: https://github.com/gruntwork-io/aws-service-catalog/blob/master/modules/base/ec2-baseline
  readonly EC2_BASELINE_RELATIVE_PATH="../../base/ec2-baseline"
  readonly EC2_BASELINE_PATH="$(dirname "$(realpath "$0")")/${EC2_BASELINE_RELATIVE_PATH}"
  if [[ ! -f "${EC2_BASELINE_PATH}/install.sh" ]]; then
    echo "ERROR: $EC2_BASELINE_PATH/install.sh not found."
    exit 1
  fi

  source "$EC2_BASELINE_PATH/install.sh"
}

function install_openvpn_packages {
  local -r package_openvpn_version="$1"
  local -ar modules=(install-openvpn init-openvpn start-openvpn-admin backup-openvpn-pki)
  local -r openvpn_repo="https://github.com/gruntwork-io/package-openvpn"

  echo "Installing Gruntwork OpenVPN packages"

  for module in "${modules[@]}"
  do
    gruntwork-install --module-name "$module" --repo "$openvpn_repo" --tag "$package_openvpn_version"
  done

  gruntwork-install --binary-name openvpn-admin --repo "$openvpn_repo" --tag "$package_openvpn_version"
}

function install_openvpn_server {
  # Read from env vars to make it easy to set these in a Packer template (without super-wide --module-param foo=bar code).
  # Fallback to default version if the env var is not set.
  local package_openvpn_version="${package_openvpn_version:-$DEFAULT_PACKAGE_OPENVPN_VERSION}"
  local module_security_version="${module_security_version:-$DEFAULT_MODULE_SECURITY_VERSION}"
  local module_aws_monitoring_version="${module_aws_monitoring_version:-$DEFAULT_MODULE_AWS_MONITORING_VERSION}"
  local bash_commons_version="${bash_commons_version:-$DEFAULT_BASH_COMMONS_VERSION}"
  local enable_ssh_grunt="${enable_ssh_grunt:-$DEFAULT_ENABLE_SSH_GRUNT}"
  local enable_cloudwatch_metrics="${enable_cloudwatch_metrics:-$DEFAULT_ENABLE_CLOUDWATCH_METRICS}"
  local enable_cloudwatch_log_aggregation="${enable_cloudwatch_log_aggregation:-$DEFAULT_ENABLE_CLOUDWATCH_LOG_AGGREGATION}"

  while [[ $# -gt 0 ]]; do
    local key="$1"

    case "$key" in
      --package-openvpn-version)
        assert_not_empty "$key" "$2"
        package_openvpn_version="$2"
        shift
        ;;
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
    "${EC2_BASELINE_PATH}/user-data-common.sh"

  install_openvpn_packages \
    "$package_openvpn_version"

  sudo /usr/local/bin/install-openvpn
}

# Determine which version of the EC2 baseline module to install.
# Prioritize an environment variable set by Packer, and fall back to the value
# set by the gruntwork-install script in GRUNTWORK_INSTALL_BRANCH or GRUNTWORK_INSTALL_TAG
# If branch and tag are both set, gruntwork-install prefers branch
module_ec2_baseline_branch="${module_ec2_baseline_branch:-$GRUNTWORK_INSTALL_BRANCH}"
module_ec2_baseline_tag="${module_ec2_baseline_version:-$GRUNTWORK_INSTALL_TAG}"
include_ec2_baseline "$module_ec2_baseline_branch" "$module_ec2_baseline_tag"

install_openvpn_server "$@"
