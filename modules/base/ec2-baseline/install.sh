# This script contains defaults values and utility functions for install common Gruntwork modules and tools
# When executed by the gruntwork-installer, it's a NOP

# Gruntwork module versions
# renovate.json auto-update: bash-commons
readonly DEFAULT_BASH_COMMONS_VERSION="v0.1.9"
# renovate.json auto-update: terraform-aws-security
readonly DEFAULT_MODULE_SECURITY_VERSION="v0.55.4"
# renovate.json auto-update: terraform-aws-monitoring
readonly DEFAULT_MODULE_AWS_MONITORING_VERSION="v0.30.3"
# renovate.json auto-update: terraform-aws-server
readonly DEFAULT_MODULE_STATEFUL_SERVER_VERSION="v0.13.7"

# Enable / disable features
readonly DEFAULT_ENABLE_SSH_GRUNT="true"
readonly DEFAULT_ENABLE_CLOUDWATCH_METRICS="true"
readonly DEFAULT_ENABLE_CLOUDWATCH_LOG_AGGREGATION="true"

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

function install_security_packages {
  local -r module_security_version="$1"
  local -r enable_ssh_grunt="$2"

  echo "Installing Gruntwork Security Modules"

  gruntwork-install --module-name 'auto-update' --repo https://github.com/gruntwork-io/terraform-aws-security --tag "$module_security_version"
  gruntwork-install --module-name 'fail2ban' --repo https://github.com/gruntwork-io/terraform-aws-security --tag "$module_security_version"
  gruntwork-install --module-name 'ntp' --repo https://github.com/gruntwork-io/terraform-aws-security --tag "$module_security_version"
  gruntwork-install --module-name 'ip-lockdown' --repo https://github.com/gruntwork-io/terraform-aws-security --tag "$module_security_version"

  if [[ "$enable_ssh_grunt" == "true" ]]; then
    # ssh-grunt is incompatible with EC2 Instance Connect, so if it's installed, we need to remove it.
    # First, we'll detect if set -e is enabled. We need to temporarily ignore errors so that we can detect if
    # the ec2-instance-connect package is installed.
    local reset_e="false"
    if [[ -o errexit ]]; then
      reset_e="true"
    fi
    set +e

    local -r remove_log_msg="Removing ec2-instance-connect due to incompatibility with ssh-grunt."
    if command -v "rpm"; then
      if rpm -q ec2-instance-connect; then
        echo "$remove_log_msg"
        sudo yum -y remove ec2-instance-connect
      fi
    elif command -v "dpkg"; then
      if dpkg -l ec2-instance-connect; then
        echo "$remove_log_msg"
        sudo apt-get -y purge ec2-instance-connect
      fi
    fi

    # Re-enable set -e if it was enabled before.
    if [[ "$reset_e" == "true" ]]; then
      set -e
    fi

    # Finally we can install ssh-grunt
    gruntwork-install --binary-name 'ssh-grunt' --repo https://github.com/gruntwork-io/terraform-aws-security --tag "$module_security_version"
  fi
}

function install_monitoring_packages {
  local -r module_aws_monitoring_version="$1"
  local -r enable_cloudwatch_metrics="$2"
  local -r enable_cloudwatch_log_aggregation="$3"

  echo "Installing Gruntwork Monitoring Modules"

  if [[ "$enable_cloudwatch_metrics" == "true" ]] || [[ "$enable_cloudwatch_log_aggregation" == "true" ]]; then
    # Allow the region to be passed in by env var
    local aws_region="$AWS_REGION"
    if [[ -z "$aws_region" ]]; then
      # If no region is passed in by env var, read it from the EC2 metadata endpoint instead
      source "/opt/gruntwork/bash-commons/aws.sh"
      aws_region=$(aws_get_instance_region)
    fi

    gruntwork-install --module-name 'agents/cloudwatch-agent' --repo https://github.com/gruntwork-io/terraform-aws-monitoring --tag "$module_aws_monitoring_version" --module-param aws-region="$aws_region"
  fi

  gruntwork-install --module-name 'logs/syslog' --repo https://github.com/gruntwork-io/terraform-aws-monitoring --tag "$module_aws_monitoring_version"
}

function install_gruntwork_modules {
  local -r bash_commons_version="$1"
  local -r module_security_version="$2"
  local -r module_aws_monitoring_version="$3"
  local -r enable_ssh_grunt="$4"
  local -r enable_cloudwatch_metrics="$5"
  local -r enable_cloudwatch_log_aggregation="$6"

  install_bash_commons "$bash_commons_version"
  install_security_packages "$module_security_version" "$enable_ssh_grunt"
  install_monitoring_packages "$module_aws_monitoring_version" "$enable_cloudwatch_metrics" "$enable_cloudwatch_log_aggregation"
}

function install_stateful_server_packages {
  local -r module_server_version="$1"

  echo "Installing nvme CLI for nitro based instances"
  sudo apt-get install -y nvme-cli

  echo "Installing Gruntwork Stateful Server Modules"
  gruntwork-install --module-name 'persistent-ebs-volume' --repo 'https://github.com/gruntwork-io/terraform-aws-server' --tag "$module_server_version"
}

function install_aws_cli {
  echo "Installing AWS CLI"
  sudo apt-get install -y jq python3-pip unzip
  sudo pip3 install awscli
}

function install_user_data {
  local -r user_data_script="$1"

  echo "Installing common user-data script"

  # This directory should have already been created by the gruntwork-installer,
  # but we create it here as a failsafe measure
  mkdir -p /etc/user-data
  cp "$user_data_script" /etc/user-data
}
