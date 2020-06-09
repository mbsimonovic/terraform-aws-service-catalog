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

function start_data_dog_ecs_task {
  local -r aws_region="$1"
  local -r ecs_cluster_name="$2"
  local -r data_dog_task_arn="$3"
  local -r data_dog_api_key_encrypted="$4"

  echo "Using gruntkms to decrypt DataDog API Key"
  local data_dog_api_key
  data_dog_api_key=$(/usr/local/bin/gruntkms decrypt --ciphertext "$data_dog_api_key_encrypted" --aws-region "$aws_region")

  # Start ECS manually now so we can retrieve the container instance ARN a few lines below
  echo "Starting ECS Agent"
  start ecs
  sleep 10 # ECS Agent takes some time to start

  # Pass the DataDog API Token as an env var
  local -r env_overrides="[{\"name\": \"API_KEY\", \"value\": \"$data_dog_api_key\"}]"
  local -r container_overrides="{\"containerOverrides\": [{\"name\": \"dd-agent\", \"environment\": $env_overrides}]}"

  local instance_arn
  instance_arn=$(curl -s http://localhost:51678/v1/metadata | jq -r '. | .ContainerInstanceArn' | awk -F/ '{print $NF}')

  echo "Starting DataDog ECS Task $data_dog_task_arn in ECS Cluster $ecs_cluster_name on instance $instance_arn in $aws_region"
  local -r cmd="aws ecs start-task --cluster '$ecs_cluster_name' --task-definition '$data_dog_task_arn' --container-instances '$instance_arn' --region '$aws_region' --overrides '$container_overrides'"

  echo "Adding DataDog ECS Task to rc.local so it runs after reboots"
  echo "$cmd" >> /etc/rc.local
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

  start_data_dog_ecs_task "$aws_region" "$ecs_cluster_name" "$data_dog_task_arn" "$data_dog_api_key_encrypted"
}

# These variables are set by Terraform interpolation
#configure_ecs_instance "${aws_region}" "${ecs_cluster_name}" "${docker_registry_url}" "${docker_repo_auth}"{{ end }}{{if .InstallCloudWatchMonitoring }} "${vpc_name}" "${log_group_name}"{{ end }}{{ if .RunDataDogEcsTask }} "${data_dog_task_arn}" "${data_dog_api_key_encrypted}"{{ end }}
configure_ecs_instance "${enable_cloudwatch_log_aggregation}" "${enable_ssh_grunt}" "${ssh_grunt_iam_group}" "${ssh_grunt_iam_group_sudo}" "${log_group_name}" "${external_account_ssh_grunt_role_arn}" "${enable_fail2ban}" "${enable_ip_lockdown}" "${}" "${}" "${}" 


