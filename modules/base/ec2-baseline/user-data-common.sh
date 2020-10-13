#!/usr/bin/env bash
# This script contains common utility functions for initializing EC2 instances at boot time

readonly BASH_COMMONS_DIR="/opt/gruntwork/bash-commons"

if [[ ! -d "$BASH_COMMONS_DIR" ]]; then
  echo "ERROR: this script requires that bash-commons is installed in $BASH_COMMONS_DIR. See https://github.com/gruntwork-io/bash-commons for more info."
  exit 1
fi

function file_contains_text {
  local -r text="$1"
  local -r file="$2"
  grep -q "$text" "$file"
}

function file_exists {
  local -r file="$1"
  [[ -f "$file" ]]
}

function append_text_in_file {
  local -r text="$1"
  local -r file="$2"

  echo -e "$text" | sudo tee -a "$file"
}

# Replace a line of text in a file. Only works for single-line replacements.
function replace_text_in_file {
  local -r original_text_regex="$1"
  local -r replacement_text="$2"
  local -r file="$3"

  sudo sed -i "s|$original_text_regex|$replacement_text|" "$file"
}

function replace_or_append_in_file {
  local -r original_text_regex="$1"
  local -r replacement_text="$2"
  local -r file="$3"

  if file_exists "$file" && file_contains_text "$original_text_regex" "$file"; then
    replace_text_in_file "$original_text_regex" "$replacement_text" "$file"
  else
    append_text_in_file "$replacement_text" "$file"
  fi
}

function attach_volume {
  local -r aws_region="$1"
  local -r volume_name_tag="$2"
  local -r device_name="$3"
  local -r mount_point="$4"
  local -r owner="$5"

  mount-ebs-volume \
    --aws-region "$aws_region" \
    --volume-with-same-tag "$volume_name_tag" \
    --device-name "$device_name" \
    --mount-point "$mount_point" \
    --owner "$owner"
}

function attach_eip {
  local -r eip_id="$1"

  source "$BASH_COMMONS_DIR/aws.sh"

  echo "Attaching EIP $eip_id..."
  aws ec2 associate-address  \
   --instance-id "$(aws_get_instance_id)"  \
   --allocation-id "$eip_id"  \
   --region "$(aws_get_instance_region)"  \
   --allow-reassociation
}

function start_cloudwatch_logs_agent {
  local -r log_group_name="$1"

  echo "Starting CloudWatch Logs Agent in VPC"
  /etc/user-data/cloudwatch-log-aggregation/run-cloudwatch-logs-agent.sh --log-group-name "$log_group_name"
}

function start_ssh_grunt {
  local -r ssh_grunt_iam_group="$1"
  local -r ssh_grunt_iam_group_sudo="$2"
  local -r external_account_ssh_grunt_role_arn="$3"

  echo "Starting ssh-grunt"

  local args=()

  if [[ -n "$ssh_grunt_iam_group" ]]; then
    args+=("--iam-group" "$ssh_grunt_iam_group")
  fi

  if [[ -n "$ssh_grunt_iam_group_sudo" ]]; then
    args+=("--iam-group-sudo" "$ssh_grunt_iam_group_sudo")
  fi

  if [[ -n "$external_account_ssh_grunt_role_arn" ]]; then
    args+=("--role-arn" "$external_account_ssh_grunt_role_arn")
  fi

  # Call 'sync-users' to sync IAM users the first time during boot. 
  sudo /usr/local/bin/ssh-grunt iam sync-users "${args[@]}"

  # Call 'install' to add a cron job that will set up ssh-grunt and re-run 'sync-users' on a schedule. 
  sudo /usr/local/bin/ssh-grunt iam install "${args[@]}"

  # Restart sshd so that the changes to sshd_config to take effect
  # First try with systemctl (systemd), then with the service command
  if command -v "systemctl"; then
    systemctl restart sshd
  elif command -v "service"; then
    service sshd restart
  else
    echo "ERROR: Could not use systemctl or service to restart sshd."
  fi
}

function start_fail2ban {
  echo "Starting fail2ban"
  /etc/user-data/configure-fail2ban-cloudwatch/configure-fail2ban-cloudwatch.sh --cloudwatch-namespace Fail2Ban
}

# Starts baseline EC2 security features, including CloudWatch Log aggregation, ssh-grunt, fail2ban, and ip-lockdown
function start_ec2_baseline {
  local -r enable_cloudwatch_log_aggregation="$1"
  local -r enable_ssh_grunt="$2"
  local -r enable_fail2ban="$3"
  local -r enable_ip_lockdown="$4"
  local -r ssh_grunt_iam_group="$5"
  local -r ssh_grunt_iam_group_sudo="$6"
  local -r log_group_name="$7"
  local -r external_account_ssh_grunt_role_arn="$8"
  shift 8
  local -ra ip_lockdown_users=("$@")

  if [[ "$enable_cloudwatch_log_aggregation" == "true" ]]; then
    start_cloudwatch_logs_agent "$log_group_name"
  fi

  if [[ "$enable_ssh_grunt" == "true" ]]; then
    start_ssh_grunt "$ssh_grunt_iam_group" "$ssh_grunt_iam_group_sudo" "$external_account_ssh_grunt_role_arn"
  fi

  if [[ "$enable_fail2ban" = "true" ]]; then
    start_fail2ban
  fi

  if [[ "$enable_ip_lockdown" = "true" ]]; then
    # Lock down the EC2 metadata endpoint so only the root and specified users can access it
    /usr/local/bin/ip-lockdown 169.254.169.254 root "${ip_lockdown_users[@]}"
  fi
}
