#!/bin/bash
# This script is meant to be run in the User Data of each ECS instance. It does the following:
#
# 1. Configures the EC2 instance baseline from the base/ec2-baseline module
# 2. Registers the instance with the proper ECS cluster.
#
# Note, this script:
#
# 1. Assumes it is running in the AMI built from the ecs-node-al2.json Packer template.
# 2. Has a number of variables filled in using Terraform interpolation.

set -e

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Include common functions
source /etc/user-data/user-data-common.sh

readonly users_for_ip_lockdown=(${ip_lockdown_users})
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

# Call the configure-ecs-instance script https://github.com/gruntwork-io/module-ecs/blob/master/modules/ecs-scripts/bin/configure-ecs-instance
# This script sets the required ecs.config file so that the EC2 instance can properly join the ECS cluster
# See also: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/bootstrap_container_instance.html#bootstrap_container_agent
/usr/local/bin/configure-ecs-instance --ecs-cluster-name "${cluster_name}" --docker-auth-type ecr --ecr-aws-region "${aws_region}"
