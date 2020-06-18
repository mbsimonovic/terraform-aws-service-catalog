#!/bin/bash
# This script is meant to be run in the User Data of each ECS instance. It does the following:
#
# 1. Configures the EC2 instance baseline from the base/ec2-baseline module
# 2. Registers the instance with the proper ECS cluster.
#
# Note, this script:
#
# 1. Assumes it is running in the AMI built from the ecs-node.json Packer template.
# 2. Has a number of variables filled in using Terraform interpolation.

set -e

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1


# Include common functions
source /etc/user-data/user-data-common.sh


function configure_baseline {
  local -r enable_cloudwatch_log_aggregation="$1"
  local -r enable_ssh_grunt="$2"
  local -r ssh_grunt_iam_group="$3"
  local -r ssh_grunt_iam_group_sudo="$4"
  local -r log_group_name="$5"
  local -r external_account_ssh_grunt_role_arn="$6"
  local -r enable_fail2ban="$7"
  local -r enable_ip_lockdown="$8"

  start_ec2_baseline \
    "${enable_cloudwatch_log_aggregation}" \
    "${enable_ssh_grunt}" \
    "${enable_fail2ban}" \
    "${enable_ip_lockdown}" \
    "${ssh_grunt_iam_group}" \
    "${ssh_grunt_iam_group_sudo}" \
    "${log_group_name}" \
    "${external_account_ssh_grunt_role_arn}"
}

function configure_ecs_instance {
  local -r enable_cloudwatch_log_aggregation="$1"
  local -r enable_ssh_grunt="$2"
  local -r ssh_grunt_iam_group="$3"
  local -r ssh_grunt_iam_group_sudo="$4"
  local -r log_group_name="$5"
  local -r external_account_ssh_grunt_role_arn="$6"
  local -r enable_fail2ban="$7"
  local -r enable_ip_lockdown="$8"

  configure_baseline \
    "${enable_cloudwatch_log_aggregation}" \
    "${enable_ssh_grunt}" \
    "${ssh_grunt_iam_group}" \
    "${ssh_grunt_iam_group_sudo}" \
    "${log_group_name}" \
    "${external_account_ssh_grunt_role_arn}" \
    "${enable_fail2ban}" \
    "${enable_ip_lockdown}" 
}

# These variables are set by Terraform interpolation
configure_ecs_instance "${enable_cloudwatch_log_aggregation}" "${enable_ssh_grunt}" "${ssh_grunt_iam_group}" "${ssh_grunt_iam_group_sudo}" "${log_group_name}" "${external_account_ssh_grunt_role_arn}" "${enable_fail2ban}" "${enable_ip_lockdown}" 


