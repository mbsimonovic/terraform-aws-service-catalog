#!/bin/bash
#
# A script run in User Data of the EC2 server during boot.
#
# Note that this script expects to be running in an AMI generated by the Packer template ec2-instance.json.

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


volume_json=$(echo ${ebs_volumes} | base64 -d)
for name in $(echo $${volume_json} | jq -r 'keys[]') ; do
    mount_point=$(echo $${volume_json} | jq -r ".\"$${name}\".mount_point")
    device_name=$(echo $${volume_json} | jq -r ".\"$${name}\".device_name")
    owner=$(echo $${volume_json} | jq -r ".\"$${name}\".owner")
    id=$(echo ${ebs_volume_data} | base64 -d | jq -r "[.\"$${name}\"][0].id")
    mount-ebs-volume \
        --aws-region "${ebs_aws_region}" \
        --volume-id "$${id}" \
        --device-name "$${device_name}" \
        --mount-point "$${mount_point}" \
        --owner "$${owner}"
done
