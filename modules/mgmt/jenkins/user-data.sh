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

# Include common functions
source /etc/user-data/user-data-common.sh

function start_jenkins {
  local -r mount_point="$1"
  local -r memory="$2"

  echo "Starting Jenkins with home directory $mount_point and memory $memory"

  run-jenkins \
    --memory "$memory" \
    --jenkins-home "$mount_point"
}


function start_server {
  local -r aws_region="$1"
  local -r volume_name_tag="$2"
  local -r device_name="$3"
  local -r mount_point="$4"
  local -r owner="$5"
  local -r memory="$6"

  attach_volume "$aws_region" "$volume_name_tag" "$device_name" "$mount_point" "$owner"
  start_jenkins "$mount_point" "$memory"
}

readonly users_for_ip_lockdown=(%{ for user in ip_lockdown_users }"${user}" %{ endfor })
start_ec2_baseline \
  "${enable_cloudwatch_log_aggregation}" \
  "${enable_ssh_grunt}" \
  "${enable_fail2ban}" \
  "${enable_ip_lockdown}" \
  "${ssh_grunt_iam_group}" \
  "${ssh_grunt_iam_group_sudo}" \
  "${log_group_name}" \
  "${external_account_ssh_grunt_role_arn}" \
  "$${users_for_ip_lockdown[@]}"  # Need a double dollar-sign here to avoid Terraform interpolation

start_server \
  "${aws_region}" \
  "${volume_name_tag}" \
  "${device_name}" \
  "${mount_point}" \
  "${owner}" \
  "${memory}"
