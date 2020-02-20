#!/bin/bash
#
# This script is meant to run in the User Data of Jenkins to:
#
# - Run the CloudWatch Logs Agent to send all data in syslog to CloudWatch
# - Mount a persistent EBS volume Jenkins can use for data storage
# - Start the Jenkins server
#
# Note that this script is intended to run on top of the AMI built from the Packer template packer/jenkins-ubuntu.json.

set -e

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

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

function start_cloudwatch_logs_agent {
  local -r log_group_name="$1"

  echo "Starting CloudWatch Logs Agent in VPC"
  /etc/user-data/cloudwatch-log-aggregation/run-cloudwatch-logs-agent.sh --log-group-name "$log_group_name" --extra-log-file jenkins=/var/log/jenkins/jenkins.log
}

function start_fail2ban {
  echo "Starting fail2ban"
  /etc/user-data/configure-fail2ban-cloudwatch/configure-fail2ban-cloudwatch.sh --cloudwatch-namespace Fail2Ban
}

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

  if $(file_exists "$file") && $(file_contains_text "$original_text_regex" "$file"); then
    replace_text_in_file "$original_text_regex" "$replacement_text" "$file"
  else
    append_text_in_file "$replacement_text" "$file"
  fi
}

function start_jenkins {
  local -r mount_point="$1"
  local -r memory="$2"

  echo "Starting Jenkins with home directory $mount_point and memory $memory"

  run-jenkins \
    --memory "$memory" \
    --jenkins-home "$mount_point"
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

  if [[ -n "$$external_account_ssh_grunt_role_arn" ]]; then
    args+=("--role-arn" "$$external_account_ssh_grunt_role_arn")
  fi

  sudo /usr/local/bin/ssh-grunt iam install "${args[@]}"
}

function start_server {
  local -r aws_region="$1"
  local -r volume_name_tag="$2"
  local -r device_name="$3"
  local -r mount_point="$4"
  local -r owner="$5"
  local -r memory="$6"
  local -r log_group_name="$7"
  local -r enable_ssh_grunt="$8"
  local -r enable_cloudwatch_log_aggregation="$9"
  local -r ssh_grunt_iam_group="${10}"
  local -r ssh_grunt_iam_group_sudo="${11}"
  local -r external_account_ssh_grunt_role_arn="${12}"

  if [[ "$enable_cloudwatch_log_aggregation" == "true" ]]; then
    start_cloudwatch_logs_agent "$log_group_name"
  fi

  if [[ "$enable_ssh_grunt" == "true" ]]; then
    start_ssh_grunt "$ssh_grunt_iam_group" "$ssh_grunt_iam_group_sudo" "$external_account_ssh_grunt_role_arn"
  fi

  start_fail2ban
  attach_volume "$aws_region" "$volume_name_tag" "$device_name" "$mount_point" "$owner"
  start_jenkins "$mount_point" "$memory"

  # Lock down the EC2 metadata endpoint so only the root, default, and jenkins users can access it
  /usr/local/bin/ip-lockdown 169.254.169.254 root ubuntu jenkins
}

# These variables are set via Terraform interpolation
start_server \
  "${aws_region}" \
  "${volume_name_tag}" \
  "${device_name}" \
  "${mount_point}" \
  "${owner}" \
  "${memory}" \
  "${log_group_name}" \
  "${enable_ssh_grunt}" \
  "${enable_cloudwatch_log_aggregation}" \
  "${ssh_grunt_iam_group}" \
  "${ssh_grunt_iam_group_sudo}" \
  "${external_account_ssh_grunt_role_arn}"
